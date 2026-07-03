//
//  GolfEventModels.swift
//  Best Man Challenge
//

import Foundation

// MARK: - Scoring constants

enum GolfScoring {
    static let bretPlayerId = "bretc"

    /// In-game sim points by rank index (0 = 1st place). Base × 3.
    static let simInGamePoints: [Double] = [45, 36, 30, 24, 21, 18, 15, 12, 9, 6, 3, 0]

    /// Scramble in-game points per partner by team rank index (0 = 1st place).
    static let scramblePointsPerPlayer: [Double] = [27, 18, 13, 9, 5, 1]

    /// BMC points for non-Bret players by rank index among the 11 (0 = 1st). Base × 3.
    static let bmcPoints: [Double] = [45, 36, 30, 24, 21, 18, 15, 12, 9, 6, 3]

    /// Shared points for tied positions: average the point values across all tied slots.
    static func sharedPoints(rankIndices: [Int], scale: [Double]) -> Double {
        let valid = rankIndices.filter { $0 < scale.count }
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0.0) { $0 + scale[$1] } / Double(valid.count)
    }
}

// MARK: - Data models

struct GolfSimEntry: Identifiable {
    var id: String { playerId }
    var playerId: String
    var displayName: String
    var score: Int?          // net vs par (nil = not entered)
    var rankIndex: Int?      // 0-based; nil until scores saved
    var inGamePoints: Double // 0 until ranked
    var isBret: Bool { playerId == GolfScoring.bretPlayerId }
}

struct GolfTeamAssignment: Identifiable, Codable {
    var id: String           // "t1"…"t6"
    var playerAId: String
    var playerBId: String
    var playerAName: String
    var playerBName: String
}

struct GolfTeamResult: Identifiable {
    var id: String { assignment.id }
    var assignment: GolfTeamAssignment
    var scrambleScore: Int?  // net vs par
    var rankIndex: Int?      // 0-based team rank
    var pointsPerPlayer: Double
}

struct GolfOverallEntry: Identifiable {
    var id: String { playerId }
    var playerId: String
    var displayName: String
    var simPoints: Double
    var scramblePoints: Double
    var totalPoints: Double
    var overallRankIndex: Int?   // rank among all 12
    var bmcRankIndex: Int?       // rank among 11 non-Bret players
    var bmcBase: Double
    var bretBonus: Double         // +3 if finished above Bret, else 0
    var totalBMC: Double { bmcBase + bretBonus }
    var isBret: Bool { playerId == GolfScoring.bretPlayerId }
}

// MARK: - Firestore document state

struct GolfEventState {
    var simScores: [String: Int]              // playerId → net score
    var teams: [GolfTeamAssignment]
    var teamsGenerated: Bool
    var scrambleScores: [String: Int]         // teamId → net score
    var isFinalized: Bool

    static let empty = GolfEventState(
        simScores: [:],
        teams: [],
        teamsGenerated: false,
        scrambleScores: [:],
        isFinalized: false
    )

    init(from data: [String: Any]) {
        simScores = (data["sim_scores"] as? [String: Int]) ?? [:]
        teamsGenerated = (data["teams_generated"] as? Bool) ?? false
        isFinalized = (data["is_finalized"] as? Bool) ?? false

        let rawTeams = data["teams"] as? [[String: Any]] ?? []
        teams = rawTeams.compactMap { d -> GolfTeamAssignment? in
            guard let id = d["team_id"] as? String,
                  let pA = d["player_a"] as? String,
                  let pB = d["player_b"] as? String else { return nil }
            return GolfTeamAssignment(
                id: id,
                playerAId: pA,
                playerBId: pB,
                playerAName: d["player_a_name"] as? String ?? pA,
                playerBName: d["player_b_name"] as? String ?? pB
            )
        }

        scrambleScores = (data["scramble_scores"] as? [String: Int]) ?? [:]
    }

    init(simScores: [String: Int], teams: [GolfTeamAssignment], teamsGenerated: Bool,
         scrambleScores: [String: Int], isFinalized: Bool) {
        self.simScores = simScores
        self.teams = teams
        self.teamsGenerated = teamsGenerated
        self.scrambleScores = scrambleScores
        self.isFinalized = isFinalized
    }
}
