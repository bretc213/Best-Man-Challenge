//
//  BracketRound.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/5/26.
//


import Foundation

enum BracketRound: String, Codable, CaseIterable {
    case wildcard, divisional, conference, superBowl
}

struct MatchupTeam: Codable, Hashable {
    let id: String
    let name: String
    let logoAsset: String?
}

struct BracketMatchup: Identifiable, Hashable {
    let id: String
    let round: BracketRound
    let index: Int
    let away: MatchupTeam
    let home: MatchupTeam
    let tv: String?

    let startsAt: Date
    let lockAt: Date
    let revealAt: Date

    let winnerTeamId: String?
    let decidedAt: Date?
}

struct BracketDefinition: Identifiable {
    let id: String
    let title: String
    let sport: String
    let season: Int
    let status: String
    let activeRound: String
    let revealPolicy: String
    let points: BracketPoints
}

struct BracketPoints: Codable {
    let wildcard: Int
    let divisional: Int
    let conference: Int
    let superBowl: Int

    func points(for round: BracketRound) -> Int {
        switch round {
        case .wildcard: return wildcard
        case .divisional: return divisional
        case .conference: return conference
        case .superBowl: return superBowl
        }
    }
}

struct RoundPicksDoc: Identifiable {
    let id: String // linkedPlayerId
    let linkedPlayerId: String
    let displayName: String
    let updatedAt: Date
    let picks: [String: String] // matchupId -> teamId
}


struct BracketScoreRow: Identifiable {
    let id: String
    let linkedPlayerId: String
    let displayName: String
    let points: Int
    let correct: Int
    let breakdown: [String: Int]
}




