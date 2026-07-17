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
    @Published var validationError: String?

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
    private var cachedDisplayName: String?

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
        cachedDisplayName = nil

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
        cachedDisplayName = nil
    }

    var isLocked: Bool { challenge?.isLocked ?? false }

    // ✅ Local-only selection (no Firestore write). Tap again to deselect.
    func selectOption(propId: String, optionId: String) {
        guard !isLocked else { return }
        if selections[propId] == optionId {
            selections.removeValue(forKey: propId)
        } else {
            selections[propId] = optionId
        }
        isDirty = true

        recomputeScore()
        // Don't write score until they actually submit picks (and answers exist)
    }

    // MARK: - Duplicate pick validation

    /// Checks for duplicate picks within any group of slots that share the same
    /// player pool AND the same market category (e.g. all "Semifinalist" slots,
    /// all "Finalist" slots). Picks are allowed to repeat across categories —
    /// picking Harper for a semi slot AND a final slot is fine.
    func validateSelections() -> String? {
        // Group by option pool key + market base name so that semis and finals
        // are checked independently even though they list the same players.
        // e.g. "Semifinalist #1" → base "Semifinalist"
        //      "Finalist #1"     → base "Finalist"
        var groups: [String: [PropBet]] = [:]
        for prop in props {
            let optionKey = prop.options.map(\.id).sorted().joined(separator: "|")
            guard !optionKey.isEmpty else { continue }
            let marketBase = prop.market?.components(separatedBy: " #").first
                          ?? prop.market
                          ?? ""
            let groupKey = "\(optionKey)__\(marketBase)"
            groups[groupKey, default: []].append(prop)
        }

        for (_, groupProps) in groups where groupProps.count > 1 {
            let picked = groupProps.compactMap { selections[$0.id] }
            guard Set(picked).count < picked.count else { continue }

            let marketText = groupProps.compactMap { $0.market }.joined(separator: " ").lowercased()
            if marketText.contains("semi") {
                return "You've picked the same player twice for the semis."
            } else if marketText.contains("final") {
                return "You've picked the same player twice for the final."
            } else {
                return "You've made a duplicate pick — each slot must be a different player."
            }
        }
        return nil
    }

    // ✅ Submit writes current picks
    func submitPicks() async {
        guard !isLocked else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let challengeId = challenge?.id, !challengeId.isEmpty else { return }

        // Validate before writing
        if let error = validateSelections() {
            validationError = error
            return
        }

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
        // Group props by option pool + market base — same logic as validation.
        // Groups of 2+ use POOL scoring: any pick that appears in the group's
        // combined correct-answer set earns the point, regardless of slot order.
        // (e.g. picking Harper for slot #3 when slot #1 is keyed to Harper still counts.)
        // Single-prop groups use standard exact-match scoring.
        //
        // Pool groups are all-or-nothing: they only contribute to score/maxScore
        // once EVERY prop in the group has a correctOptionId set.

        var groups: [String: [PropBet]] = [:]
        for prop in props {
            let optionKey = prop.options.map(\.id).sorted().joined(separator: "|")
            guard !optionKey.isEmpty else { continue }
            let marketBase = prop.market?.components(separatedBy: " #").first
                           ?? prop.market ?? ""
            groups["\(optionKey)__\(marketBase)", default: []].append(prop)
        }

        var score = 0
        var answered = 0

        for (_, groupProps) in groups {
            if groupProps.count > 1 {
                // Pool group — score against whichever correct answers admin has set so far.
                // A player earns +1 for each confirmed correct player they picked ANYWHERE in
                // their group selections (slot order doesn't matter).
                let answeredProps = groupProps.filter { !($0.correctOptionId ?? "").isEmpty }
                guard !answeredProps.isEmpty else { continue }

                let correctPool = Set(answeredProps.compactMap { $0.correctOptionId })
                answered += answeredProps.count

                // All picks the user made across every slot in this group
                let userPicks = Set(groupProps.compactMap { selections[$0.id] })
                for correct in correctPool where userPicks.contains(correct) {
                    score += 1
                }

            } else if let prop = groupProps.first {
                // Standard exact-match
                guard let correct = prop.correctOptionId, !correct.isEmpty else { continue }
                answered += 1
                if selections[prop.id] == correct { score += 1 }
            }
        }

        answeredCount = answered
        maxScore      = answered
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
            let db = Firestore.firestore()
            let snap = try await db.collection("users").document(uid).getDocument()
            let linked = snap.data()?["linked_player_id"] as? String
            let cleaned = linked?.trimmingCharacters(in: .whitespacesAndNewlines)

            guard let cleaned, !cleaned.isEmpty else { return nil }
            cachedLinkedPlayerId = cleaned

            // Also cache display name from players collection so submission shows a real name
            if let playerSnap = try? await db.collection("players").document(cleaned).getDocument(),
               let name = playerSnap.data()?["display_name"] as? String, !name.isEmpty {
                cachedDisplayName = name
            }

            return cleaned
        } catch {
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

            var submissionFields: [String: Any] = [
                "uid": uid,
                "linked_player_id": linkedPlayerId,
                "score": computedScore,
                "max_score": maxScore,
                "updated_at": FieldValue.serverTimestamp()
            ]
            if let displayName = cachedDisplayName {
                submissionFields["display_name"] = displayName
            }
            try await submissionRef.setData(submissionFields, merge: true)

            lastPushedScore = computedScore
            lastPushedMax = maxScore

        } catch {
            errorMessage = "Score sync failed: \(error.localizedDescription)"
        }
    }
}
