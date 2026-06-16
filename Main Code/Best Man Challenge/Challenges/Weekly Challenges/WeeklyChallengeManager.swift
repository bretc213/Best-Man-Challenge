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

    // Quiz / Riddle / Wordle / Image Quiz submission (LIVE)
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

    init(autoStart: Bool = true) {
        if autoStart { startActiveChallengeListener() }
    }

    /// Admin/test use only — injects a challenge directly without Firestore.
    func previewChallenge(_ challenge: WeeklyChallenge) {
        stopListening()
        currentChallenge = challenge
        state = .loaded
        lastSubmission = nil
        propBetsPickSummary = nil
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

    private func computeSubmitterId(uid: String, linkedPlayerId: String?) -> String {
        let lp = (linkedPlayerId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !lp.isEmpty { return lp }

        let u = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        return u.isEmpty ? "" : u
    }

    private func resolvedSubmitterId() -> String? {
        if let sid = submitterId, !sid.isEmpty { return sid }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return nil }
        return computeSubmitterId(uid: uid, linkedPlayerId: linkedPlayerId)
    }

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
                    await self.backfillSubmissionDisplayNameIfNeeded(challengeId: challenge.id)
                }
            }
    }

    // MARK: - Submission listeners routing

    private func updateSubmissionListeners(for challenge: WeeklyChallenge) {
        self.lastSubmission = nil
        self.propBetsPickSummary = nil
        stopPropBetsPickListener()
        stopSubmissionListener()

        if challenge.type == .prop_bets {
            if let uid = self.authUid, !uid.isEmpty {
                startPropBetsPickListener(challengeId: challenge.id, uid: uid)
            }
            return
        }

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

    // MARK: - LIVE submission listener

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

    private func backfillSubmissionDisplayNameIfNeeded(challengeId: String) async {
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
        let rules = data["rules"] as? [String]
        let isActiveFlag    = boolValue(data["is_active"])
        let isFinalizedFlag = boolValue(data["is_finalized"])

        let gameFormat = stringValue(data["game_format"])
        var wordle: WeeklyChallengeWordle? = nil
        if let w = data["wordle"] as? [String: Any] {
            wordle = WeeklyChallengeWordle(
                word_length: intValue(w["word_length"]),
                max_attempts: intValue(w["max_attempts"]),
                answer: stringValue(w["answer"])
            )
        }

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

        var cipher: WeeklyChallengeCipher? = nil
        if let c = data["cipher"] as? [String: Any] {
            cipher = WeeklyChallengeCipher(
                type: stringValue(c["type"]),
                ciphertext: stringValue(c["ciphertext"]),
                direction: stringValue(c["direction"]),
                shift: intValue(c["shift"])
            )
        }

        var quiz: WeeklyChallengeQuiz? = nil
        if let q = data["quiz"] as? [String: Any] {
            let pointsPerCorrect = intValue(q["points_per_correct"])
            var questions: [WeeklyQuizQuestion] = []
            var imageQuestions: [WeeklyImageQuizQuestion] = []

            if let rawQs = q["questions"] as? [[String: Any]] {
                for rq in rawQs {
                    guard
                        let id = stringValue(rq["id"]),
                        let prompt = stringValue(rq["prompt"])
                    else { continue }

                    if let imageName = stringValue(rq["image_name"]) {
                        imageQuestions.append(
                            WeeklyImageQuizQuestion(
                                id: id,
                                prompt: prompt,
                                image_name: imageName,
                                answer: stringValue(rq["answer"]),
                                acceptable_answers: rq["acceptable_answers"] as? [String],
                                allow_fuzzy_match: boolValue(rq["allow_fuzzy_match"]),
                                fuzzy_distance: intValue(rq["fuzzy_distance"])
                            )
                        )
                    } else if let options = rq["options"] as? [String] {
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
            }

            quiz = WeeklyChallengeQuiz(
                points_per_correct: pointsPerCorrect,
                questions: questions.isEmpty ? nil : questions,
                image_questions: imageQuestions.isEmpty ? nil : imageQuestions
            )
        }

        // MARK: Multi-Wordle
        var multiWordle: WeeklyChallengeMultiWordle? = nil
        if let mw = data["multi_wordle"] as? [String: Any],
           let rawWords = mw["words"] as? [[String: Any]] {
            let words = rawWords.compactMap { w -> MultiWordleWord? in
                guard let id = stringValue(w["id"]),
                      let answer = stringValue(w["answer"]) else { return nil }
                return MultiWordleWord(
                    id: id,
                    answer: answer.uppercased(),
                    word_length: intValue(w["word_length"]) ?? answer.count,
                    max_attempts: intValue(w["max_attempts"]) ?? 6,
                    label: stringValue(w["label"])
                )
            }
            if !words.isEmpty { multiWordle = WeeklyChallengeMultiWordle(words: words) }
        }

        // MARK: Photo Challenge
        var photoConfig: WeeklyChallengePhotoConfig? = nil
        if let pc = data["photo_challenge"] as? [String: Any],
           let rawPrompts = pc["prompts"] as? [[String: Any]] {
            let prompts = rawPrompts.compactMap { p -> PhotoChallengePrompt? in
                guard let id = stringValue(p["id"]),
                      let label = stringValue(p["label"]) else { return nil }
                return PhotoChallengePrompt(
                    id: id,
                    label: label,
                    emoji: stringValue(p["emoji"]) ?? "📸",
                    description: stringValue(p["description"]) ?? ""
                )
            }
            if !prompts.isEmpty {
                photoConfig = WeeklyChallengePhotoConfig(
                    prompts: prompts,
                    points_per_submission: intValue(pc["points_per_submission"]) ?? 2,
                    bonus_points_per_winner: intValue(pc["bonus_points_per_winner"]) ?? 1,
                    judge_name: stringValue(pc["judge_name"])
                )
            }
        }

        // MARK: Scavenger Hunt
        var scavengerConfig: WeeklyChallengeScavengerHuntConfig? = nil
        if let sh = data["scavenger_hunt"] as? [String: Any],
           let rawItems = sh["items"] as? [[String: Any]] {
            let items = rawItems.compactMap { item -> ScavengerHuntItem? in
                guard let id = stringValue(item["id"]),
                      let clue = stringValue(item["clue"]) else { return nil }
                return ScavengerHuntItem(
                    id: id,
                    clue: clue,
                    emoji: stringValue(item["emoji"]) ?? "📷",
                    point_value: intValue(item["point_value"]) ?? 1
                )
            }
            if !items.isEmpty {
                scavengerConfig = WeeklyChallengeScavengerHuntConfig(
                    items: items,
                    points_per_item: intValue(sh["points_per_item"]) ?? 1
                )
            }
        }

        // MARK: Connections
        var connectionsConfig: WeeklyChallengeConnectionsConfig? = nil
        if let conn = data["connections_config"] as? [String: Any],
           let rawCats = conn["categories"] as? [[String: Any]] {
            let cats = rawCats.compactMap { cat -> ConnectionsCategory? in
                guard let id = stringValue(cat["id"]),
                      let name = stringValue(cat["name"]),
                      let colorRaw = stringValue(cat["color"]),
                      let color = ConnectionsColor(rawValue: colorRaw),
                      let words = cat["words"] as? [String] else { return nil }
                return ConnectionsCategory(
                    id: id,
                    name: name,
                    color: color,
                    words: words.map { $0.uppercased() },
                    point_value: intValue(cat["point_value"]) ?? color.order + 1
                )
            }
            if !cats.isEmpty {
                connectionsConfig = WeeklyChallengeConnectionsConfig(
                    categories: cats,
                    max_mistakes: intValue(conn["max_mistakes"]) ?? 4
                )
            }
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
            rules: rules,
            puzzle: puzzle,
            cipher: cipher,
            quiz: quiz,
            wordle: wordle,
            game_format: gameFormat,
            is_active: isActiveFlag,
            is_finalized: isFinalizedFlag,
            multi_wordle: multiWordle,
            photo_challenge: photoConfig,
            scavenger_hunt: scavengerConfig,
            connections_config: connectionsConfig
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

    private func parseStringMap(_ any: Any?) -> [String: String]? {
        if let map = any as? [String: String] {
            return map
        }
        if let raw = any as? [String: Any] {
            var parsed: [String: String] = [:]
            for (k, v) in raw {
                if let s = v as? String {
                    parsed[k] = s
                }
            }
            return parsed.isEmpty ? nil : parsed
        }
        return nil
    }

    private func parseIntMap(_ any: Any?) -> [String: Int]? {
        if let map = any as? [String: Int] {
            return map
        }
        if let raw = any as? [String: Any] {
            var parsed: [String: Int] = [:]
            for (k, v) in raw {
                if let i = v as? Int { parsed[k] = i }
                else if let d = v as? Double { parsed[k] = Int(d) }
                else if let s = v as? String, let i = Int(s) { parsed[k] = i }
            }
            return parsed.isEmpty ? nil : parsed
        }
        return nil
    }

    private func parseBoolMap(_ any: Any?) -> [String: Bool]? {
        if let map = any as? [String: Bool] {
            return map
        }
        if let raw = any as? [String: Any] {
            var parsed: [String: Bool] = [:]
            for (k, v) in raw {
                if let b = v as? Bool { parsed[k] = b }
                else if let n = v as? NSNumber { parsed[k] = n.boolValue }
            }
            return parsed.isEmpty ? nil : parsed
        }
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

        let wordleAttempts = intValue(data["wordle_attempts"])
        let wordleSolved = data["wordle_solved"] as? Bool
        let wordleGuesses = data["wordle_guesses"] as? [String]

        let score = intValue(data["score"])
        let maxScore = intValue(data["maxScore"]) ?? intValue(data["max_score"])

        let answers = parseIntMap(data["answers"])
        let textAnswers = parseStringMap(data["answers_text"]) ?? parseStringMap(data["answers"])
        let breakdown = parseBoolMap(data["breakdown"])

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
            textAnswers: textAnswers,
            score: score,
            maxScore: maxScore,
            breakdown: breakdown,
            wordleAttempts: wordleAttempts,
            wordleSolved: wordleSolved,
            wordleGuesses: wordleGuesses,
            submittedAt: submittedAt
        )
    }

    // MARK: - Submitters

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

    func submitImageQuiz(
        answers: [String: String],
        score: Int,
        maxScore: Int,
        breakdown: [String: Bool]
    ) async throws {
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
        let trimmedAnswers = answers.mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let payload: [String: Any] = [
            "uid": uid,
            "linked_player_id": self.linkedPlayerId as Any,
            "display_name": bestName,
            "answers_text": trimmedAnswers,
            "score": score,
            "maxScore": maxScore,
            "breakdown": breakdown,
            "submittedAt": Timestamp(date: Date()),
            "updated_at": FieldValue.serverTimestamp()
        ]

        try await db.collection("weekly_challenges")
            .document(challengeId)
            .collection("submissions")
            .document(sid)
            .setData(payload, merge: true)
    }

    func saveImageQuizDraft(challengeId: String, answers: [String: String]) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "WeeklyChallenge", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "You must be logged in."])
        }
        guard let sid = resolvedSubmitterId() else {
            throw NSError(domain: "WeeklyChallenge", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Missing user context."])
        }

        if self.lastSubmission != nil { return }

        let bestName = bestDisplayName(uid: uid)

        try await db.collection("weekly_challenges")
            .document(challengeId)
            .collection("submissions")
            .document(sid)
            .setData([
                "uid": uid,
                "linked_player_id": self.linkedPlayerId as Any,
                "display_name": bestName,
                "image_quiz_draft_answers": answers,
                "image_quiz_draft_updated_at": Timestamp(date: Date())
            ], merge: true)
    }

    func loadImageQuizDraft(challengeId: String) async -> [String: String]? {
        guard let sid = resolvedSubmitterId() else { return nil }

        do {
            let snap = try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("submissions")
                .document(sid)
                .getDocument()

            guard snap.exists, let data = snap.data() else { return nil }
            return parseStringMap(data["image_quiz_draft_answers"])
        } catch {
            print("⚠️ loadImageQuizDraft failed:", error.localizedDescription)
            return nil
        }
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

        self.lastSubmission = WeeklyChallengeSubmission(
            id: sid,
            uid: uid,
            linkedPlayerId: self.linkedPlayerId,
            displayName: bestName,
            answerText: nil,
            isCorrect: nil,
            answers: nil,
            textAnswers: nil,
            score: points,
            maxScore: maxAttempts,
            breakdown: nil,
            wordleAttempts: attemptsUsed,
            wordleSolved: solved,
            wordleGuesses: guesses,
            submittedAt: now
        )
    }

    func saveWordleProgress(challengeId: String, guesses: [String]) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "WeeklyChallenge", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "You must be logged in."])
        }
        guard let sid = resolvedSubmitterId() else {
            throw NSError(domain: "WeeklyChallenge", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Missing user context."])
        }

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
    let textAnswers: [String: String]?
    let score: Int?
    let maxScore: Int?
    let breakdown: [String: Bool]?

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
        textAnswers: [String: String]? = nil,
        score: Int? = nil,
        maxScore: Int? = nil,
        breakdown: [String: Bool]? = nil,
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
        self.textAnswers = textAnswers
        self.score = score
        self.maxScore = maxScore
        self.breakdown = breakdown
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
