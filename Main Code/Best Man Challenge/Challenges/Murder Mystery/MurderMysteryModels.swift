//
//  MurderMysteryModels.swift
//  Best Man Challenge
//
//  "Dead in the Dust" — data models (admin test feature)
//

import SwiftUI

// MARK: - Answer normalization

/// Normalize an answer for comparison: uppercase, keep letters and numbers only
/// (strips spaces, dashes, punctuation). Applied to BOTH user input and answer keys.
func mmNormalize(_ s: String) -> String {
    s.uppercased().filter { $0.isLetter || $0.isNumber }
}

// MARK: - Enums

enum ChallengeDifficulty: String, Codable {
    case easy, medium, hard

    var label: String { rawValue.capitalized }

    var badgeColor: Color {
        switch self {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }

    var points: Int {
        switch self {
        case .easy:   return 50
        case .medium: return 150
        case .hard:   return 300
        }
    }
}

enum MMChallengeType {
    case multipleChoice([String])
    case textInput(placeholder: String, hint: String)
}

// MARK: - Content models

struct Suspect: Identifiable {
    let id: String
    let name: String
    let role: String
    let bio: String
    let details: [(label: String, value: String)]
    let colorHex: String

    var initials: String {
        name.split(separator: " ").compactMap { $0.first.map(String.init) }.joined()
    }

    var accentColor: Color { Color(mmHex: colorHex) }
}

struct Drop: Identifiable {
    let id: String
    let week: Int
    let isMidweek: Bool
    let title: String
    let body: String
    let clueNote: String?
}

struct Challenge: Identifiable {
    let id: String
    let name: String
    let difficulty: ChallengeDifficulty
    let points: Int
    let description: String
    let type: MMChallengeType
    let answerKey: String   // compared via mmNormalize — never displayed
    let rewardText: String

    func isCorrect(_ input: String) -> Bool {
        mmNormalize(input) == mmNormalize(answerKey)
    }
}

struct InvestigationLocation: Identifiable {
    let id: String
    let name: String
    let description: String
    let unlocksWeek: Int
    let challenges: [Challenge]
}

// MARK: - Accusation

struct AccusationEntry: Codable, Identifiable {
    let id: UUID
    let week: Int
    let killer: String
    let weapon: String
    let location: String
    let pointsAwarded: Int
    let multiplier: Double
    let doubleDownKiller: Bool
    let doubleDownWeapon: Bool
    let doubleDownLocation: Bool
}

// MARK: - Hex color helper

extension Color {
    init(mmHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
