//
//  WeeklyChallenge.swift
//

import Foundation

// MARK: - Nested puzzle/cipher models (matches Firestore document shape)

struct WeeklyChallengePuzzle: Codable {
    let type: String?
    let size: Int?
    let grid: [Int]?

    let unlock_rule: String?
    let unlock_value: Int?
    let unlock_text: String?
}

struct WeeklyChallengeCipher: Codable {
    let type: String?
    let ciphertext: String?
    let direction: String?
    let shift: Int?
}

// MARK: - Wordle models

struct WeeklyChallengeWordle: Codable {
    let word_length: Int?
    let max_attempts: Int?
    let answer: String?
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
    
    let startDate: Date?
    let endDate: Date?
    let locksAt: Date?
    
    let answer: String?
    
    let puzzle: WeeklyChallengePuzzle?
    let cipher: WeeklyChallengeCipher?
    let quiz: WeeklyChallengeQuiz?
    
    // ✅ Wordle extras (optional)
    let wordle: WeeklyChallengeWordle?
    let game_format: String?
    
    // Optional Firestore flag
    let is_active: Bool?
    
    // ✅ Explicit initializer with defaults (so older call sites keep compiling)
    init(
        id: String,
        week: Int,
        title: String,
        description: String,
        type: ChallengeType,
        startDate: Date? = nil,
        endDate: Date? = nil,
        locksAt: Date? = nil,
        answer: String? = nil,
        puzzle: WeeklyChallengePuzzle? = nil,
        cipher: WeeklyChallengeCipher? = nil,
        quiz: WeeklyChallengeQuiz? = nil,
        wordle: WeeklyChallengeWordle? = nil,
        game_format: String? = nil,
        is_active: Bool? = nil
    ) {
        self.id = id
        self.week = week
        self.title = title
        self.description = description
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.locksAt = locksAt
        self.answer = answer
        self.puzzle = puzzle
        self.cipher = cipher
        self.quiz = quiz
        self.wordle = wordle
        self.game_format = game_format
        self.is_active = is_active
    }
    
    // MARK: - Derived
    
    var isActive: Bool {
        if let is_active { return is_active }
        
        if let startDate, let endDate {
            let now = Date()
            return now >= startDate && now < endDate
        }
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
    
    // MARK: - Wordle helpers
    
    var isWordle: Bool {
        if let game_format, game_format.lowercased() == "wordle" { return true }
        return wordle != nil || type == .wordle
    }
    
    var wordleWordLength: Int {
        wordle?.word_length ?? 5
    }
    
    var wordleMaxAttempts: Int {
        wordle?.max_attempts ?? 6
    }
    
    // ✅ FIXED: prefer nested answer only if non-empty, else fall back to top-level answer
    var wordleAnswer: String? {
        let nested = (wordle?.answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !nested.isEmpty { return nested }
        
        let top = (answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return top.isEmpty ? nil : top
    }
    
    var isWordleReady: Bool {
        guard isWordle else { return false }
        let ans = (wordleAnswer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !ans.isEmpty && ans.count == wordleWordLength
    }
}
