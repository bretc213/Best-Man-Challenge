//
//  WorldCup2026KnockoutModels.swift
//  Best Man Challenge
//
//  Data models for the FIFA 2026 World Cup knockout stage (Phase 2).
//
//  Scoring per correct pick:
//    R32   → 2 pts   (16 matches, 32 pts max)
//    R16   → 4 pts   (8 matches,  32 pts max)
//    QF    → 8 pts   (4 matches,  32 pts max)
//    SF    → 16 pts  (2 matches,  32 pts max)
//    Final → 32 pts  (1 match,    32 pts max)

import Foundation

// MARK: - Knockout Round

enum WCKORound: String, CaseIterable, Identifiable, Hashable {
    case r32    = "r32"
    case r16    = "r16"
    case qf     = "qf"
    case sf     = "sf"
    case final_ = "final"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .r32:    return "Round of 32"
        case .r16:    return "Round of 16"
        case .qf:     return "Quarterfinals"
        case .sf:     return "Semifinals"
        case .final_: return "Final"
        }
    }

    var shortName: String {
        switch self {
        case .r32:    return "R32"
        case .r16:    return "R16"
        case .qf:     return "QF"
        case .sf:     return "SF"
        case .final_: return "Final"
        }
    }

    /// Points awarded for a correct pick in this round.
    var points: Int {
        switch self {
        case .r32:    return 2
        case .r16:    return 4
        case .qf:     return 8
        case .sf:     return 16
        case .final_: return 32
        }
    }

    var matchCount: Int {
        switch self {
        case .r32:    return 16
        case .r16:    return 8
        case .qf:     return 4
        case .sf:     return 2
        case .final_: return 1
        }
    }

    static func from(rawValue: String) -> WCKORound? { WCKORound(rawValue: rawValue) }
}

// MARK: - Knockout Match

/// One match in the knockout bracket. `team1Slot` / `team2Slot` are slot descriptors
/// (e.g. "1A" = Group A winner, "2B" = Group B runner-up, "3rd-ABCDF" = best 3rd from
/// those groups, "W73" = winner of FIFA match 73). The store resolves them to actual
/// team IDs at runtime.
struct WCKOMatch: Identifiable {
    let id: String          // Firestore document ID, e.g. "m73"
    let round: WCKORound
    let fifaMatchNumber: Int
    let sortOrder: Int

    let team1Slot: String   // human-readable slot descriptor
    let team2Slot: String
}

// MARK: - Knockout Status

enum WCKnockoutStatus: String {
    case open       = "open"
    case locked     = "locked"
    case finalized  = "finalized"

    var displayName: String {
        switch self {
        case .open:      return "Open"
        case .locked:    return "Locked"
        case .finalized: return "Finalized"
        }
    }
}

// MARK: - Knockout Results (admin-set)

struct WCKnockoutResults {
    /// matchId → winning team ID
    var matchResults: [String: String] = [:]
    var knockoutStatus: WCKnockoutStatus = .open
    var knockoutIsLocked: Bool = false
    var finalizedAt: Date? = nil
    var finalizedBy: String? = nil

    func winnerId(for matchId: String) -> String? {
        let v = matchResults[matchId]
        return (v?.isEmpty == false) ? v : nil
    }
}

// MARK: - Round Group (used in ForEach to avoid tuple key-path issues)

struct WCKORoundGroup: Identifiable {
    var id: String { round.rawValue }
    let round: WCKORound
    let matches: [WCKOMatch]
}

// MARK: - Knockout Score Row

struct WCKOScoreRow: Identifiable {
    let id: String              // scopedId
    let linkedPlayerId: String
    let displayName: String
    let knockoutTotal: Int
    let byRound: [String: Int]  // WCKORound.rawValue → points
}
