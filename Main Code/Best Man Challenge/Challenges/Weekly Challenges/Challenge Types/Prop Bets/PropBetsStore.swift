//
//  PropBetsStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 2/3/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class PropBetsStore: ObservableObject {

    @Published var challenge: PropBetsChallenge?
    @Published var props: [PropBet] = []

    @Published var selections: [String: String] = [:] // propId -> optionId
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?

    @Published var isDirty: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var lastSubmittedAt: Date?

    // ✅ Scoring
    @Published var computedScore: Int = 0
    @Published var maxScore: Int = 0
    @Published var answeredCount: Int = 0

    private var propsListener: ListenerRegistration?
    private var picksListener: ListenerRegistration?
    private var challengeListener: ListenerRegistration?

    private var hasHydratedFromFirestore = false

    // Prevent spam writes when props listener fires rapidly
    private var lastPushedScore: Int?
    private var lastPushedMax: Int?
    private var scorePushTask: Task<Void, Never>?

    // Cache the linked player id so we don’t re-fetch every time
    private var cachedLinkedPlayerId: String?

    deinit {
        propsListener?.remove()
        picksListener?.remove()
        challengeListener?.remove()
        scorePushTask?.cancel()
    }

    func start(challengeId: String) {
        stop()

        isLoading = true
        errorMessage = nil
        isDirty = false
        isSubmitting = false
        lastSubmittedAt = nil
        hasHydratedFromFirestore = false

        computedScore = 0
        maxScore = 0
        answeredCount = 0
        lastPushedScore = nil
        lastPushedMax = nil
        cachedLinkedPlayerId = nil

        let db = Firestore.firestore()
        let challengeRef = db.collection("weekly_challenges").document(challengeId)

        // 1) Challenge listener
        challengeListener = challengeRef.addSnapshotListener { [weak self] snap, err in
            guard let self else { return }
            if let err {
                Task { @MainActor in self.errorMessage = err.localizedDescription }
                return
            }
            guard let snap, snap.exists, let data = snap.data() else { return }

            if let decoded = PropBetsChallenge.fromDoc(id: snap.documentID, data: data) {
                Task { @MainActor in self.challenge = decoded }
            } else {
                Task { @MainActor in self.errorMessage = "Challenge decode failed: missing required fields." }
            }
        }

        // 2) Props listener (ordered)
        propsListener = challengeRef.collection("props")
            .whereField("is_active", isEqualTo: true)
            .order(by: "position", descending: false)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in self.errorMessage = err.localizedDescription }
                    return
                }
                guard let snap else { return }

                var newProps: [PropBet] = []
                newProps.reserveCapacity(snap.documents.count)

                for doc in snap.documents {
                    let data = doc.data()
                    if let p = PropBet.fromDoc(id: doc.documentID, data: data) {
                        newProps.append(p)
                    }
                }

                newProps.sort { $0.position < $1.position }

                Task { @MainActor in
                    self.props = newProps
                    self.isLoading = false

                    // ✅ Recompute score whenever correctOptionId changes
                    self.recomputeScore()

                    // ✅ If answers were added after user submitted, push score now
                    self.upsertSubmissionScoreIfNeededDebounced()
                }
            }

        // 3) Picks listener (loads submitted picks)
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }

        picksListener = challengeRef.collection("picks").document(uid)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in self.errorMessage = err.localizedDescription }
                    return
                }

                guard let snap, snap.exists, let data = snap.data() else {
                    Task { @MainActor in
                        if !self.hasHydratedFromFirestore {
                            self.selections = [:]
                            self.isDirty = false
                            self.lastSubmittedAt = nil
                            self.hasHydratedFromFirestore = true
                            self.recomputeScore()
                        }
                    }
                    return
                }

                let remoteSelections = data["selections"] as? [String: String] ?? [:]
                let submittedAt = (data["submitted_at"] as? Timestamp)?.dateValue()

                Task { @MainActor in
                    // Don't clobber in-progress edits.
                    if !self.isDirty {
                        self.selections = remoteSelections
                    }
                    self.lastSubmittedAt = submittedAt
                    self.hasHydratedFromFirestore = true

                    // ✅ Score depends on picks too
                    self.recomputeScore()
                    self.upsertSubmissionScoreIfNeededDebounced()
                }
            }
    }

    func stop() {
        propsListener?.remove()
        picksListener?.remove()
        challengeListener?.remove()
        propsListener = nil
        picksListener = nil
        challengeListener = nil
        scorePushTask?.cancel()
        scorePushTask = nil
        cachedLinkedPlayerId = nil
    }

    var isLocked: Bool { challenge?.isLocked ?? false }

    // ✅ Local-only selection (no Firestore write)
    func selectOption(propId: String, optionId: String) {
        guard !isLocked else { return }
        selections[propId] = optionId
        isDirty = true

        recomputeScore()
        // Don't write score until they actually submit picks (and answers exist)
    }

    // ✅ Submit writes current picks
    func submitPicks() async {
        guard !isLocked else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let challengeId = challenge?.id, !challengeId.isEmpty else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let db = Firestore.firestore()
            let challengeRef = db.collection("weekly_challenges").document(challengeId)
            let pickRef = challengeRef.collection("picks").document(uid)

            try await pickRef.setData([
                "uid": uid,
                "selections": selections,
                "submitted_at": FieldValue.serverTimestamp(),
                "updated_at": FieldValue.serverTimestamp()
            ], merge: true)

            // IMPORTANT:
            // serverTimestamp may not be available immediately in the listener, so set a local value.
            self.lastSubmittedAt = Date()

            isDirty = false

            // ✅ If answers already exist, write score now; otherwise it'll write once you add correctOptionId
            await upsertSubmissionScoreIfNeeded(force: true)

        } catch {
            errorMessage = "Submit failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Scoring

    private func recomputeScore() {
        // Only count props that have a correctOptionId set
        let answeredProps = props.filter { ($0.correctOptionId ?? "").isEmpty == false }
        answeredCount = answeredProps.count

        // For prop bets, "max score" is how many props have an answer key (so standings appear only after you set them)
        maxScore = answeredProps.count

        var score = 0
        for p in answeredProps {
            guard let correct = p.correctOptionId else { continue }
            if selections[p.id] == correct {
                score += 1
            }
        }
        computedScore = score
    }

    // Debounce so prop answer updates don't spam writes
    private func upsertSubmissionScoreIfNeededDebounced() {
        scorePushTask?.cancel()
        scorePushTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 350_000_000) // 0.35s
            await self.upsertSubmissionScoreIfNeeded(force: false)
        }
    }

    private func fetchLinkedPlayerIdIfNeeded(uid: String) async -> String? {
        if let cachedLinkedPlayerId { return cachedLinkedPlayerId }

        do {
            let snap = try await Firestore.firestore().collection("users").document(uid).getDocument()
            let linked = snap.data()?["linked_player_id"] as? String
            let cleaned = linked?.trimmingCharacters(in: .whitespacesAndNewlines)

            if let cleaned, !cleaned.isEmpty {
                cachedLinkedPlayerId = cleaned
                return cleaned
            }
            return nil
        } catch {
            // If we can’t read user doc, treat as not eligible for leaderboard
            errorMessage = "Failed to load user profile: \(error.localizedDescription)"
            return nil
        }
    }

    private func upsertSubmissionScoreIfNeeded(force: Bool) async {
        // ✅ Must have submitted at least once
        guard lastSubmittedAt != nil else { return }

        // ✅ For your prop-bet flow: don’t create submissions until answers exist
        guard answeredCount > 0 else { return }

        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let challengeId = challenge?.id, !challengeId.isEmpty else { return }

        // ✅ Enforce your rule: if no linked_player_id, they do NOT exist in leaderboard
        guard let linkedPlayerId = await fetchLinkedPlayerIdIfNeeded(uid: uid) else {
            return
        }

        // Avoid redundant writes
        if !force,
           lastPushedScore == computedScore,
           lastPushedMax == maxScore {
            return
        }

        do {
            let db = Firestore.firestore()
            let submissionRef = db.collection("weekly_challenges")
                .document(challengeId)
                .collection("submissions")
                .document(uid)

            try await submissionRef.setData([
                "uid": uid,
                "linked_player_id": linkedPlayerId,
                "score": computedScore,
                "max_score": maxScore,
                "updated_at": FieldValue.serverTimestamp()
            ], merge: true)

            lastPushedScore = computedScore
            lastPushedMax = maxScore

        } catch {
            errorMessage = "Score sync failed: \(error.localizedDescription)"
        }
    }
}
