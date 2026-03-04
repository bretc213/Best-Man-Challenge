//
//  VegasOddsModels.swift
//  Best Man Challenge
//
//  Firestore-backed Vegas Odds in-person event framework.
//

import Foundation

// MARK: - Firestore Models

struct VegasOddsEvent: Identifiable, Hashable {
    let id: String              // eventId
    let name: String
    let status: String          // "open" | "locked" | "finalized"
    let betPerPick: Int         // default 100
    let maxPicks: Int           // default 3
    let parlayBonus: Double     // legacy: flat bonus dollars when all 3 hit (kept for backward compat)
    let startsAt: Date?
    let locksAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    var totalWager: Int { betPerPick * maxPicks }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.name = (data["name"] as? String) ?? id
        self.status = (data["status"] as? String) ?? "open"
        self.betPerPick = (data["betPerPick"] as? NSNumber)?.intValue ?? 100
        self.maxPicks = (data["maxPicks"] as? NSNumber)?.intValue ?? 3
        self.parlayBonus = (data["parlayBonus"] as? NSNumber)?.doubleValue ?? 0
        self.startsAt = (data["startsAt"] as? TimestampLike)?.dateValue
        self.locksAt = (data["locksAt"] as? TimestampLike)?.dateValue
        self.createdAt = (data["createdAt"] as? TimestampLike)?.dateValue
        self.updatedAt = (data["updatedAt"] as? TimestampLike)?.dateValue
    }
}

struct VegasOddsLine: Identifiable, Hashable {
    let id: String              // odds doc id (usually playerId)
    let playerId: String

    /// New schema: chances to finish Top-3 (0.0 - 1.0)
    let top3Probability: Double

    /// Legacy schema: directly stored American odds (optional)
    let americanOddsLegacy: Int?

    init(id: String, data: [String: Any]) {
        self.id = id
        self.playerId = (data["playerId"] as? String) ?? id

        // Prefer probability-driven field
        let prob = (data["top3Probability"] as? NSNumber)?.doubleValue
            ?? (data["top3_probability"] as? NSNumber)?.doubleValue
            ?? (data["probability"] as? NSNumber)?.doubleValue

        // Fallback: old american odds field
        let legacyOdds = (data["americanOdds"] as? NSNumber)?.intValue
            ?? (data["american_odds"] as? NSNumber)?.intValue

        if let prob {
            self.top3Probability = OddsMath.clampProbability(prob)
            self.americanOddsLegacy = nil
        } else if let legacyOdds {
            self.americanOddsLegacy = legacyOdds
            self.top3Probability = OddsMath.clampProbability(OddsMath.probability(fromAmerican: legacyOdds))
        } else {
            self.top3Probability = 0.25
            self.americanOddsLegacy = nil
        }
    }

    /// Computed American odds (fair) unless legacy odds exist.
    var americanOdds: Int {
        if let legacy = americanOddsLegacy { return legacy }
        return OddsMath.americanOdds(fromProbability: top3Probability)
    }

    var oddsString: String {
        OddsMath.formatAmerican(americanOdds)
    }

    /// Decimal odds implied by the probability (fair). If legacy odds exist, convert.
    var decimalOdds: Double {
        if let legacy = americanOddsLegacy {
            return OddsMath.decimalOdds(fromAmerican: legacy)
        }
        return OddsMath.decimalOdds(fromProbability: top3Probability)
    }
}

struct VegasOddsBet: Identifiable, Hashable {
    let id: String              // "{eventId}_{bettorId}"
    let eventId: String
    let eventName: String
    let bettorId: String              // auth uid (legacy field)
    let bettorAuthUid: String
    let bettorPlayerId: String
    let bettorDisplayName: String?
    let picks: [String]         // playerIds
    let pickDisplayNames: [String]
    let oddsStrings: [String]
    let betPerPick: Int
    let maxPicks: Int
    let createdAt: Date?

    // settlement
    let isSettled: Bool
    let effectiveTop3: [String]
    let winningPicks: [String]
    let parlayHit: Bool
    let payoutTotal: Double
    let netProfit: Double
    let settledAt: Date?

    init(id: String, data: [String: Any]) {
        self.id = id
        self.eventId = (data["eventId"] as? String) ?? ""
        self.eventName = (data["eventName"] as? String) ?? eventId
        let auth = (data["bettorAuthUid"] as? String) ?? (data["bettorId"] as? String) ?? ""
        let pid = (data["bettorPlayerId"] as? String)
            ?? (data["bettor_player_id"] as? String)
            ?? (data["linked_player_id"] as? String)
            ?? auth
        self.bettorId = auth
        self.bettorAuthUid = auth
        self.bettorPlayerId = pid
        self.bettorDisplayName = data["bettorDisplayName"] as? String
        self.picks = (data["picks"] as? [String]) ?? []
        self.pickDisplayNames = (data["pickDisplayNames"] as? [String]) ?? []
        self.oddsStrings = (data["oddsStrings"] as? [String]) ?? []
        self.betPerPick = (data["betPerPick"] as? NSNumber)?.intValue ?? 100
        self.maxPicks = (data["maxPicks"] as? NSNumber)?.intValue ?? 3
        self.createdAt = (data["createdAt"] as? TimestampLike)?.dateValue

        self.isSettled = (data["isSettled"] as? Bool) ?? false
        self.effectiveTop3 = (data["effectiveTop3"] as? [String]) ?? []
        self.winningPicks = (data["winningPicks"] as? [String]) ?? []
        self.parlayHit = (data["parlayHit"] as? Bool) ?? false
        self.payoutTotal = (data["payoutTotal"] as? NSNumber)?.doubleValue ?? 0
        self.netProfit = (data["netProfit"] as? NSNumber)?.doubleValue ?? 0
        self.settledAt = (data["settledAt"] as? TimestampLike)?.dateValue
    }
}

struct VegasOddsResult: Identifiable, Hashable {
    let id: String              // eventId
    let eventId: String
    let standings: [String]     // ordered playerIds (1st..n)
    let finalizedAt: Date?

    init(id: String, data: [String: Any]) {
        self.id = id
        self.eventId = (data["eventId"] as? String) ?? id
        self.standings = (data["standings"] as? [String]) ?? []
        self.finalizedAt = (data["finalizedAt"] as? TimestampLike)?.dateValue
    }
}

// MARK: - Timestamp bridging (keeps this file FirebaseFirestore-free)

/// Minimal protocol so this file compiles without importing Firebase.
/// Firebase's Timestamp conforms via extension in VegasOddsFirestoreSupport.swift.
protocol TimestampLike {
    var dateValue: Date { get }
}
