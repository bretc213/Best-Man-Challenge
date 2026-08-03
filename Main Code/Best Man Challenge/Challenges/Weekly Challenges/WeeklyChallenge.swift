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

struct WeeklyImageQuizQuestion: Codable, Identifiable {
    let id: String
    let prompt: String
    let image_name: String
    let answer: String?
    let acceptable_answers: [String]?
    let allow_fuzzy_match: Bool?
    let fuzzy_distance: Int?
}

struct WeeklyChallengeQuiz: Codable {
    let points_per_correct: Int?
    let questions: [WeeklyQuizQuestion]?
    let image_questions: [WeeklyImageQuizQuestion]?
}

// MARK: - Multi-Wordle models

struct MultiWordleWord: Identifiable, Codable {
    let id: String
    let answer: String
    let word_length: Int
    let max_attempts: Int
    let label: String?
}

struct WeeklyChallengeMultiWordle: Codable {
    let words: [MultiWordleWord]
}

// MARK: - Photo Challenge models

struct PhotoChallengePrompt: Identifiable, Codable {
    let id: String
    let label: String
    let emoji: String
    let description: String
}

struct WeeklyChallengePhotoConfig: Codable {
    let prompts: [PhotoChallengePrompt]
    let points_per_submission: Int
    let bonus_points_per_winner: Int
    let judge_name: String?
}

// MARK: - Scavenger Hunt models

struct ScavengerHuntItem: Identifiable, Codable {
    let id: String
    let clue: String
    let emoji: String
    let point_value: Int
    let position: Int?
    let bonus_eligible: Bool?
    let bonus_clue: String?
}

struct WeeklyChallengeScavengerHuntConfig: Codable {
    let items: [ScavengerHuntItem]
    let points_per_item: Int
    let bonus_item_id: String?
    let authenticity_note: String?
}

// MARK: - Connections models

enum ConnectionsColor: String, Codable, CaseIterable {
    case yellow, green, blue, purple

    /// Visual difficulty order (0 = easiest/yellow, 3 = hardest/purple)
    var order: Int {
        switch self {
        case .yellow: return 0
        case .green:  return 1
        case .blue:   return 2
        case .purple: return 3
        }
    }
}

struct ConnectionsCategory: Identifiable, Codable {
    let id: String
    let name: String
    let color: ConnectionsColor
    let words: [String]
    let point_value: Int

    var allWords: [String] { words }
}

struct WeeklyChallengeConnectionsConfig: Codable {
    let categories: [ConnectionsCategory]
    let max_mistakes: Int

    var allWords: [String] { categories.flatMap { $0.words } }
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
    /// Additional accepted answers (case/punctuation-insensitive) beyond `answer`.
    let accepted_answers: [String]?
    let rules: [String]?

    let puzzle: WeeklyChallengePuzzle?
    let cipher: WeeklyChallengeCipher?
    let quiz: WeeklyChallengeQuiz?

    // Wordle extras (optional)
    let wordle: WeeklyChallengeWordle?
    let game_format: String?

    // New challenge type configs
    let multi_wordle: WeeklyChallengeMultiWordle?
    let photo_challenge: WeeklyChallengePhotoConfig?
    let scavenger_hunt: WeeklyChallengeScavengerHuntConfig?
    let connections_config: WeeklyChallengeConnectionsConfig?

    // Optional Firestore flags
    let is_active: Bool?
    /// When true, explicitly includes this challenge in the Past Weeks list.
    /// When false, explicitly hides it. When nil, visibility falls back to date logic.
    let is_finalized: Bool?

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
        accepted_answers: [String]? = nil,
        rules: [String]? = nil,
        puzzle: WeeklyChallengePuzzle? = nil,
        cipher: WeeklyChallengeCipher? = nil,
        quiz: WeeklyChallengeQuiz? = nil,
        wordle: WeeklyChallengeWordle? = nil,
        game_format: String? = nil,
        is_active: Bool? = nil,
        is_finalized: Bool? = nil,
        multi_wordle: WeeklyChallengeMultiWordle? = nil,
        photo_challenge: WeeklyChallengePhotoConfig? = nil,
        scavenger_hunt: WeeklyChallengeScavengerHuntConfig? = nil,
        connections_config: WeeklyChallengeConnectionsConfig? = nil
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
        self.accepted_answers = accepted_answers
        self.rules = rules
        self.puzzle = puzzle
        self.cipher = cipher
        self.quiz = quiz
        self.wordle = wordle
        self.game_format = game_format
        self.is_active = is_active
        self.is_finalized = is_finalized
        self.multi_wordle = multi_wordle
        self.photo_challenge = photo_challenge
        self.scavenger_hunt = scavenger_hunt
        self.connections_config = connections_config
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

    var isImageQuiz: Bool {
        type == .image_quiz
    }

    var imageQuizQuestions: [WeeklyImageQuizQuestion] {
        quiz?.image_questions ?? []
    }

    var imageQuizPointsPerCorrect: Int {
        quiz?.points_per_correct ?? 1
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
