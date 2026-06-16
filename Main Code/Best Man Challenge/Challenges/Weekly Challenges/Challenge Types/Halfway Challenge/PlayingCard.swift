//
//  PlayingCard.swift
//  Best Man Challenge
//
//  Shared card model used by Ride the Bus (Round 1) and Blackjack (Round 3).
//  Serialized as a short code string for Firestore persistence: e.g. "S14" = Ace of Spades.
//

import SwiftUI

// MARK: - Suit

enum CardSuit: String, CaseIterable, Codable {
    case spades   = "S"
    case hearts   = "H"
    case diamonds = "D"
    case clubs    = "C"

    var symbol: String {
        switch self {
        case .spades:   return "♠"
        case .hearts:   return "♥"
        case .diamonds: return "♦"
        case .clubs:    return "♣"
        }
    }

    var isRed: Bool { self == .hearts || self == .diamonds }
    var color: Color { isRed ? .red : .white }
}

// MARK: - Card

struct PlayingCard: Equatable, Codable {
    let suit: CardSuit
    let value: Int   // 2–14 (Ace = 14, King = 13, Queen = 12, Jack = 11)

    // MARK: Display

    var displayValue: String {
        switch value {
        case 14: return "A"
        case 13: return "K"
        case 12: return "Q"
        case 11: return "J"
        default: return "\(value)"
        }
    }

    var displayFull: String { "\(displayValue)\(suit.symbol)" }

    // MARK: Serialization

    /// Short code for Firestore: "S14", "H7", "D11" etc.
    var code: String { "\(suit.rawValue)\(value)" }

    static func from(code: String) -> PlayingCard? {
        guard code.count >= 2 else { return nil }
        let suitRaw = String(code.prefix(1))
        guard let suit = CardSuit(rawValue: suitRaw),
              let value = Int(code.dropFirst()),
              (2...14).contains(value) else { return nil }
        return PlayingCard(suit: suit, value: value)
    }
}

// MARK: - Deck

struct CardDeck {
    var cards: [PlayingCard]

    static func fresh() -> CardDeck {
        let cards = CardSuit.allCases.flatMap { suit in
            (2...14).map { PlayingCard(suit: suit, value: $0) }
        }.shuffled()
        return CardDeck(cards: cards)
    }

    var isEmpty: Bool { cards.isEmpty }
    var count: Int { cards.count }

    /// Draw the top card. Returns nil if empty (caller should reshuffle).
    mutating func draw() -> PlayingCard? {
        guard !cards.isEmpty else { return nil }
        return cards.removeFirst()
    }

    // MARK: Firestore serialization

    var codes: [String] { cards.map(\.code) }

    static func from(codes: [String]) -> CardDeck {
        CardDeck(cards: codes.compactMap { PlayingCard.from(code: $0) })
    }
}
