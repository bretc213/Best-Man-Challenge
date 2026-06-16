//
//  NFLPickEmModels.swift
//  Best Man Challenge
//
//  Models for the 2026 NFL Season Pick 'Em (Weeks 1–16)
//

import Foundation

// MARK: - Team

struct NFLPickEmTeam: Identifiable, Hashable, Codable {
    let id: String          // e.g. "sea", "ne", "kc"
    let city: String        // e.g. "Seattle"
    let nickname: String    // e.g. "Seahawks"
    let logoAsset: String   // e.g. "nfl_sea"

    var fullName: String { "\(city) \(nickname)" }
    var displayName: String { nickname }
}

// MARK: - Game

struct NFLPickEmGame: Identifiable, Hashable {
    let id: String              // e.g. "2026_w01_g01"
    let week: Int               // 1–16
    let awayTeam: NFLPickEmTeam
    let homeTeam: NFLPickEmTeam
    let kickoffTime: Date

    /// "away_team_id", "home_team_id", or nil if not yet decided
    var winnerId: String?

    var isLocked: Bool {
        Date() >= kickoffTime || winnerId != nil
    }

    var isFinal: Bool {
        winnerId != nil
    }
}

// MARK: - Player Picks

/// One player's complete pick entry across all weeks.
struct NFLPickEmEntry: Identifiable {
    let id: String              // linkedPlayerId
    let linkedPlayerId: String
    let displayName: String
    let updatedAt: Date

    /// gameId → picked teamId
    let picks: [String: String]

    func pick(for gameId: String) -> String? {
        picks[gameId]
    }
}

// MARK: - Scoring

struct NFLPickEmScoreRow: Identifiable {
    let id: String              // linkedPlayerId
    let linkedPlayerId: String
    let displayName: String

    /// Correct picks per week: weekNumber → correct count
    let weeklyCorrect: [Int: Int]

    /// Weeks this player won (or tied for the win)
    let weekWins: [Int]

    var totalCorrect: Int {
        weeklyCorrect.values.reduce(0, +)
    }

    func correctPicks(for week: Int) -> Int {
        weeklyCorrect[week] ?? 0
    }
}

// MARK: - Weekly Leaderboard Row

struct NFLPickEmWeekRow: Identifiable {
    let id: String              // linkedPlayerId
    let linkedPlayerId: String
    let displayName: String
    let correctPicks: Int
    let totalGames: Int
    let isWinner: Bool
}

// MARK: - All Picks Row (for a single game in All Picks view)

struct NFLPickEmGamePicksRow: Identifiable {
    let game: NFLPickEmGame
    /// linkedPlayerId → picked teamId (only players who have picked)
    var picks: [String: String]
    var id: String { game.id }
}

// MARK: - Tabs

enum NFLPickEmTab: String, CaseIterable, Identifiable {
    case myPicks    = "My Picks"
    case allPicks   = "All Picks"
    case leaderboard = "Leaderboard"
    case admin      = "Admin"

    var id: String { rawValue }
}

// MARK: - All 32 NFL Teams

extension NFLPickEmTeam {
    static let allTeams: [NFLPickEmTeam] = [
        // AFC East
        .init(id: "buf", city: "Buffalo",       nickname: "Bills",       logoAsset: "nfl_buf"),
        .init(id: "mia", city: "Miami",         nickname: "Dolphins",    logoAsset: "nfl_mia"),
        .init(id: "ne",  city: "New England",   nickname: "Patriots",    logoAsset: "nfl_ne"),
        .init(id: "nyj", city: "New York",      nickname: "Jets",        logoAsset: "nfl_nyj"),
        // AFC North
        .init(id: "bal", city: "Baltimore",     nickname: "Ravens",      logoAsset: "nfl_bal"),
        .init(id: "cin", city: "Cincinnati",    nickname: "Bengals",     logoAsset: "nfl_cin"),
        .init(id: "cle", city: "Cleveland",     nickname: "Browns",      logoAsset: "nfl_cle"),
        .init(id: "pit", city: "Pittsburgh",    nickname: "Steelers",    logoAsset: "nfl_pit"),
        // AFC South
        .init(id: "hou", city: "Houston",       nickname: "Texans",      logoAsset: "nfl_hou"),
        .init(id: "ind", city: "Indianapolis",  nickname: "Colts",       logoAsset: "nfl_ind"),
        .init(id: "jax", city: "Jacksonville",  nickname: "Jaguars",     logoAsset: "nfl_jax"),
        .init(id: "ten", city: "Tennessee",     nickname: "Titans",      logoAsset: "nfl_ten"),
        // AFC West
        .init(id: "den", city: "Denver",        nickname: "Broncos",     logoAsset: "nfl_den"),
        .init(id: "kc",  city: "Kansas City",   nickname: "Chiefs",      logoAsset: "nfl_kc"),
        .init(id: "lv",  city: "Las Vegas",     nickname: "Raiders",     logoAsset: "nfl_lv"),
        .init(id: "lac", city: "Los Angeles",   nickname: "Chargers",    logoAsset: "nfl_lac"),
        // NFC East
        .init(id: "dal", city: "Dallas",        nickname: "Cowboys",     logoAsset: "nfl_dal"),
        .init(id: "nyg", city: "New York",      nickname: "Giants",      logoAsset: "nfl_nyg"),
        .init(id: "phi", city: "Philadelphia",  nickname: "Eagles",      logoAsset: "nfl_phi"),
        .init(id: "was", city: "Washington",    nickname: "Commanders",  logoAsset: "nfl_was"),
        // NFC North
        .init(id: "chi", city: "Chicago",       nickname: "Bears",       logoAsset: "nfl_chi"),
        .init(id: "det", city: "Detroit",       nickname: "Lions",       logoAsset: "nfl_det"),
        .init(id: "gb",  city: "Green Bay",     nickname: "Packers",     logoAsset: "nfl_gb"),
        .init(id: "min", city: "Minnesota",     nickname: "Vikings",     logoAsset: "nfl_min"),
        // NFC South
        .init(id: "atl", city: "Atlanta",       nickname: "Falcons",     logoAsset: "nfl_atl"),
        .init(id: "car", city: "Carolina",      nickname: "Panthers",    logoAsset: "nfl_car"),
        .init(id: "no",  city: "New Orleans",   nickname: "Saints",      logoAsset: "nfl_no"),
        .init(id: "tb",  city: "Tampa Bay",     nickname: "Buccaneers",  logoAsset: "nfl_tb"),
        // NFC West
        .init(id: "ari", city: "Arizona",       nickname: "Cardinals",   logoAsset: "nfl_ari"),
        .init(id: "lar", city: "Los Angeles",   nickname: "Rams",        logoAsset: "nfl_lar"),
        .init(id: "sf",  city: "San Francisco", nickname: "49ers",       logoAsset: "nfl_sf"),
        .init(id: "sea", city: "Seattle",       nickname: "Seahawks",    logoAsset: "nfl_sea"),
    ]

    static func team(for id: String) -> NFLPickEmTeam? {
        allTeams.first { $0.id == id }
    }
}
