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
    @Published var lastSubmission: WeeklyChallengeSubmission?

    // ✅ Store user context once (set from SessionStore)
    @Published private(set) var linkedPlayerId: String?
    @Published private(set) var displayName: String?

    private let db = Firestore.firestore()

    // ✅ Live listener for the active challenge
    private var activeListener: ListenerRegistration?

    init() {
        startActiveChallengeListener()
    }

    deinit {
        // ✅ IMPORTANT: Do NOT create Tasks in deinit.
        // Removing the listener here is safe and synchronous.
        activeListener?.remove()
        activeListener = nil
    }

    func stopListening() {
        activeListener?.remove()
        activeListener = nil
    }

    func refresh() {
        startActiveChallengeListener()
    }

    /// Call this once you have a logged-in session (e.g., onAppear).
    func setUserContext(linkedPlayerId: String?, displayName: String?) {
        let lp = (linkedPlayerId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let dn = (displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        self.linkedPlayerId = lp.isEmpty ? nil : lp
        self.displayName = dn.isEmpty ? nil : dn

        // If we already have a challenge loaded, refresh lastSubmission immediately.
        if let cid = currentChallenge?.id, let lp = self.linkedPlayerId {
            loadMyLatestSubmissionIfPossible(challengeId: cid, linkedPlayerId: lp)
        } else {
            self.lastSubmission = nil
        }
    }

    // MARK: - Active Challenge (LIVE)

    func startActiveChallengeListener() {
        state = .loading
        currentChallenge = nil
        lastSubmission = nil

        activeListener?.remove()
        activeListener = nil

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
                    }
                    return
                }

                guard let doc = snapshot?.documents.first else {
                    Task { @MainActor in
                        self.state = .empty
                        self.currentChallenge = nil
                        self.lastSubmission = nil
                    }
                    return
                }

                let data = doc.data()

                guard
                    let week = data["week"] as? Int,
                    let title = data["title"] as? String,
                    let description = data["description"] as? String,
                    let typeRaw = data["type"] as? String,
                    let type = ChallengeType(rawValue: typeRaw),
                    let startTimestamp = data["startDate"] as? Timestamp,
                    let endTimestamp = data["endDate"] as? Timestamp
                else {
                    Task { @MainActor in
                        self.state = .failed(
                            "Weekly challenge document has invalid or missing fields.\n" +
                            "Expected: week(Int), title(String), description(String), type(String), startDate(Timestamp), endDate(Timestamp)"
                        )
                        self.currentChallenge = nil
                        self.lastSubmission = nil
                    }
                    return
                }

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
                                let options = rq["options"] as? [String],
                                let correctIndex = rq["correct_index"] as? Int
                            else { continue }

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

                let challenge = WeeklyChallenge(
                    id: doc.documentID,
                    week: week,
                    title: title,
                    description: description,
                    type: type,
                    startDate: startTimestamp.dateValue(),
                    endDate: endTimestamp.dateValue(),
                    answer: answer,
                    puzzle: puzzle,
                    cipher: cipher,
                    quiz: quiz,
                    is_active: isActiveFlag
                )

                Task { @MainActor in
                    self.currentChallenge = challenge
                    self.state = .loaded

                    // Reload user's submission when challenge updates
                    if let lp = self.linkedPlayerId {
                        self.loadMyLatestSubmissionIfPossible(
                            challengeId: challenge.id,
                            linkedPlayerId: lp
                        )
                    } else {
                        self.lastSubmission = nil
                    }
                }
            }
    }

    // MARK: - My Submission (by linkedPlayerId)

    private func loadMyLatestSubmissionIfPossible(challengeId: String, linkedPlayerId: String) {
        db.collection("weekly_challenges")
            .document(challengeId)
            .collection("submissions")
            .document(linkedPlayerId)
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

                let lp = data["linked_player_id"] as? String ?? linkedPlayerId
                let dn = data["display_name"] as? String

                if let score = data["score"] as? Int {
                    let maxScore = (data["maxScore"] as? Int) ?? (data["max_score"] as? Int)
                    let answers = data["answers"] as? [String: Int]
                    let uid = data["uid"] as? String ?? ""

                    let sub = WeeklyChallengeSubmission(
                        id: linkedPlayerId,
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

                    let uid = data["uid"] as? String ?? ""

                    let sub = WeeklyChallengeSubmission(
                        id: linkedPlayerId,
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

    // MARK: - Submitters

    func submitRiddleAnswer(
        _ text: String,
        isCorrect: Bool,
        linkedPlayerId: String,
        displayName: String
    ) async throws {

        guard let challengeId = currentChallenge?.id else {
            throw NSError(domain: "WeeklyChallenge", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No active challenge."])
        }
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "WeeklyChallenge", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "You must be logged in to submit."])
        }

        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw NSError(domain: "WeeklyChallenge", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Answer cannot be empty."])
        }

        let payload: [String: Any] = [
            "uid": uid,
            "linked_player_id": linkedPlayerId,
            "display_name": displayName,
            "answerText": cleaned,
            "isCorrect": isCorrect,
            "submittedAt": Timestamp(date: Date())
        ]

        try await db.collection("weekly_challenges")
            .document(challengeId)
            .collection("submissions")
            .document(linkedPlayerId)
            .setData(payload, merge: true)

        self.lastSubmission = WeeklyChallengeSubmission(
            id: linkedPlayerId,
            uid: uid,
            linkedPlayerId: linkedPlayerId,
            displayName: displayName,
            answerText: cleaned,
            isCorrect: isCorrect,
            answers: nil,
            score: nil,
            maxScore: nil,
            submittedAt: Date()
        )
    }

    func submitQuiz(
        linkedPlayerId: String,
        displayName: String,
        answers: [String: Int],
        score: Int,
        maxScore: Int
    ) async throws {

        guard let challengeId = currentChallenge?.id else {
            throw NSError(domain: "WeeklyChallenge", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No active challenge."])
        }
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "WeeklyChallenge", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "You must be logged in to submit."])
        }

        let lp = linkedPlayerId.trimmingCharacters(in: .whitespacesAndNewlines)
        let dn = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        let payload: [String: Any] = [
            "uid": uid,
            "linked_player_id": lp,
            "display_name": dn,
            "answers": answers,
            "score": score,
            "maxScore": maxScore,
            "submittedAt": Timestamp(date: Date())
        ]

        try await db.collection("weekly_challenges")
            .document(challengeId)
            .collection("submissions")
            .document(lp)
            .setData(payload, merge: true)

        self.lastSubmission = WeeklyChallengeSubmission(
            id: lp,
            uid: uid,
            linkedPlayerId: lp,
            displayName: dn,
            answerText: nil,
            isCorrect: nil,
            answers: answers,
            score: score,
            maxScore: maxScore,
            submittedAt: Date()
        )
    }
}

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
