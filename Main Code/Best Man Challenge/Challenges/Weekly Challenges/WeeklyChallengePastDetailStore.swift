//
//  WeeklyChallengePastDetailStore.swift
//  Best Man Challenge
//
//  Fetches a single user's submission for a past (inactive) weekly challenge.
//  Uses a one-time read since past challenges are finalized / read-only.
//

import Foundation
import FirebaseFirestore

@MainActor
final class WeeklyChallengePastDetailStore: ObservableObject {
    @Published var submission: WeeklyChallengeSubmission?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func load(challengeId: String, submitterId: String) async {
        guard !challengeId.isEmpty, !submitterId.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let snap = try await db
                .collection("weekly_challenges")
                .document(challengeId)
                .collection("submissions")
                .document(submitterId)
                .getDocument()

            guard snap.exists, let data = snap.data() else {
                submission = nil
                return
            }

            submission = Self.parse(id: submitterId, data: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Parsing

    static func parse(id: String, data: [String: Any]) -> WeeklyChallengeSubmission {
        func intVal(_ v: Any?) -> Int? {
            if let i = v as? Int    { return i }
            if let i = v as? Int64  { return Int(i) }
            if let d = v as? Double { return Int(d) }
            if let n = v as? NSNumber { return n.intValue }
            return nil
        }

        let submittedAt =
            (data["submittedAt"] as? Timestamp)?.dateValue()
            ?? (data["submitted_at"] as? Timestamp)?.dateValue()
            ?? Date()

        let uid = data["uid"] as? String ?? ""
        let lp  = data["linked_player_id"] as? String
        let dn  = data["display_name"] as? String

        let score    = intVal(data["score"])
        let maxScore = intVal(data["maxScore"]) ?? intVal(data["max_score"])

        // answers: [String: Int] (quiz)
        var answers: [String: Int]? = nil
        if let raw = data["answers"] as? [String: Any] {
            var parsed: [String: Int] = [:]
            for (k, v) in raw {
                if let i = intVal(v) { parsed[k] = i }
            }
            if !parsed.isEmpty { answers = parsed }
        }

        // textAnswers: [String: String] (image quiz)
        var textAnswers: [String: String]? = nil
        for key in ["answers_text", "answers"] {
            if let raw = data[key] as? [String: Any] {
                var parsed: [String: String] = [:]
                for (k, v) in raw { if let s = v as? String { parsed[k] = s } }
                if !parsed.isEmpty { textAnswers = parsed; break }
            }
        }

        // breakdown: [String: Bool] (image quiz correctness)
        var breakdown: [String: Bool]? = nil
        if let raw = data["breakdown"] as? [String: Any] {
            var parsed: [String: Bool] = [:]
            for (k, v) in raw {
                if let b = v as? Bool { parsed[k] = b }
                else if let n = v as? NSNumber { parsed[k] = n.boolValue }
            }
            if !parsed.isEmpty { breakdown = parsed }
        }

        let answerText = data["answerText"] as? String
        let isCorrect  = data["isCorrect"] as? Bool

        let wordleAttempts = intVal(data["wordle_attempts"])
        let wordleSolved   = data["wordle_solved"] as? Bool
        let wordleGuesses  = data["wordle_guesses"] as? [String]

        return WeeklyChallengeSubmission(
            id: id,
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
}
