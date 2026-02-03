//
//  WeeklyChallenge.swift
//

import Foundation

// MARK: - Nested puzzle/cipher models (matches Firestore document shape)

struct WeeklyChallengePuzzle: Codable {
    let type: String?           // "mini_sudoku_4x4"
    let size: Int?              // 4
    let grid: [Int]?            // flat array length 16, 0 = empty

    let unlock_rule: String?
    let unlock_value: Int?
    let unlock_text: String?
}

struct WeeklyChallengeCipher: Codable {
    let type: String?           // "caesar"
    let ciphertext: String?
    let direction: String?      // "back"
    let shift: Int?
}

// MARK: - Quiz models

struct WeeklyQuizQuestion: Codable, Identifiable {
    let id: String
    let prompt: String
    let options: [String]
    let correct_index: Int?
}

struct WeeklyChallengeQuiz: Codable {
    let points_per_correct: Int?
    let questions: [WeeklyQuizQuestion]?
}

// MARK: - Main model

struct WeeklyChallenge: Identifiable, Codable {
    var id: String

    let week: Int
    let title: String
    let description: String
    let type: ChallengeType

    // ✅ Optional so prop_bets can exist without “timer dates”
    let startDate: Date?
    let endDate: Date?

    // ✅ Prop-bets locking (kickoff)
    let locksAt: Date?

    // Riddle-style challenge
    let answer: String?

    // Puzzle/cipher challenge
    let puzzle: WeeklyChallengePuzzle?
    let cipher: WeeklyChallengeCipher?

    // Quiz challenge
    let quiz: WeeklyChallengeQuiz?

    // Optional Firestore flag
    let is_active: Bool?

    // MARK: - Derived

    var isActive: Bool {
        if let is_active { return is_active }

        if let startDate, let endDate {
            let now = Date()
            return now >= startDate && now < endDate
        }

        // If no start/end, default active
        return true
    }

    var isExpired: Bool {
        if let endDate {
            return Date() >= endDate
        }
        return false
    }

    var isLocked: Bool {
        guard let locksAt else { return false }
        return Date() >= locksAt
    }
}
