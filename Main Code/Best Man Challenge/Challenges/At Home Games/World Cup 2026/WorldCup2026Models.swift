//
//  WorldCup2026Models.swift
//  Best Man Challenge
//
//  Models for the 2026 FIFA World Cup group-stage pick challenge.
//

import Foundation

// MARK: - Groups & Slots

/// FIFA 2026 has 12 groups (A–L).
enum WCGroup: String, CaseIterable, Identifiable, Comparable {
    case A, B, C, D, E, F, G, H, I, J, K, L
    var id: String { rawValue }

    static func < (lhs: WCGroup, rhs: WCGroup) -> Bool {
        let all = WCGroup.allCases
        return (all.firstIndex(of: lhs) ?? 0) < (all.firstIndex(of: rhs) ?? 0)
    }
}

/// The 4 finishing positions within a group.
enum WCGroupSlot: String, CaseIterable, Identifiable {
    case first  = "1st"
    case second = "2nd"
    case third  = "3rd"
    case fourth = "4th"

    var id: String { rawValue }

    var rank: Int {
        switch self {
        case .first:  return 1
        case .second: return 2
        case .third:  return 3
        case .fourth: return 4
        }
    }

    static func from(rank: Int) -> WCGroupSlot? {
        allCases.first { $0.rank == rank }
    }
}

// MARK: - Tournament Status

enum WCTournamentStatus: String {
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

// MARK: - Team

struct WCTeam: Identifiable, Hashable {
    let id: String          // e.g., "USA"
    let name: String        // e.g., "United States"
    let abbr: String        // e.g., "USA"
    let group: WCGroup
    let flag: String?       // emoji flag
    let sortOrder: Int
}

// MARK: - Picks

/// A single player's full entry.
struct WCEntry: Identifiable {
    let id: String                  // linkedPlayerId
    let linkedPlayerId: String
    let displayName: String
    let updatedAt: Date

    /// groupPicks["A"]["1st"] = teamId
    let groupPicks: [String: [String: String]]

    /// knockoutPicks (Phase 2 – reserved)
    let knockoutPicks: [String: String]

    func pick(group: WCGroup, slot: WCGroupSlot) -> String? {
        groupPicks[group.rawValue]?[slot.rawValue]
    }

    /// Returns the predicted rank (1-4) for a given teamId within a group, nil if not picked.
    func predictedRank(teamId: String, group: WCGroup) -> Int? {
        let picks = groupPicks[group.rawValue] ?? [:]
        for slot in WCGroupSlot.allCases {
            if picks[slot.rawValue] == teamId { return slot.rank }
        }
        return nil
    }
}

// MARK: - Results

struct WCGroupResult {
    /// actualFinish["1st"] = teamId, etc.
    var actualFinish: [String: String] = [:]

    func teamId(forSlot slot: WCGroupSlot) -> String? {
        let v = actualFinish[slot.rawValue]
        return (v?.isEmpty == false) ? v : nil
    }

    func actualRank(teamId: String) -> Int? {
        for slot in WCGroupSlot.allCases {
            if actualFinish[slot.rawValue] == teamId { return slot.rank }
        }
        return nil
    }
}

struct WCResults {
    /// groupResults["A"] = WCGroupResult
    var groupResults: [String: WCGroupResult] = [:]
    var status: WCTournamentStatus = .open
    var isFinalized: Bool = false
    var finalizedAt: Date? = nil
    var finalizedBy: String? = nil

    func result(for group: WCGroup) -> WCGroupResult {
        groupResults[group.rawValue] ?? WCGroupResult()
    }

    /// Teams that advanced (1st and 2nd from each group).
    var groupAdvancers: [String: [WCGroup: String]] {
        var out: [String: [WCGroup: String]] = [:]
        for g in WCGroup.allCases {
            let r = result(for: g)
            if let t1 = r.teamId(forSlot: .first)  { out["1st", default: [:]][g] = t1 }
            if let t2 = r.teamId(forSlot: .second) { out["2nd", default: [:]][g] = t2 }
        }
        return out
    }
}

// MARK: - Scoring

struct WCGroupScore: Identifiable {
    let group: WCGroup
    var id: String { group.rawValue }
    let points: Int
    /// teamId -> points for that team's slot
    let perTeam: [String: Int]
}

struct WCScoreRow: Identifiable {
    let id: String          // scopedId ("admin:<id>" for admins lane)
    let linkedPlayerId: String
    let displayName: String
    let groupTotal: Int
    let byGroup: [String: Int]      // group rawValue -> points
    let knockoutTotal: Int
    let byRound: [String: Int]      // WCKORound.rawValue -> points

    /// Combined Phase 1 + Phase 2 score
    var total: Int { groupTotal + knockoutTotal }

    static func positionPoints(predictedRank: Int, actualRank: Int) -> Int {
        let diff = abs(predictedRank - actualRank)
        switch diff {
        case 0:  return  2
        case 1:  return  1
        case 2:  return  0
        default: return -1
        }
    }
}

// MARK: - Tabs

enum WCTab: String, CaseIterable, Identifiable {
    case groupPicks  = "Group Picks"
    case knockout    = "Knockout"
    case leaderboard = "Leaderboard"
    case allPicks    = "All Picks"
    case admin       = "Admin"
    var id: String { rawValue }
}
