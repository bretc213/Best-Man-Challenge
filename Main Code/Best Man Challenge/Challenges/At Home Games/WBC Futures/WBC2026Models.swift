//
//  WBC2026Models.swift
//  Best Man Challenge
//
//  Lightweight models for WBC 2026 bracket challenge.
//

import Foundation

enum WBCPool: String, CaseIterable, Identifiable {
    case A, B, C, D
    var id: String { rawValue }
}

/// Tabs/rounds for the all-up-front bracket UI.
enum WBCStage: String, CaseIterable, Identifiable {
    case pool = "Pool Play"
    case quarters = "Quarterfinals"
    case semis = "Semifinals"
    case championship = "Championship"
    case leaderboard = "Standings"
    case admin = "Admin"

    var id: String { rawValue }
}

struct WBCTeam: Identifiable, Hashable {
    let id: String          // e.g., "USA"
    let name: String        // e.g., "United States"
    let abbr: String        // e.g., "USA"
    let pool: WBCPool

    // Leave placeholders so you can add later.
    let logoAsset: String?          // e.g. "teams/usa.png" (app asset name)
    let logoStoragePath: String?    // e.g. "logos/wbc_2026/USA.png" (Firebase Storage path)
    let logoUrl: String?            // cached https URL if you ever want it
}

/// Stored per-player document (players lane or admins lane).
struct WBCEntry: Identifiable {
    let id: String                 // linkedPlayerId (players lane) or uid (admins lane)
    let linkedPlayerId: String
    let displayName: String
    let updatedAt: Date

    // Pool picks: A/B/C/D -> winner/runnerUp
    let poolPicks: [String: [String: String]]

    // Bracket picks
    let qfPicks: [String: String] // qf1..qf4 -> teamId
    let sfPicks: [String: String] // sf1..sf2 -> teamId
    let champPick: String?        // teamId
}

struct WBCResults {
    var poolResults: [String: [String: String]] = [:]  // A/B/C/D -> seed1/seed2
    var finalFour: [String] = []
    var finalTwo: [String] = []
    var champion: String? = nil
}

struct WBCMatchup: Identifiable {
    let id: String        // qf1, sf1, final
    let left: String?     // teamId
    let right: String?    // teamId
}
