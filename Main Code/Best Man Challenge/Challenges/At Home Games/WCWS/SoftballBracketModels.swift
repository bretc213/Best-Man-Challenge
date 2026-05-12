//
//  SoftballBracketModels.swift
//  Best Man Challenge
//

import Foundation
import FirebaseFirestore

// MARK: - Config

struct SoftballBracketConfig: Codable {
    static let challengeId = "wcws_2026"

    var id: String
    var challengeId: String
    var title: String
    var subtitle: String
    var status: String
    var locksAt: Timestamp?

    var regionalPoints: Int
    var superRegionalPoints: Int
    var finalistPoints: Int
    var championPoints: Int

    var regionals: [SoftballRegional]

    static let superRegionalPairings: [(Int, Int)] = [
        (1, 16),
        (8, 9),
        (5, 12),
        (4, 13),
        (3, 14),
        (6, 11),
        (7, 10),
        (2, 15)
    ]

    var sortedRegionals: [SoftballRegional] {
        regionals.sorted { $0.nationalSeed < $1.nationalSeed }
    }

    func regional(seed: Int) -> SoftballRegional? {
        regionals.first { $0.nationalSeed == seed }
    }

    static let default2026 = SoftballBracketConfig(
        id: challengeId,
        challengeId: challengeId,
        title: "2026 WCWS Bracket",
        subtitle: "NCAA Softball Tournament",
        status: "live",
        locksAt: nil,
        regionalPoints: 2,
        superRegionalPoints: 4,
        finalistPoints: 8,
        championPoints: 16,
        regionals: []
    )

    enum CodingKeys: String, CodingKey {
        case id
        case challengeId
        case title
        case subtitle
        case status
        case locksAt
        case regionalPoints
        case superRegionalPoints
        case finalistPoints
        case championPoints
        case regionals
    }

    init(
        id: String,
        challengeId: String,
        title: String,
        subtitle: String,
        status: String,
        locksAt: Timestamp?,
        regionalPoints: Int,
        superRegionalPoints: Int,
        finalistPoints: Int,
        championPoints: Int,
        regionals: [SoftballRegional]
    ) {
        self.id = id
        self.challengeId = challengeId
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.locksAt = locksAt
        self.regionalPoints = regionalPoints
        self.superRegionalPoints = superRegionalPoints
        self.finalistPoints = finalistPoints
        self.championPoints = championPoints
        self.regionals = regionals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? Self.challengeId
        self.challengeId = try container.decodeIfPresent(String.self, forKey: .challengeId) ?? Self.challengeId
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "2026 WCWS Bracket"
        self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? "NCAA Softball Tournament"
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "live"
        self.locksAt = try container.decodeIfPresent(Timestamp.self, forKey: .locksAt)

        self.regionalPoints = try container.decodeIfPresent(Int.self, forKey: .regionalPoints) ?? 2
        self.superRegionalPoints = try container.decodeIfPresent(Int.self, forKey: .superRegionalPoints) ?? 4
        self.finalistPoints = try container.decodeIfPresent(Int.self, forKey: .finalistPoints) ?? 8
        self.championPoints = try container.decodeIfPresent(Int.self, forKey: .championPoints) ?? 16

        self.regionals = try container.decodeIfPresent([SoftballRegional].self, forKey: .regionals) ?? []
    }
}

// MARK: - Regionals / Teams

struct SoftballRegional: Codable, Identifiable, Hashable {
    let id: String
    let nationalSeed: Int
    let host: String
    let location: String
    let teams: [SoftballTeam]

    var title: String {
        location.isEmpty ? "\(host) Regional" : location
    }

    var sortedTeams: [SoftballTeam] {
        teams.sorted { $0.regionalSeed < $1.regionalSeed }
    }
}

struct SoftballTeam: Codable, Identifiable, Hashable {
    let id: String
    let teamId: String
    let name: String
    let displayName: String
    let seed: Int
    let regionalSeed: Int

    var seedLabel: String? {
        "#\(regionalSeed)"
    }
}

// MARK: - Picks

struct SoftballBracketPicks: Codable, Identifiable, Equatable {
    var id: String { submitterId }

    var submitterId: String
    var displayName: String

    var regionalWinners: [String: String]
    var superRegionalWinners: [String: String]
    var finalists: [String]
    var champion: String?

    var submittedAt: Timestamp?
    var updatedAt: Timestamp?

    static func empty(submitterId: String, displayName: String) -> SoftballBracketPicks {
        SoftballBracketPicks(
            submitterId: submitterId,
            displayName: displayName,
            regionalWinners: [:],
            superRegionalWinners: [:],
            finalists: [],
            champion: nil,
            submittedAt: nil,
            updatedAt: nil
        )
    }

    static func == (lhs: SoftballBracketPicks, rhs: SoftballBracketPicks) -> Bool {
        lhs.submitterId == rhs.submitterId &&
        lhs.displayName == rhs.displayName &&
        lhs.regionalWinners == rhs.regionalWinners &&
        lhs.superRegionalWinners == rhs.superRegionalWinners &&
        lhs.finalists == rhs.finalists &&
        lhs.champion == rhs.champion
    }
}

// MARK: - Results

struct SoftballBracketResults: Codable, Equatable {
    var regionalWinners: [String: String]
    var superRegionalWinners: [String: String]
    var finalists: [String]
    var champion: String?
    var finalizedAt: Timestamp?

    static let empty = SoftballBracketResults(
        regionalWinners: [:],
        superRegionalWinners: [:],
        finalists: [],
        champion: nil,
        finalizedAt: nil
    )

    static func == (lhs: SoftballBracketResults, rhs: SoftballBracketResults) -> Bool {
        lhs.regionalWinners == rhs.regionalWinners &&
        lhs.superRegionalWinners == rhs.superRegionalWinners &&
        lhs.finalists == rhs.finalists &&
        lhs.champion == rhs.champion
    }
}

// MARK: - Leaderboard

struct SoftballLeaderboardRow: Identifiable {
    var id: String { submitterId }

    let submitterId: String
    let displayName: String

    let regionalPoints: Int
    let superRegionalPoints: Int
    let finalistPoints: Int
    let championPoints: Int

    let total: Int
    let maxRemaining: Int
}

// MARK: - Helpers

enum SoftballBracketHelpers {

    static func regionalId(forNationalSeed seed: Int) -> String {
        String(format: "regional_%02d", seed)
    }

    static func superRegionalId(seedA: Int, seedB: Int) -> String {
        String(format: "super_%02d_%02d", seedA, seedB)
    }

    static func team(_ teamId: String?, config: SoftballBracketConfig) -> SoftballTeam? {
        guard let teamId else { return nil }

        for regional in config.regionals {
            if let found = regional.teams.first(where: { $0.id == teamId || $0.teamId == teamId }) {
                return found
            }
        }

        return nil
    }

    static func teamName(_ teamId: String, config: SoftballBracketConfig) -> String {
        team(teamId, config: config)?.name ?? teamId
    }

    static func teamName(teamId: String, config: SoftballBracketConfig) -> String {
        team(teamId, config: config)?.name ?? teamId
    }
}
