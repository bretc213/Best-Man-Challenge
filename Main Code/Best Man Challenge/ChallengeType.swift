//
//  ChallengeType.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 12/25/25.
//

import Foundation

enum ChallengeType: String, Codable, CaseIterable {
    case riddle
    case minesweeper
    case creative
    case quiz
    case image_quiz
    case prop_bets
    case wordle
    case photo_challenge
    case scavenger_hunt
    case connections
    case multi_wordle

    /// Fallback-safe decoding so unknown future types
    /// don’t crash the whole challenge load.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        if let value = ChallengeType(rawValue: rawValue) {
            self = value
        } else {
            print("⚠️ Unknown ChallengeType '\(rawValue)' — defaulting to .riddle")
            self = .riddle
        }
    }
}
