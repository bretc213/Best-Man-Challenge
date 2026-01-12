//
//  WeeklyChallengesHistoryStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/7/26.
//

import Foundation
import FirebaseFirestore

@MainActor
final class WeeklyChallengesHistoryStore: ObservableObject {
    @Published var pastChallenges: [WeeklyChallenge] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening() {
        errorMessage = nil
        isLoading = true

        listener?.remove()
        listener = db.collection("weekly_challenges")
            .whereField("is_active", isEqualTo: false)
            .order(by: "week", descending: true)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }

                if let err {
                    Task { @MainActor in
                        self.errorMessage = err.localizedDescription
                        self.isLoading = false
                    }
                    return
                }

                let docs = snap?.documents ?? []

                let parsed: [WeeklyChallenge] = docs.compactMap { doc in
                    Self.parseWeeklyChallenge(doc: doc)
                }

                Task { @MainActor in
                    self.pastChallenges = parsed
                    self.isLoading = false
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        isLoading = false
    }

    // MARK: - Parsing (mirrors WeeklyChallengeManager)

    private static func parseWeeklyChallenge(doc: QueryDocumentSnapshot) -> WeeklyChallenge? {
        let data = doc.data()

        guard
            let week = data["week"] as? Int,
            let title = data["title"] as? String,
            let description = data["description"] as? String,
            let typeRaw = data["type"] as? String,
            let type = ChallengeType(rawValue: typeRaw),
            let startTimestamp = data["startDate"] as? Timestamp,
            let endTimestamp = data["endDate"] as? Timestamp
        else { return nil }

        let answer = data["answer"] as? String
        let isActiveFlag = data["is_active"] as? Bool

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

        var cipher: WeeklyChallengeCipher? = nil
        if let c = data["cipher"] as? [String: Any] {
            cipher = WeeklyChallengeCipher(
                type: c["type"] as? String,
                ciphertext: c["ciphertext"] as? String,
                direction: c["direction"] as? String,
                shift: c["shift"] as? Int
            )
        }

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

        return WeeklyChallenge(
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
    }
}
