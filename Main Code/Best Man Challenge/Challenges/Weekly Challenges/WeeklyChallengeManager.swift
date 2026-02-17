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

    // Quiz / Riddle / Wordle submission (LIVE)
    @Published var lastSubmission: WeeklyChallengeSubmission?

    // Prop bets submission summary (LIVE)
    @Published var propBetsPickSummary: PropBetsPickSummary?

    // User context (from SessionStore)
    @Published private(set) var linkedPlayerId: String?
    @Published private(set) var displayName: String?

    // /submissions/{submitterId}
    @Published private(set) var submitterId: String?
    @Published private(set) var submitterDisplayName: String?

    // Raw auth uid (prop bets uses picks/{uid})
    @Published private(set) var authUid: String?

    private let db = Firestore.firestore()
    private var activeListener: ListenerRegistration?
    private var propBetsPickListener: ListenerRegistration?
    private var submissionListener: ListenerRegistration?

    init() {
        startActiveChallengeListener()
    }

    deinit {
        activeListener?.remove()
        propBetsPickListener?.remove()
        submissionListener?.remove()
    }

    func stopListening() {
        activeListener?.remove()
        activeListener = nil

        propBetsPickListener?.remove()
        propBetsPickListener = nil

        submissionListener?.remove()
        submissionListener = nil
    }

    func refresh() {
        startActiveChallengeListener()
    }

    // MARK: - User Context

    /// ✅ Use linked_player_id if present, otherwise fall back to uid (NOT admin_ prefix)
    private func computeSubmitterId(uid: String, linkedPlayerId: String?) -> String {
        let lp = (linkedPlayerId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !lp.isEmpty { return lp }

        let u = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        return u.isEmpty ? "" : u
    }

    /// Always returns the best submitter id we can, even if setUserContext wasn’t called yet.
    private func resolvedSubmitterId() -> String? {
        if let sid = submitterId, !sid.isEmpty { return sid }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return nil }
        return computeSubmitterId(uid: uid, linkedPlayerId: linkedPlayerId)
    }

    /// ✅ Canonical display name chooser (SessionStore name > Auth displayName > uid)
    private func bestDisplayName(uid: String) -> String {
        let authName = Auth.auth().currentUser?.displayName

        let cleanedSubmitter =
            (self.submitterDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines))
                .flatMap { $0.isEmpty ? nil : $0 }

        let cleanedProfile =
            (self.displayName?.trimmingCharacters(in: .whitespacesAndNewlines))
                .flatMap { $0.isEmpty ? nil : $0 }

        let cleanedAuth =
            (authName?.trimmingCharacters(in: .whitespacesAndNewlines))
                .flatMap { $0.isEmpty ? nil : $0 }

        return cleanedSubmitter ?? cleanedProfile ?? cleanedAuth ?? uid
    }

    /// Call this once you have a logged-in session (e.g., onAppear).
    func setUserContext(uid: String?, linkedPlayerId: String?, displayName: String?) {
        let dn = (displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let uidClean = (uid ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lp = (linkedPlayerId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        self.linkedPlayerId = lp.isEmpty ? nil : lp
        self.displayName = dn.isEmpty ? nil : dn
        self.authUid = uidClean.isEmpty ? nil : uidClean

        guard !uidClean.isEmpty else {
            self.submitterId = nil
            self.submitterDisplayName = self.displayName
            self.lastSubmission = nil
            self.propBetsPickSummary = nil
            stopPropBetsPickListener()
            stopSubmissionListener()
            return
        }

        let sid = computeSubmitterId(uid: uidClean, linkedPlayerId: self.linkedPlayerId)
        self.submitterId = sid

        // Prefer SessionStore displayName; fall back to Auth displayName; then sid
        let authName = Auth.auth().currentUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let dn = self.displayName, !dn.isEmpty {
            self.submitterDisplayName = dn
        } else if let authName, !authName.isEmpty {
            self.submitterDisplayName = authName
        } else {
            self.submitterDisplayName = sid
        }

        if let challenge = currentChallenge {
            updateSubmissionListeners(for: challenge)

            // ✅ If you previously wrote uid/Unknown into the submission doc, patch it once
            Task { @MainActor in
                await self.backfillSubmissionDisplayNameIfNeeded(challengeId: challenge.id)
            }
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
        stopSubmissionListener()

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
                        self.stopSubmissionListener()
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
                        self.stopSubmissionListener()
                    }
                    return
                }

                guard let challenge = Self.parseWeeklyChallenge(doc: doc) else {
                    let raw = doc.data()
                    print("❌ Failed to parse weekly challenge:", doc.documentID)
                    for (k, v) in raw { print("• \(k): \(type(of: v)) => \(v)") }

                    Task { @MainActor in
                        self.state = .failed(
                            "Weekly challenge document has invalid or missing fields.\n" +
                            "Expected at minimum: week(Int), title(String), description(String), type(String)."
                        )
                        self.currentChallenge = nil
                        self.lastSubmission = nil
                        self.propBetsPickSummary = nil
                        self.stopPropBetsPickListener()
                        self.stopSubmissionListener()
                    }
                    return
                }

                Task { @MainActor in
                    self.currentChallenge = challenge
                    self.state = .loaded
                    self.updateSubmissionListeners(for: challenge)

                    // ✅ If we already have a submission and the profile name is now known, patch it once
                    await self.backfillSubmissionDisplayNameIfNeeded(challengeId: challenge.id)
                }
            }
    }

    // MARK: - Submission listeners routing

    private func updateSubmissionListeners(for challenge: WeeklyChallenge) {
        // reset
        self.lastSubmission = nil
        self.propBetsPickSummary = nil
        stopPropBetsPickListener()
        stopSubmissionListener()

        // Prop bets uses picks/{uid}
        if challenge.type == .prop_bets {
            if let uid = self.authUid, !uid.isEmpty {
                startPropBetsPickListener(challengeId: challenge.id, uid: uid)
            }
            return
        }

        // Everything else uses submissions/{submitterId}
        guard let sid = resolvedSubmitterId(), !sid.isEmpty else {
            self.lastSubmission = nil
            return
        }

        startSubmissionListener(challengeId: challenge.id, submitterId: sid)
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
                print("⚠️ prop bets pick listener error:", err.localizedDescription)
                return
            }

            guard let snap, snap.exists, let data = snap.data() else {
                Task { @MainActor in self.propBetsPickSummary = nil }
                return
            }

            let selections = data["selections"] as? [String: String] ?? [:]
            let submittedAt = (data["submitted_at"] as? Timestamp)?.dateValue()
                ?? (data["submittedAt"] as? Timestamp)?.dateValue()

            Task { @MainActor in
                self.propBetsPickSummary = PropBetsPickSummary(
                    submittedAt: submittedAt,
                    selections: selections
                )
            }
        }
    }

    // MARK: - LIVE submission listener (Quiz / Riddle / Wordle)

    private func stopSubmissionListener() {
        submissionListener?.remove()
        submissionListener = nil
    }

    private func startSubmissionListener(challengeId: String, submitterId: String) {
        stopSubmissionListener()

        let ref = db.collection("weekly_challenges")
            .document(challengeId)
            .collection("submissions")
            .document(submitterId)

        submissionListener = ref.addSnapshotListener { [weak self] snap, err in
            guard let self else { return }

            if let err = err {
                print("⚠️ submission listener error:", err.localizedDescription)
                return
            }

            guard let snap, snap.exists, let data = snap.data() else {
                Task { @MainActor in self.lastSubmission = nil }
                return
            }

            let submission = self.parseSubmissionDoc(submitterId: submitterId, data: data)
            Task { @MainActor in
                self.lastSubmission = submission
            }
        }
    }

    // MARK: - Backfill display name (fix old submissions that wrote uid/Unknown)

    private func backfillSubmissionDisplayNameIfNeeded(challengeId: String) async {
        // Only for submissions/{submitterId} challenges (not prop bets)
        guard currentChallenge?.type != .prop_bets else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        guard let sid = resolvedSubmitterId(), !sid.isEmpty else { return }

        let desired = bestDisplayName(uid: uid).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desired.isEmpty, desired.lowercased() != "unknown", desired != uid else { return }

        do {
            let ref = db.collection("weekly_challenges")
                .document(challengeId)
                .collection("submissions")
                .document(sid)

            let snap = try await ref.getDocument()
            guard snap.exists else { return }
            let data = snap.data() ?? [:]

            let existing = (data["display_name"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Patch only if missing/unknown/equals uid
            if existing == nil || existing?.isEmpty == true || existing?.lowercased() == "unknown" || existing == uid {
                try await ref.setData(["display_name": desired], merge: true)
            }
        } catch {
            print("⚠️ backfillSubmissionDisplayNameIfNeeded failed:", error.localizedDescription)
        }
    }

    // MARK: - Parsing (Weekly Challenge)

    static func parseWeeklyChallenge(doc: QueryDocumentSnapshot) -> WeeklyChallenge? {
        let data = doc.data()

        func intValue(_ any: Any?) -> Int? {
            if let i = any as? Int { return i }
            if let i = any as? Int64 { return Int(i) }
            if let d = any as? Double { return Int(d) }
            if let n = any as? NSNumber { return n.intValue }
            return nil
        }

        func boolValue(_ any: Any?) -> Bool? {
            if let b = any as? Bool { return b }
            if let n = any as? NSNumber { return n.boolValue }
            return nil
        }

        func stringValue(_ any: Any?) -> String? { any as? String }

        guard
            let week = intValue(data["week"]),
            let title = stringValue(data["title"]),
            let description = stringValue(data["description"]),
            let typeRaw = stringValue(data["type"]),
            let type = ChallengeType(rawValue: typeRaw)
        else { return nil }

        let startDate = (data["startDate"] as? Timestamp)?.dateValue()
        let endDate   = (data["endDate"] as? Timestamp)?.dateValue()
        let locksAt   = (data["locksAt"] as? Timestamp)?.dateValue()

        let answer = stringValue(data["answer"])
        let isActiveFlag = boolValue(data["is_active"])

        // Wordle extras (optional)
        let gameFormat = stringValue(data["game_format"])
        var wordle: WeeklyChallengeWordle? = nil
        if let w = data["wordle"] as? [String: Any] {
            wordle = WeeklyChallengeWordle(
                word_length: intValue(w["word_length"]),
                max_attempts: intValue(w["max_attempts"]),
                answer: stringValue(w["answer"])
            )
        }

        // Puzzle (optional)
        var puzzle: WeeklyChallengePuzzle? = nil
        if let p = data["puzzle"] as? [String: Any] {
            puzzle = WeeklyChallengePuzzle(
                type: stringValue(p["type"]),
                size: intValue(p["size"]),
                grid: p["grid"] as? [Int],
                unlock_rule: stringValue(p["unlock_rule"]),
                unlock_value: intValue(p["unlock_value"]),
                unlock_text: stringValue(p["unlock_text"])
            )
        }

        // Cipher (optional)
        var cipher: WeeklyChallengeCipher? = nil
        if let c = data["cipher"] as? [String: Any] {
            cipher = WeeklyChallengeCipher(
                type: stringValue(c["type"]),
                ciphertext: stringValue(c["ciphertext"]),
                direction: stringValue(c["direction"]),
                shift: intValue(c["shift"])
            )
        }

        // Quiz (optional)
        var quiz: WeeklyChallengeQuiz? = nil
        if let q = data["quiz"] as? [String: Any] {
            let pointsPerCorrect = intValue(q["points_per_correct"])
            var questions: [WeeklyQuizQuestion] = []

            if let rawQs = q["questions"] as? [[String: Any]] {
                for rq in rawQs {
                    guard
                        let id = stringValue(rq["id"]),
                        let prompt = stringValue(rq["prompt"]),
                        let options = rq["options"] as? [String]
                    else { continue }

                    questions.append(
                        WeeklyQuizQuestion(
                            id: id,
                            prompt: prompt,
                            options: options,
                            correct_index: intValue(rq["correct_index"])
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
            wordle: wordle,
            game_format: gameFormat,
            is_active: isActiveFlag
        )
    }

    // MARK: - Submission parsing

    private func intValue(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let i = any as? Int64 { return Int(i) }
        if let d = any as? Double { return Int(d) }
        if let n = any as? NSNumber { return n.intValue }
        return nil
    }

    private func parseSubmissionDoc(submitterId: String, data: [String: Any]) -> WeeklyChallengeSubmission {
        let submittedAt =
            (data["submittedAt"] as? Timestamp)?.dateValue()
            ?? (data["submitted_at"] as? Timestamp)?.dateValue()
            ?? Date()

        let uid = data["uid"] as? String ?? ""
        let lp = data["linked_player_id"] as? String
        let dn = data["display_name"] as? String

        // Wordle fields
        let wordleAttempts = intValue(data["wordle_attempts"])
        let wordleSolved = data["wordle_solved"] as? Bool
        let wordleGuesses = data["wordle_guesses"] as? [String]

        // Score-based (Quiz OR Wordle result)
        let score = intValue(data["score"])
        let maxScore = intValue(data["maxScore"]) ?? intValue(data["max_score"])

        // Quiz answers (optional)
        let answers = data["answers"] as? [String: Int]

        // Riddle fields
        let answerText = data["answerText"] as? String
        let isCorrect = data["isCorrect"] as? Bool

        return WeeklyChallengeSubmission(
            id: submitterId,
            uid: uid,
            linkedPlayerId: lp,
            displayName: dn,
            answerText: answerText,
            isCorrect: isCorrect,
            answers: answers,
            score: score,
            maxScore: maxScore,
            wordleAttempts: wordleAttempts,
            wordleSolved: wordleSolved,
            wordleGuesses: wordleGuesses,
            submittedAt: submittedAt
        )
    }

    // MARK: - Submitters (Riddle / Quiz)

    func submitRiddleAnswer(_ text: String, isCorrect: Bool) async throws {
        guard let challengeId = currentChallenge?.id else {
            throw NSError(domain: "WeeklyChallenge", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No active challenge."])
        }
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "WeeklyChallenge", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "You must be logged in to submit."])
        }
        guard let sid = resolvedSubmitterId() else {
            throw NSError(domain: "WeeklyChallenge", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Missing user context."])
        }

        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw NSError(domain: "WeeklyChallenge", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "Answer cannot be empty."])
        }

        let bestName = bestDisplayName(uid: uid)

        let payload: [String: Any] = [
            "uid": uid,
            "linked_player_id": self.linkedPlayerId as Any,
            "display_name": bestName,
            "answerText": cleaned,
            "isCorrect": isCorrect,
            "submittedAt": Timestamp(date: Date())
        ]

        try await db.collection("weekly_challenges")
            .document(challengeId)
            .collection("submissions")
            .document(sid)
            .setData(payload, merge: true)
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
        guard let sid = resolvedSubmitterId() else {
            throw NSError(domain: "WeeklyChallenge", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Missing user context."])
        }

        let bestName = bestDisplayName(uid: uid)

        let payload: [String: Any] = [
            "uid": uid,
            "linked_player_id": self.linkedPlayerId as Any,
            "display_name": bestName,
            "answers": answers,
            "score": score,
            "maxScore": maxScore,
            "submittedAt": Timestamp(date: Date())
        ]

        try await db.collection("weekly_challenges")
            .document(challengeId)
            .collection("submissions")
            .document(sid)
            .setData(payload, merge: true)
    }

    // MARK: - Wordle: finish submit (points + completion)

    func submitWordleResult(
        challengeId: String,
        attemptsUsed: Int,
        solved: Bool,
        guesses: [String],
        maxAttempts: Int
    ) async throws {

        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "WeeklyChallenge", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "You must be logged in to submit."])
        }
        guard let sid = resolvedSubmitterId() else {
            throw NSError(domain: "WeeklyChallenge", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Missing user context."])
        }

        let bestName = bestDisplayName(uid: uid)

        // Scoring: solved in 1 => maxAttempts, solved in maxAttempts => 1, fail => 0
        let points = solved ? max(1, (maxAttempts + 6) - attemptsUsed) : 0
        let now = Date()

        let payload: [String: Any] = [
            "uid": uid,
            "linked_player_id": self.linkedPlayerId as Any,
            "display_name": bestName,

            "score": points,
            "maxScore": maxAttempts,
            "submittedAt": Timestamp(date: now),

            "wordle_attempts": attemptsUsed,
            "wordle_solved": solved,
            "wordle_guesses": guesses
        ]

        try await db.collection("weekly_challenges")
            .document(challengeId)
            .collection("submissions")
            .document(sid)
            .setData(payload, merge: true)

        // Keep UI snappy; listener will also update
        self.lastSubmission = WeeklyChallengeSubmission(
            id: sid,
            uid: uid,
            linkedPlayerId: self.linkedPlayerId,
            displayName: bestName,
            answerText: nil,
            isCorrect: nil,
            answers: nil,
            score: points,
            maxScore: maxAttempts,
            wordleAttempts: attemptsUsed,
            wordleSolved: solved,
            wordleGuesses: guesses,
            submittedAt: now
        )
    }

    // MARK: - Wordle Progress (persist after ENTER, restore on reopen)

    func saveWordleProgress(challengeId: String, guesses: [String]) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "WeeklyChallenge", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "You must be logged in."])
        }
        guard let sid = resolvedSubmitterId() else {
            throw NSError(domain: "WeeklyChallenge", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Missing user context."])
        }

        // Don’t overwrite finished result
        if let sub = self.lastSubmission, sub.isWordleFinished { return }

        let bestName = bestDisplayName(uid: uid)

        let payload: [String: Any] = [
            "uid": uid,
            "linked_player_id": self.linkedPlayerId as Any,
            "display_name": bestName,
            "wordle_progress_guesses": guesses,
            "wordle_progress_updatedAt": Timestamp(date: Date())
        ]

        try await db.collection("weekly_challenges")
            .document(challengeId)
            .collection("submissions")
            .document(sid)
            .setData(payload, merge: true)
    }

    func loadWordleProgress(challengeId: String) async -> [String] {
        guard let sid = resolvedSubmitterId() else { return [] }

        do {
            let snap = try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("submissions")
                .document(sid)
                .getDocument()

            guard snap.exists, let data = snap.data() else { return [] }

            // If finished, return final guesses
            if let finished = data["wordle_guesses"] as? [String], !finished.isEmpty {
                return finished
            }

            return data["wordle_progress_guesses"] as? [String] ?? []
        } catch {
            print("⚠️ loadWordleProgress failed:", error.localizedDescription)
            return []
        }
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

    // Wordle (optional)
    let wordleAttempts: Int?
    let wordleSolved: Bool?
    let wordleGuesses: [String]?

    let submittedAt: Date

    var isWordleFinished: Bool {
        return wordleSolved != nil
            || wordleAttempts != nil
            || (wordleGuesses?.isEmpty == false)
    }

    init(
        id: String,
        uid: String,
        linkedPlayerId: String? = nil,
        displayName: String? = nil,
        answerText: String? = nil,
        isCorrect: Bool? = nil,
        answers: [String: Int]? = nil,
        score: Int? = nil,
        maxScore: Int? = nil,
        wordleAttempts: Int? = nil,
        wordleSolved: Bool? = nil,
        wordleGuesses: [String]? = nil,
        submittedAt: Date
    ) {
        self.id = id
        self.uid = uid
        self.linkedPlayerId = linkedPlayerId
        self.displayName = displayName
        self.answerText = answerText
        self.isCorrect = isCorrect
        self.answers = answers
        self.score = score
        self.maxScore = maxScore
        self.wordleAttempts = wordleAttempts
        self.wordleSolved = wordleSolved
        self.wordleGuesses = wordleGuesses
        self.submittedAt = submittedAt
    }
}

// MARK: - Prop bets summary

struct PropBetsPickSummary {
    let submittedAt: Date?
    let selections: [String: String]

    var hasSubmitted: Bool {
        submittedAt != nil && !selections.isEmpty
    }
}
