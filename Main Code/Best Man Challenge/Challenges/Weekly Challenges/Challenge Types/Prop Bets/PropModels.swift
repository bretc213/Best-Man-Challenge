//
//  PropOption.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 2/3/26.
//


import Foundation
import FirebaseFirestore

// MARK: - Models (no FirebaseFirestoreSwift needed)

struct PropOption: Identifiable, Hashable {
    let id: String
    let position: Int
    let label: String
    let oddsAmerican: Int?

    static func fromDict(_ dict: [String: Any]) -> PropOption? {
        guard let id = dict["id"] as? String else { return nil }
        let position = dict["position"] as? Int ?? 0
        let label = dict["label"] as? String ?? ""
        let odds = dict["odds_american"] as? Int
        return PropOption(id: id, position: position, label: label, oddsAmerican: odds)
    }
}

enum PropKind: String {
    case overUnder = "over_under"
    case multipleChoice = "multiple_choice"
}

struct PropBet: Identifiable, Hashable {
    let id: String
    let position: Int
    let kind: PropKind
    let prompt: String
    let market: String?
    let line: Double?
    let options: [PropOption]
    let isActive: Bool

    static func fromDoc(id: String, data: [String: Any]) -> PropBet? {
        // Required-ish fields with safe defaults
        let position = data["position"] as? Int ?? 0
        let kindRaw = data["kind"] as? String ?? "multiple_choice"
        let kind = PropKind(rawValue: kindRaw) ?? .multipleChoice
        let prompt = data["prompt"] as? String ?? ""
        let market = data["market"] as? String
        let isActive = data["is_active"] as? Bool ?? true

        // line can be stored as Int or Double
        var line: Double? = nil
        if let d = data["line"] as? Double { line = d }
        else if let i = data["line"] as? Int { line = Double(i) }

        let rawOptions = data["options"] as? [[String: Any]] ?? []
        let options = rawOptions.compactMap { PropOption.fromDict($0) }
            .sorted { $0.position < $1.position }

        // Must have an id + prompt at minimum
        guard !id.isEmpty, !prompt.isEmpty else { return nil }

        return PropBet(
            id: id,
            position: position,
            kind: kind,
            prompt: prompt,
            market: market,
            line: line,
            options: options,
            isActive: isActive
        )
    }
}

struct PropBetsChallenge: Identifiable {
    let id: String
    let week: Int
    let type: String
    let title: String
    let description: String
    let isActive: Bool
    let locksAt: Timestamp?

    var isLocked: Bool {
        guard let locksAt else { return false }
        return Date() >= locksAt.dateValue()
    }

    static func fromDoc(id: String, data: [String: Any]) -> PropBetsChallenge? {
        // SAFE defaults (this is what fixes “missing” decode crashes)
        let week = data["week"] as? Int ?? 0
        let type = data["type"] as? String ?? "prop_bets"
        let title = data["title"] as? String ?? "Prop Bets"
        let description = data["description"] as? String ?? ""
        let isActive = data["is_active"] as? Bool ?? false
        let locksAt = data["locksAt"] as? Timestamp

        // Must at least have an id
        guard !id.isEmpty else { return nil }

        return PropBetsChallenge(
            id: id,
            week: week,
            type: type,
            title: title,
            description: description,
            isActive: isActive,
            locksAt: locksAt
        )
    }
}
