//
//  WeeklyChallengeManager.swift
//  Best Man Challenge
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class WeeklyChallengeManager: ObservableObject {

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(String)
    }

    @Published var currentChallenge: WeeklyChallenge?
    @Published var state: LoadState = .idle

    // Quiz / Riddle submission (existing)
    @Published var lastSubmission: WeeklyChallengeSubmission?

    // ✅ Prop bets submission summary (NEW)
    @Published var propBetsPickSummary: PropBetsPickSummary?

    // ✅ Store user context once (set from SessionStore)
    @Published private(set) var linkedPlayerId: String?
    @Published private(set) var displayName: String?

    // ✅ Submitter identity used for doc id in quiz/riddle submissions
    @Published private(set) var submitterId: String?
    @Published private(set) var submitterDisplayName: String?

    // ✅ Raw auth uid (used for prop bets picks/{uid})
    @Published private(set) var authUid: String?

    private let db = Firestore.firestore()
    private var activeListener: ListenerRegistration?
    private var propBetsPickListener: ListenerRegistration?

    init() {
        startActiveChallengeListener()
    }

    deinit {
        activeListener?.remove()
        activeListener = nil

        propBetsPickListener?.remove()
        propBetsPickListener = nil
    }

    func stopListening() {
        activeListener?.remove()
        activeListener = nil

        propBetsPickListener?.remove()
        propBetsPickListener = nil
    }

    func refresh() {
        startActiveChallengeListener()
    }

    // MARK: - User Context

    private func computeSubmitterId(uid: String, linkedPlayerId: String?) -> String {
        let lp = (linkedPlayerId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !lp.isEmpty { return lp }
        return "admin_\(uid)"
    }

    /// Call this once you have a logged-in session (e.g., onAppear).
    func setUserContext(uid: String?, linkedPlayerId: String?, displayName: String?) {
        let dn = (displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let uidClean = (uid ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lp = (linkedPlayerId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        self.linkedPlayerId = lp.isEmpty ? nil : lp
        self.displayName = dn.isEmpty ? nil : dn

        // ✅ store raw auth uid (prop bets uses this)
        self.authUid = uidClean.isEmpty ? nil : uidClean

        guard !uidClean.isEmpty else {
            self.submitterId = nil
            self.submitterDisplayName = self.displayName
            self.lastSubmission = nil
            self.propBetsPickSummary = nil
            stopPropBetsPickListener()
            return
        }

        // quiz/riddle submission identity (existing behavior)
        let sid = computeSubmitterId(uid: uidClean, linkedPlayerId: self.linkedPlayerId)
        self.submitterId = sid

        if let dn = self.displayName, !dn.isEmpty {
            self.submitterDisplayName = dn
        } else if sid.hasPrefix("admin_") {
            self.submitterDisplayName = "Admin"
        } else {
            self.submitterDisplayName = sid
        }

        // ✅ once we have a challenge, load correct submission type
        if let challenge = currentChallenge {
            updateSubmissionListeners(for: challenge)
        } else {
            self.lastSubmission = nil
            self.propBetsPickSummary = nil
        }
    }

    // MARK: - Active Challenge (LIVE)

    func startActiveChallengeListener() {
        state = .loading
        currentChallenge = nil
        lastSubmission = nil
        propBetsPickSummary = nil

        activeListener?.remove()
        activeListener = nil

        stopPropBetsPickListener()

        activeListener = db.collection("weekly_challenges")
            .whereField("is_active", isEqualTo: true)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    Task { @MainActor in
                        self.state = .failed("Firestore error: \(error.localizedDescription)")
                        self.currentChallenge = nil
                        self.lastSubmission = nil
                        self.propBetsPickSummary = nil
                        self.stopPropBetsPickListener()
                    }
                    return
                }

                guard let doc = snapshot?.documents.first else {
                    Task { @MainActor in
                        self.state = .empty
                        self.currentChallenge = nil
                        self.lastSubmission = nil
                        self.propBetsPickSummary = nil
                        self.stopPropBetsPickListener()
                    }
                    return
                }

                guard let challenge = Self.parseWeeklyChallenge(doc: doc) else {
                    Task { @MainActor in
                        self.state = .failed(
                            "Weekly challenge document has invalid or missing fields.\n" +
                            "Expected at minimum: week(Int), title(String), description(String), type(String)."
                        )
                        self.currentChallenge = nil
                        self.lastSubmission = nil
                        self.propBetsPickSummary = nil
                        self.stopPropBetsPickListener()
                    }
                    return
                }

                Task { @MainActor in
                    self.currentChallenge = challenge
                    self.state = .loaded

                    self.updateSubmissionListeners(for: challenge)
                }
            }
    }

    // MARK: - Submission listeners routing

    private func updateSubmissionListeners(for challenge: WeeklyChallenge) {
        // Always reset both, then start the correct one
        self.lastSubmission = nil
        self.propBetsPickSummary = nil
        stopPropBetsPickListener()

        // ✅ Prop bets uses /picks/{uid}
        if challenge.type == .prop_bets {
            if let uid = self.authUid, !uid.isEmpty {
                startPropBetsPickListener(challengeId: challenge.id, uid: uid)
            }
            return
        }

        // ✅ Quiz/Riddle uses /submissions/{submitterId}
        if let sid = self.submitterId {
            loadMyLatestSubmissionIfPossible(challengeId: challenge.id, submitterId: sid)
        } else {
            self.lastSubmission = nil
        }
    }

    private func stopPropBetsPickListener() {
        propBetsPickListener?.remove()
        propBetsPickListener = nil
    }

    private func startPropBetsPickListener(challengeId: String, uid: String) {
        stopPropBetsPickListener()

        let ref = db.collection("weekly_challenges")
            .document(challengeId)
            .collection("picks")
            .document(uid)

        propBetsPickListener = ref.addSnapshotListener { [weak self] snap, err in
            guard let self else { return }

            if let err = err {
                // Don’t hard-fail the whole view; just log
                print("⚠️ prop bets pick listener error:", err.localizedDescription)
                return
            }

            guard let snap, snap.exists, let data = snap.data() else {
                Task { @MainActor in self.propBetsPickSummary = nil }
                return
            }

            let selections = data["selections"] as? [String: String] ?? [:]
            let submittedAt = (data["submitted_at"] as? Timestamp)?.dateValue()

            Task { @MainActor in
                self.propBetsPickSummary = PropBetsPickSummary(
                    submittedAt: submittedAt,
                    selections: selections
                )
            }
        }
    }

    // MARK: - Parsing (shared)

    /// ✅ Shared parser used here + HistoryStore
    static func parseWeeklyChallenge(doc: QueryDocumentSnapshot) -> WeeklyChallenge? {
        let data = doc.data()

        guard
            let week = data["week"] as? Int,
            let title = data["title"] as? String,
            let description = data["description"] as? String,
            let typeRaw = data["type"] as? String,
            let type = ChallengeType(rawValue: typeRaw)
        else {
            return nil
        }

        // Optional dates (prop_bets may not have them)
        let startDate = (data["startDate"] as? Timestamp)?.dateValue()
        let endDate = (data["endDate"] as? Timestamp)?.dateValue()

        // ✅ locksAt (for prop_bets)
        let locksAt = (data["locksAt"] as? Timestamp)?.dateValue()

        let answer = data["answer"] as? String
        let isActiveFlag = data["is_active"] as? Bool

        // Puzzle (optional)
        var puzzle: WeeklyChallengePuzzle? = nil
        if let p = data["puzzle"] as? [String: Any] {
            puzzle = WeeklyChallengePuzzle(
                type: p["type"] as? String,
                size: p["size"] as? Int,
                grid: p["grid"] as? [Int],
                unlock_rule: p["unlock_rule"] as? String,
                unlock_value: p["unlock_value"] as? Int,
                unlock_text: p["unlock_text"] as? String
            )
        }

        // Cipher (optional)
        var cipher: WeeklyChallengeCipher? = nil
        if let c = data["cipher"] as? [String: Any] {
            cipher = WeeklyChallengeCipher(
                type: c["type"] as? String,
                ciphertext: c["ciphertext"] as? String,
                direction: c["direction"] as? String,
                shift: c["shift"] as? Int
            )
        }

        // Quiz (optional)
        var quiz: WeeklyChallengeQuiz? = nil
        if let q = data["quiz"] as? [String: Any] {
            let pointsPerCorrect = q["points_per_correct"] as? Int
            var questions: [WeeklyQuizQuestion] = []

            if let rawQs = q["questions"] as? [[String: Any]] {
                for rq in rawQs {
                    guard
                        let id = rq["id"] as? String,
                        let prompt = rq["prompt"] as? String,
                        let options = rq["options"] as? [String]
                    else { continue }

                    let correctIndex = rq["correct_index"] as? Int

                    questions.append(
                        WeeklyQuizQuestion(
                            id: id,
                            prompt: prompt,
                            options: options,
                            correct_index: correctIndex
                        )
                    )
                }
            }

            quiz = WeeklyChallengeQuiz(
                points_per_correct: pointsPerCorrect,
                questions: questions.isEmpty ? nil : questions
            )
        }

        return WeeklyChallenge(
            id: doc.documentID,
            week: week,
            title: title,
            description: description,
            type: type,
            startDate: startDate,
            endDate: endDate,
            locksAt: locksAt,
            answer: answer,
            puzzle: puzzle,
            cipher: cipher,
            quiz: quiz,
            is_active: isActiveFlag
        )
    }

    // MARK: - My Submission (by submitterId) - quiz/riddle only

    private func loadMyLatestSubmissionIfPossible(challengeId: String, submitterId: String) {
        db.collection("weekly_challenges")
            .document(challengeId)
            .collection("submissions")
            .document(submitterId)
            .getDocument { [weak self] snap, _ in
                guard let self else { return }
                guard let snap, snap.exists else {
                    Task { @MainActor in self.lastSubmission = nil }
                    return
                }

                let data = snap.data() ?? [:]
                let submittedAt =
                    (data["submittedAt"] as? Timestamp)?.dateValue()
                    ?? (data["submitted_at"] as? Timestamp)?.dateValue()
                    ?? Date()

                let lp = data["linked_player_id"] as? String
                let dn = data["display_name"] as? String
                let uid = data["uid"] as? String ?? ""

                if let score = data["score"] as? Int {
                    let maxScore = (data["maxScore"] as? Int) ?? (data["max_score"] as? Int)
                    let answers = data["answers"] as? [String: Int]

                    let sub = WeeklyChallengeSubmission(
                        id: submitterId,
                        uid: uid,
                        linkedPlayerId: lp,
                        displayName: dn,
                        answerText: nil,
                        isCorrect: nil,
                        answers: answers,
                        score: score,
                        maxScore: maxScore,
                        submittedAt: submittedAt
                    )

                    Task { @MainActor in self.lastSubmission = sub }
                    return
                }

                if let answerText = data["answerText"] as? String,
                   let isCorrect = data["isCorrect"] as? Bool {

                    let cleaned = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned.isEmpty || cleaned.lowercased() == "null" {
                        Task { @MainActor in self.lastSubmission = nil }
                        return
                    }

                    let sub = WeeklyChallengeSubmission(
                        id: submitterId,
                        uid: uid,
                        linkedPlayerId: lp,
                        displayName: dn,
                        answerText: cleaned,
                        isCorrect: isCorrect,
                        answers: nil,
                        score: nil,
                        maxScore: nil,
                        submittedAt: submittedAt
                    )

                    Task { @MainActor in self.lastSubmission = sub }
                    return
                }

                Task { @MainActor in self.lastSubmission = nil }
            }
    }

    // MARK: - Submitters (quiz/riddle)

    func submitRiddleAnswer(_ text: String, isCorrect: Bool) async throws {
        guard let challengeId = currentChallenge?.id else {
            throw NSError(domain: "WeeklyChallenge", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No active challenge."])
        }
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "WeeklyChallenge", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "You must be logged in to submit."])
        }
        guard let submitterId = self.submitterId else {
            throw NSError(domain: "WeeklyChallenge", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Missing user context."])
        }

        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw NSError(domain: "WeeklyChallenge", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "Answer cannot be empty."])
        }

        let payload: [String: Any] = [
            "uid": uid,
            "linked_player_id": self.linkedPlayerId as Any,
            "display_name": self.submitterDisplayName ?? self.displayName ?? "Unknown",
            "answerText": cleaned,
            "isCorrect": isCorrect,
            "submittedAt": Timestamp(date: Date())
        ]

        try await db.collection("weekly_challenges")
            .document(challengeId)
            .collection("submissions")
            .document(submitterId)
            .setData(payload, merge: true)

        self.lastSubmission = WeeklyChallengeSubmission(
            id: submitterId,
            uid: uid,
            linkedPlayerId: self.linkedPlayerId,
            displayName: self.submitterDisplayName ?? self.displayName,
            answerText: cleaned,
            isCorrect: isCorrect,
            answers: nil,
            score: nil,
            maxScore: nil,
            submittedAt: Date()
        )
    }

    func submitQuiz(answers: [String: Int], score: Int, maxScore: Int) async throws {
        guard let challengeId = currentChallenge?.id else {
            throw NSError(domain: "WeeklyChallenge", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No active challenge."])
        }
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "WeeklyChallenge", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "You must be logged in to submit."])
        }
        guard let submitterId = self.submitterId else {
            throw NSError(domain: "WeeklyChallenge", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Missing user context."])
        }

        let payload: [String: Any] = [
            "uid": uid,
            "linked_player_id": self.linkedPlayerId as Any,
            "display_name": self.submitterDisplayName ?? self.displayName ?? "Unknown",
            "answers": answers,
            "score": score,
            "maxScore": maxScore,
            "submittedAt": Timestamp(date: Date())
        ]

        try await db.collection("weekly_challenges")
            .document(challengeId)
            .collection("submissions")
            .document(submitterId)
            .setData(payload, merge: true)

        self.lastSubmission = WeeklyChallengeSubmission(
            id: submitterId,
            uid: uid,
            linkedPlayerId: self.linkedPlayerId,
            displayName: self.submitterDisplayName ?? self.displayName,
            answerText: nil,
            isCorrect: nil,
            answers: answers,
            score: score,
            maxScore: maxScore,
            submittedAt: Date()
        )
    }
}

// MARK: - Submission models

struct WeeklyChallengeSubmission: Identifiable {
    let id: String
    let uid: String

    let linkedPlayerId: String?
    let displayName: String?

    let answerText: String?
    let isCorrect: Bool?

    let answers: [String: Int]?
    let score: Int?
    let maxScore: Int?

    let submittedAt: Date
}

// ✅ NEW: prop bets submission summary
struct PropBetsPickSummary {
    let submittedAt: Date?
    let selections: [String: String]

    var hasSubmitted: Bool {
        submittedAt != nil && !selections.isEmpty
    }
}
