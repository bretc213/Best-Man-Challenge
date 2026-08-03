//
//  CFBConfChampsModels.swift
//  Best Man Challenge
//
//  Models + 2026 conference/team data for the CFB Conference Championships game.
//
//  TWO PHASES:
//   • Phase 1 (Preseason): for each conference, pick the 2 title-game finalists
//     and designate 1 as champion. Locks at the first Power-4 game. Worth MORE.
//   • Phase 2 (Champ Week): once the admin posts the real matchup, pick the
//     winner of each conference title game. Locks at each game's kickoff. Worth LESS.
//
//  Scoring is raw (0…82). The admin "Finalize & Award" converts raw scores to
//  BMC points via ChallengePointsFinalizer (golf-payout tie logic + owner +3),
//  exactly like the CFB Playoffs pool.
//

import Foundation

// MARK: - Tier + Scoring

enum CFBTier: String, Codable {
    case power       // SEC, Big Ten, ACC, Big 12  — worth more
    case nonPower    // AAC, MWC, Sun Belt, MAC, C-USA, Pac-12 — worth less

    /// Phase 1: points per correctly-predicted finalist team (max 2 per conf).
    var finalistPoints: Double { self == .power ? 3 : 1 }
    /// Phase 1: bonus for correctly predicting the champion.
    var championBonus: Double { self == .power ? 5 : 2 }
    /// Phase 2: points for correctly picking the title-game winner.
    var phase2Points: Double { self == .power ? 2 : 1 }

    var label: String { self == .power ? "Power 4" : "Group of 5" }
}

// MARK: - Team

struct CFBTeam: Identifiable, Hashable, Codable {
    let id: String          // e.g. "ohio_state"
    let name: String        // e.g. "Ohio State"
    let logoAsset: String   // e.g. "OhioStateLogo"

    var displayName: String { name }
}

// MARK: - Conference

/// Static definition + admin-driven live state merged by the store.
struct CFBConference: Identifiable, Hashable {
    let id: String              // e.g. "sec"
    let name: String            // e.g. "SEC"
    let tier: CFBTier
    let sortOrder: Int
    let teamIds: [String]       // roster (2026)

    // Live state (from Firestore, admin-entered)
    var finalistIds: [String]   // the 2 teams that reached the title game (0 or 2)
    var championId: String?     // the winner (set after the game)
    var phase1LockAt: Date?     // shared: first Power-4 game
    var phase2LockAt: Date?     // this conf's title-game kickoff

    var teams: [CFBTeam] { teamIds.compactMap { CFBData.team(for: $0) } }
    var finalists: [CFBTeam] { finalistIds.compactMap { CFBData.team(for: $0) } }
    var champion: CFBTeam? { championId.flatMap { CFBData.team(for: $0) } }

    /// Matchup is set (admin posted 2 finalists) → Phase 2 is open.
    var matchupSet: Bool { finalistIds.count == 2 }

    /// Max points a player can earn from this conference across both phases.
    var maxPoints: Double {
        (tier.finalistPoints * 2) + tier.championBonus + tier.phase2Points
    }

    var isPhase1Locked: Bool {
        guard let lock = phase1LockAt else { return false }
        return Date() >= lock
    }

    var isPhase2Locked: Bool {
        guard let lock = phase2LockAt else { return false }
        return Date() >= lock
    }
}

// MARK: - Player Picks

/// One conference's Phase 1 prediction.
struct CFBPhase1Pick: Hashable, Codable {
    var finalistIds: [String]   // up to 2
    var championId: String?     // must be one of finalistIds

    var isComplete: Bool { finalistIds.count == 2 && championId != nil }
}

/// One player's full entry.
struct CFBConfChampsEntry: Identifiable {
    let id: String              // linkedPlayerId
    let linkedPlayerId: String
    let displayName: String
    let updatedAt: Date

    /// confId → Phase 1 prediction
    var phase1: [String: CFBPhase1Pick]
    /// confId → picked winner teamId (Phase 2)
    var phase2: [String: String]

    func phase1Pick(for confId: String) -> CFBPhase1Pick? { phase1[confId] }
    func phase2Pick(for confId: String) -> String? { phase2[confId] }
}

// MARK: - Scoring

struct CFBScoreRow: Identifiable {
    let id: String              // linkedPlayerId
    let linkedPlayerId: String
    let displayName: String
    let phase1Points: Double
    let phase2Points: Double

    var total: Double { phase1Points + phase2Points }
}

// MARK: - Tabs

enum CFBConfChampsTab: String, CaseIterable, Identifiable {
    case preseason   = "Preseason"
    case champWeek   = "Champ Week"
    case leaderboard = "Leaderboard"
    case allPicks    = "All Picks"
    case admin       = "Admin"

    var id: String { rawValue }
}

// MARK: - 2026 Conference Data

enum CFBData {

    static let challengeId = "cfb_conf_champs_2026"

    /// All 10 FBS conferences that hold a 2026 title game, Power-4 first.
    static let conferences: [CFBConferenceDef] = [
        // ───────── Power 4 ─────────
        .init(id: "sec", name: "SEC", tier: .power, sortOrder: 1, teams: [
            .t("alabama", "Alabama"), .t("arkansas", "Arkansas"), .t("auburn", "Auburn"),
            .t("florida", "Florida"), .t("georgia", "Georgia"), .t("kentucky", "Kentucky"),
            .t("lsu", "LSU"), .t("mississippi_state", "Mississippi State"),
            .t("missouri", "Missouri"), .t("oklahoma", "Oklahoma"), .t("ole_miss", "Ole Miss"),
            .t("south_carolina", "South Carolina"), .t("tennessee", "Tennessee"),
            .t("texas", "Texas"), .t("texas_am", "Texas A&M"), .t("vanderbilt", "Vanderbilt"),
        ]),
        .init(id: "big_ten", name: "Big Ten", tier: .power, sortOrder: 2, teams: [
            .t("illinois", "Illinois"), .t("indiana", "Indiana"), .t("iowa", "Iowa"),
            .t("maryland", "Maryland"), .t("michigan", "Michigan"),
            .t("michigan_state", "Michigan State"), .t("minnesota", "Minnesota"),
            .t("nebraska", "Nebraska"), .t("northwestern", "Northwestern"),
            .t("ohio_state", "Ohio State"), .t("oregon", "Oregon"),
            .t("penn_state", "Penn State"), .t("purdue", "Purdue"), .t("rutgers", "Rutgers"),
            .t("ucla", "UCLA"), .t("usc", "USC"), .t("washington", "Washington"),
            .t("wisconsin", "Wisconsin"),
        ]),
        .init(id: "acc", name: "ACC", tier: .power, sortOrder: 3, teams: [
            .t("boston_college", "Boston College"), .t("california", "California"),
            .t("clemson", "Clemson"), .t("duke", "Duke"), .t("florida_state", "Florida State"),
            .t("georgia_tech", "Georgia Tech"), .t("louisville", "Louisville"),
            .t("miami", "Miami"), .t("nc_state", "NC State"),
            .t("north_carolina", "North Carolina"), .t("pittsburgh", "Pittsburgh"),
            .t("smu", "SMU"), .t("stanford", "Stanford"), .t("syracuse", "Syracuse"),
            .t("virginia", "Virginia"), .t("virginia_tech", "Virginia Tech"),
            .t("wake_forest", "Wake Forest"),
        ]),
        .init(id: "big_12", name: "Big 12", tier: .power, sortOrder: 4, teams: [
            .t("arizona", "Arizona"), .t("arizona_state", "Arizona State"),
            .t("baylor", "Baylor"), .t("byu", "BYU"), .t("cincinnati", "Cincinnati"),
            .t("colorado", "Colorado"), .t("houston", "Houston"), .t("iowa_state", "Iowa State"),
            .t("kansas", "Kansas"), .t("kansas_state", "Kansas State"),
            .t("oklahoma_state", "Oklahoma State"), .t("tcu", "TCU"),
            .t("texas_tech", "Texas Tech"), .t("ucf", "UCF"), .t("utah", "Utah"),
            .t("west_virginia", "West Virginia"),
        ]),
        // ───────── Group of 5 (incl. relaunched Pac-12) ─────────
        .init(id: "american", name: "American", tier: .nonPower, sortOrder: 5, teams: [
            .t("army", "Army"), .t("charlotte", "Charlotte"),
            .t("east_carolina", "East Carolina"), .t("florida_atlantic", "Florida Atlantic"),
            .t("memphis", "Memphis"), .t("navy", "Navy"), .t("north_texas", "North Texas"),
            .t("rice", "Rice"), .t("south_florida", "South Florida"), .t("temple", "Temple"),
            .t("tulane", "Tulane"), .t("tulsa", "Tulsa"), .t("uab", "UAB"), .t("utsa", "UTSA"),
        ]),
        .init(id: "mountain_west", name: "Mountain West", tier: .nonPower, sortOrder: 6, teams: [
            .t("air_force", "Air Force"), .t("hawaii", "Hawai'i"), .t("nevada", "Nevada"),
            .t("new_mexico", "New Mexico"), .t("north_dakota_state", "North Dakota State"),
            .t("northern_illinois", "Northern Illinois"), .t("san_jose_state", "San José State"),
            .t("unlv", "UNLV"), .t("utep", "UTEP"), .t("wyoming", "Wyoming"),
        ]),
        .init(id: "sun_belt", name: "Sun Belt", tier: .nonPower, sortOrder: 7, teams: [
            .t("appalachian_state", "Appalachian State"), .t("arkansas_state", "Arkansas State"),
            .t("coastal_carolina", "Coastal Carolina"), .t("georgia_southern", "Georgia Southern"),
            .t("georgia_state", "Georgia State"), .t("james_madison", "James Madison"),
            .t("louisiana", "Louisiana"), .t("louisiana_tech", "Louisiana Tech"),
            .t("marshall", "Marshall"), .t("old_dominion", "Old Dominion"),
            .t("south_alabama", "South Alabama"), .t("southern_miss", "Southern Miss"),
            .t("troy", "Troy"), .t("ul_monroe", "UL Monroe"),
        ]),
        .init(id: "mac", name: "MAC", tier: .nonPower, sortOrder: 8, teams: [
            .t("akron", "Akron"), .t("ball_state", "Ball State"),
            .t("bowling_green", "Bowling Green"), .t("buffalo", "Buffalo"),
            .t("central_michigan", "Central Michigan"), .t("eastern_michigan", "Eastern Michigan"),
            .t("kent_state", "Kent State"), .t("miami_oh", "Miami (OH)"), .t("ohio", "Ohio"),
            .t("sacramento_state", "Sacramento State"), .t("toledo", "Toledo"),
            .t("umass", "UMass"), .t("western_michigan", "Western Michigan"),
        ]),
        .init(id: "conference_usa", name: "Conference USA", tier: .nonPower, sortOrder: 9, teams: [
            .t("delaware", "Delaware"), .t("fiu", "FIU"),
            .t("jacksonville_state", "Jacksonville State"), .t("kennesaw_state", "Kennesaw State"),
            .t("liberty", "Liberty"), .t("middle_tennessee", "Middle Tennessee"),
            .t("missouri_state", "Missouri State"), .t("new_mexico_state", "New Mexico State"),
            .t("sam_houston", "Sam Houston"), .t("western_kentucky", "Western Kentucky"),
        ]),
        .init(id: "pac_12", name: "Pac-12", tier: .nonPower, sortOrder: 10, teams: [
            .t("boise_state", "Boise State"), .t("colorado_state", "Colorado State"),
            .t("fresno_state", "Fresno State"), .t("oregon_state", "Oregon State"),
            .t("san_diego_state", "San Diego State"), .t("texas_state", "Texas State"),
            .t("utah_state", "Utah State"), .t("washington_state", "Washington State"),
        ]),
    ]

    /// Flat lookup of every team across all conferences.
    static let allTeams: [CFBTeam] = conferences.flatMap { $0.teams }

    private static let teamIndex: [String: CFBTeam] =
        Dictionary(uniqueKeysWithValues: allTeams.map { ($0.id, $0) })

    static func team(for id: String) -> CFBTeam? { teamIndex[id] }

    static func conferenceDef(for id: String) -> CFBConferenceDef? {
        conferences.first { $0.id == id }
    }
}

/// Static (code-defined) conference blueprint used by the seeder + as a fallback.
struct CFBConferenceDef: Identifiable {
    let id: String
    let name: String
    let tier: CFBTier
    let sortOrder: Int
    let teams: [CFBTeam]

    var teamIds: [String] { teams.map { $0.id } }
}

// MARK: - Convenience team builder (asset = PascalCase(name) + "Logo")

extension CFBTeam {
    /// `.t("ohio_state", "Ohio State")` → logoAsset "OhioStateLogo"
    static func t(_ id: String, _ name: String) -> CFBTeam {
        CFBTeam(id: id, name: name, logoAsset: CFBTeam.logoAsset(for: name))
    }

    /// Deterministic asset name: strip non-alphanumerics, PascalCase, append "Logo".
    /// "Miami (OH)" → "MiamiOHLogo", "Texas A&M" → "TexasAMLogo", "Hawai'i" → "HawaiiLogo".
    static func logoAsset(for name: String) -> String {
        let cleaned = name
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US"))
            .replacingOccurrences(of: "&", with: " ")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")
        let parts = cleaned
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let pascal = parts.map { part -> String in
            // Keep all-caps tokens as-is (LSU, BYU, TCU, UCLA, USC, UAB, UTSA, FIU, OH…)
            if part == part.uppercased() { return part }
            return part.prefix(1).uppercased() + part.dropFirst()
        }.joined()
        return pascal + "Logo"
    }
}
