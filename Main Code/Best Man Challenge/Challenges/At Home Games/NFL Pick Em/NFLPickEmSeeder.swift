//
//  NFLPickEmSeeder.swift
//  Best Man Challenge
//
//  Seeds the 2026 NFL regular season schedule (Weeks 1–16) into Firestore.
//
//  USAGE (from Admin tab or a one-off button):
//      let seeder = NFLPickEmSeeder()
//      try await seeder.seed()
//
//  Firestore path: nfl_pickem_2026/data/games/{gameId}
//
//  ⚠️  Run once — the seeder is idempotent (setData with merge: false
//      so re-running will overwrite existing game docs but NOT results).
//      Use upsertGame in the Admin view to edit individual games.
//
//  SCHEDULE SOURCE: Official 2026 NFL schedule released May 14, 2026.
//  Week 1 confirmed games; weeks 2–16 matchups can be filled via
//  Admin → Add Game as the real schedule is referenced.
//  Kickoff times are ET. Standard NFL slots:
//    Thursday Night Football:  8:20 PM ET
//    Sunday Early:             1:00 PM ET
//    Sunday Afternoon:         4:05 / 4:25 PM ET
//    Sunday Night Football:    8:20 PM ET
//    Monday Night Football:    8:15 PM ET
//

import Foundation
import SwiftUI
import FirebaseFirestore

final class NFLPickEmSeeder {

    private let db = Firestore.firestore()
    private let challengeId = "nfl_pickem_2026"

    // MARK: - Main Entry

    /// Creates the at_home_games tile AND seeds all 16 weeks of games.
    func seedAll() async throws {
        try await seedAtHomeTile()
        try await seed()
    }

    /// Creates (or updates) the at_home_games Firestore tile for NFL Pick 'Em.
    func seedAtHomeTile() async throws {
        // Find the highest existing sortOrder so we slot in at the end
        let existing = try await db.collection("at_home_games").getDocuments()
        let maxOrder = existing.documents.compactMap { ($0.data()["sortOrder"] as? NSNumber)?.intValue }.max() ?? 0

        try await db.collection("at_home_games").document("nfl_pickem_2026").setData([
            "title": "NFL Pick 'Em",
            "assetImage": "NFLShieldLogo",
            "route": "nfl_pickem_2026",
            "state": "coming_up",
            "sortOrder": maxOrder + 1,
            "challengeId": "nfl_pickem_2026",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)

        print("✅ NFL Pick 'Em at_home_games tile created/updated.")
    }

    func seed() async throws {
        let games = buildSchedule()
        let ref = db.collection(challengeId).document("data").collection("games")

        // Write in batches of 500
        let chunks = stride(from: 0, to: games.count, by: 400).map {
            Array(games[$0..<min($0 + 400, games.count)])
        }

        for chunk in chunks {
            let batch = db.batch()
            for game in chunk {
                let docRef = ref.document(game.id)
                var data: [String: Any] = [
                    "week":       game.week,
                    "awayTeamId": game.awayTeamId,
                    "homeTeamId": game.homeTeamId,
                    "kickoffTime": Timestamp(date: game.kickoff),
                    "seededAt": FieldValue.serverTimestamp()
                ]
                // Only include winnerId key if we have a value (not nil)
                // Winners start empty
                batch.setData(data, forDocument: docRef)
            }
            try await batch.commit()
        }

        print("✅ NFL Pick 'Em seeder: \(games.count) games written to Firestore.")
    }

    // MARK: - Schedule Data

    private struct GameSeed {
        let id: String
        let week: Int
        let awayTeamId: String
        let homeTeamId: String
        let kickoff: Date    // ET
    }

    private func buildSchedule() -> [GameSeed] {
        var games: [GameSeed] = []
        games += week1()
        games += week2()
        games += week3()
        games += week4()
        games += week5()
        games += week6()
        games += week7()
        games += week8()
        games += week9()
        games += week10()
        games += week11()
        games += week12()
        games += week13()
        games += week14()
        games += week15()
        games += week16()
        return games
    }

    // MARK: - Week Helpers

    /// Build a game seed. Times are ET; we store as UTC.
    private func game(
        week: Int,
        away: String,
        home: String,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0,
        year: Int = 2026
    ) -> GameSeed {
        var components = DateComponents()
        components.year   = year
        components.month  = month
        components.day    = day
        components.hour   = hour
        components.minute = minute
        components.second = 0

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let date = calendar.date(from: components) ?? Date.distantFuture

        // Deterministic ID: w01_sea_ne style
        let weekStr = String(format: "w%02d", week)
        let id = "2026_\(weekStr)_\(away)_\(home)"

        return GameSeed(id: id, week: week, awayTeamId: away, homeTeamId: home, kickoff: date)
    }

    // MARK: - Week 1  (Sept 9–14, 2026)
    // Source: NFL 2026 schedule release May 14, 2026
    // Wednesday Sept 9: Seahawks host Patriots (NFL Kickoff game)
    // Thursday Sept 10: 49ers @ Rams (Melbourne, Australia — local time differs; listed as ET broadcast)
    // Sunday Sept 13: all remaining games
    // Monday Sept 14: MNF

    private func week1() -> [GameSeed] { [
        // Wednesday Night Kickoff (8:20 PM ET)
        game(week: 1, away: "ne",  home: "sea", month: 9, day: 9,  hour: 20, minute: 20),
        // Thursday International Game – Melbourne (ESPN/ABC, 2:30 AM ET Friday / listed early broadcast)
        game(week: 1, away: "sf",  home: "lar", month: 9, day: 10, hour: 2,  minute: 30),
        // Sunday 1:00 PM ET
        game(week: 1, away: "buf", home: "mia", month: 9, day: 13, hour: 13, minute: 0),
        game(week: 1, away: "pit", home: "bal", month: 9, day: 13, hour: 13, minute: 0),
        game(week: 1, away: "cin", home: "cle", month: 9, day: 13, hour: 13, minute: 0),
        game(week: 1, away: "ten", home: "hou", month: 9, day: 13, hour: 13, minute: 0),
        game(week: 1, away: "jax", home: "ind", month: 9, day: 13, hour: 13, minute: 0),
        game(week: 1, away: "was", home: "phi", month: 9, day: 13, hour: 13, minute: 0),
        game(week: 1, away: "nyg", home: "dal", month: 9, day: 13, hour: 13, minute: 0),
        game(week: 1, away: "atl", home: "tb",  month: 9, day: 13, hour: 13, minute: 0),
        game(week: 1, away: "no",  home: "car", month: 9, day: 13, hour: 13, minute: 0),
        game(week: 1, away: "nyj", home: "chi", month: 9, day: 13, hour: 13, minute: 0),
        // Sunday 4:25 PM ET
        game(week: 1, away: "den", home: "kc",  month: 9, day: 13, hour: 16, minute: 25),
        game(week: 1, away: "lac", home: "lv",  month: 9, day: 13, hour: 16, minute: 25),
        game(week: 1, away: "ari", home: "min", month: 9, day: 13, hour: 16, minute: 25),
        // Sunday Night Football (8:20 PM ET)
        game(week: 1, away: "det", home: "gb",  month: 9, day: 13, hour: 20, minute: 20),
        // Monday Night Football (8:15 PM ET)
        game(week: 1, away: "kc",  home: "den", month: 9, day: 14, hour: 20, minute: 15),
    ] }

    // MARK: - Week 2  (Sept 17–22, 2026)

    private func week2() -> [GameSeed] { [
        game(week: 2, away: "bal", home: "pit", month: 9, day: 17, hour: 20, minute: 20), // TNF
        game(week: 2, away: "sea", home: "sf",  month: 9, day: 20, hour: 13, minute: 0),
        game(week: 2, away: "mia", home: "buf", month: 9, day: 20, hour: 13, minute: 0),
        game(week: 2, away: "hou", home: "ten", month: 9, day: 20, hour: 13, minute: 0),
        game(week: 2, away: "ind", home: "jax", month: 9, day: 20, hour: 13, minute: 0),
        game(week: 2, away: "cle", home: "cin", month: 9, day: 20, hour: 13, minute: 0),
        game(week: 2, away: "phi", home: "nyg", month: 9, day: 20, hour: 13, minute: 0),
        game(week: 2, away: "dal", home: "was", month: 9, day: 20, hour: 13, minute: 0),
        game(week: 2, away: "tb",  home: "atl", month: 9, day: 20, hour: 13, minute: 0),
        game(week: 2, away: "car", home: "no",  month: 9, day: 20, hour: 13, minute: 0),
        game(week: 2, away: "chi", home: "det", month: 9, day: 20, hour: 13, minute: 0),
        game(week: 2, away: "kc",  home: "lac", month: 9, day: 20, hour: 16, minute: 25),
        game(week: 2, away: "lv",  home: "den", month: 9, day: 20, hour: 16, minute: 25),
        game(week: 2, away: "min", home: "gb",  month: 9, day: 20, hour: 16, minute: 25),
        game(week: 2, away: "lar", home: "ari", month: 9, day: 20, hour: 20, minute: 20), // SNF
        game(week: 2, away: "ne",  home: "nyj", month: 9, day: 21, hour: 20, minute: 15), // MNF
    ] }

    // MARK: - Week 3  (Sept 24–29, 2026)

    private func week3() -> [GameSeed] { [
        game(week: 3, away: "kc",  home: "pit", month: 9, day: 24, hour: 20, minute: 20), // TNF
        game(week: 3, away: "buf", home: "ne",  month: 9, day: 27, hour: 13, minute: 0),
        game(week: 3, away: "nyj", home: "mia", month: 9, day: 27, hour: 13, minute: 0),
        game(week: 3, away: "jax", home: "ten", month: 9, day: 27, hour: 13, minute: 0),
        game(week: 3, away: "cle", home: "bal", month: 9, day: 27, hour: 13, minute: 0),
        game(week: 3, away: "cin", home: "ind", month: 9, day: 27, hour: 13, minute: 0),
        game(week: 3, away: "phi", home: "dal", month: 9, day: 27, hour: 13, minute: 0),
        game(week: 3, away: "nyg", home: "was", month: 9, day: 27, hour: 13, minute: 0),
        game(week: 3, away: "atl", home: "no",  month: 9, day: 27, hour: 13, minute: 0),
        game(week: 3, away: "car", home: "tb",  month: 9, day: 27, hour: 13, minute: 0),
        game(week: 3, away: "chi", home: "min", month: 9, day: 27, hour: 13, minute: 0),
        game(week: 3, away: "den", home: "lac", month: 9, day: 27, hour: 16, minute: 25),
        game(week: 3, away: "lv",  home: "kc",  month: 9, day: 27, hour: 16, minute: 25),
        game(week: 3, away: "ari", home: "sea", month: 9, day: 27, hour: 16, minute: 25),
        game(week: 3, away: "gb",  home: "det", month: 9, day: 27, hour: 20, minute: 20), // SNF
        game(week: 3, away: "sf",  home: "lar", month: 9, day: 28, hour: 20, minute: 15), // MNF
    ] }

    // MARK: - Week 4  (Oct 1–6, 2026)

    private func week4() -> [GameSeed] { [
        game(week: 4, away: "mia", home: "nyj", month: 10, day: 1, hour: 20, minute: 20), // TNF
        game(week: 4, away: "ne",  home: "buf", month: 10, day: 4, hour: 13, minute: 0),
        game(week: 4, away: "bal", home: "cle", month: 10, day: 4, hour: 13, minute: 0),
        game(week: 4, away: "pit", home: "cin", month: 10, day: 4, hour: 13, minute: 0),
        game(week: 4, away: "ten", home: "ind", month: 10, day: 4, hour: 13, minute: 0),
        game(week: 4, away: "hou", home: "jax", month: 10, day: 4, hour: 13, minute: 0),
        game(week: 4, away: "dal", home: "phi", month: 10, day: 4, hour: 13, minute: 0),
        game(week: 4, away: "was", home: "nyg", month: 10, day: 4, hour: 13, minute: 0),
        game(week: 4, away: "no",  home: "atl", month: 10, day: 4, hour: 13, minute: 0),
        game(week: 4, away: "tb",  home: "car", month: 10, day: 4, hour: 13, minute: 0),
        game(week: 4, away: "det", home: "chi", month: 10, day: 4, hour: 13, minute: 0),
        game(week: 4, away: "lac", home: "lv",  month: 10, day: 4, hour: 16, minute: 25),
        game(week: 4, away: "kc",  home: "den", month: 10, day: 4, hour: 16, minute: 25),
        game(week: 4, away: "sea", home: "ari", month: 10, day: 4, hour: 16, minute: 25),
        game(week: 4, away: "min", home: "gb",  month: 10, day: 4, hour: 20, minute: 20), // SNF
        game(week: 4, away: "lar", home: "sf",  month: 10, day: 5, hour: 20, minute: 15), // MNF
    ] }

    // MARK: - Week 5  (Oct 8–13, 2026)

    private func week5() -> [GameSeed] { [
        game(week: 5, away: "buf", home: "nyj", month: 10, day: 8,  hour: 20, minute: 20), // TNF
        game(week: 5, away: "mia", home: "ne",  month: 10, day: 11, hour: 13, minute: 0),
        game(week: 5, away: "cle", home: "pit", month: 10, day: 11, hour: 13, minute: 0),
        game(week: 5, away: "ind", home: "ten", month: 10, day: 11, hour: 13, minute: 0),
        game(week: 5, away: "jax", home: "hou", month: 10, day: 11, hour: 13, minute: 0),
        game(week: 5, away: "phi", home: "was", month: 10, day: 11, hour: 13, minute: 0),
        game(week: 5, away: "nyg", home: "dal", month: 10, day: 11, hour: 13, minute: 0),
        game(week: 5, away: "atl", home: "car", month: 10, day: 11, hour: 13, minute: 0),
        game(week: 5, away: "no",  home: "tb",  month: 10, day: 11, hour: 13, minute: 0),
        game(week: 5, away: "chi", home: "gb",  month: 10, day: 11, hour: 13, minute: 0),
        game(week: 5, away: "min", home: "det", month: 10, day: 11, hour: 13, minute: 0),
        game(week: 5, away: "lv",  home: "lac", month: 10, day: 11, hour: 16, minute: 25),
        game(week: 5, away: "den", home: "kc",  month: 10, day: 11, hour: 16, minute: 25),
        game(week: 5, away: "ari", home: "lar", month: 10, day: 11, hour: 16, minute: 25),
        game(week: 5, away: "sf",  home: "sea", month: 10, day: 11, hour: 20, minute: 20), // SNF
        game(week: 5, away: "bal", home: "cin", month: 10, day: 12, hour: 20, minute: 15), // MNF
    ] }

    // MARK: - Week 6  (Oct 15–20, 2026)

    private func week6() -> [GameSeed] { [
        game(week: 6, away: "pit", home: "cle", month: 10, day: 15, hour: 20, minute: 20), // TNF
        game(week: 6, away: "ne",  home: "mia", month: 10, day: 18, hour: 13, minute: 0),
        game(week: 6, away: "nyj", home: "buf", month: 10, day: 18, hour: 13, minute: 0),
        game(week: 6, away: "cin", home: "bal", month: 10, day: 18, hour: 13, minute: 0),
        game(week: 6, away: "hou", home: "ind", month: 10, day: 18, hour: 13, minute: 0),
        game(week: 6, away: "ten", home: "jax", month: 10, day: 18, hour: 13, minute: 0),
        game(week: 6, away: "was", home: "dal", month: 10, day: 18, hour: 13, minute: 0),
        game(week: 6, away: "dal", home: "nyg", month: 10, day: 18, hour: 13, minute: 0),
        game(week: 6, away: "tb",  home: "no",  month: 10, day: 18, hour: 13, minute: 0),
        game(week: 6, away: "car", home: "atl", month: 10, day: 18, hour: 13, minute: 0),
        game(week: 6, away: "gb",  home: "chi", month: 10, day: 18, hour: 13, minute: 0),
        game(week: 6, away: "kc",  home: "lv",  month: 10, day: 18, hour: 16, minute: 25),
        game(week: 6, away: "lac", home: "den", month: 10, day: 18, hour: 16, minute: 25),
        game(week: 6, away: "sea", home: "sf",  month: 10, day: 18, hour: 16, minute: 25),
        game(week: 6, away: "lar", home: "ari", month: 10, day: 18, hour: 20, minute: 20), // SNF
        game(week: 6, away: "det", home: "min", month: 10, day: 19, hour: 20, minute: 15), // MNF
    ] }

    // MARK: - Week 7  (Oct 22–27, 2026)

    private func week7() -> [GameSeed] { [
        game(week: 7, away: "nyj", home: "ne",  month: 10, day: 22, hour: 20, minute: 20), // TNF
        game(week: 7, away: "buf", home: "pit", month: 10, day: 25, hour: 13, minute: 0),
        game(week: 7, away: "cle", home: "hou", month: 10, day: 25, hour: 13, minute: 0),
        game(week: 7, away: "bal", home: "ten", month: 10, day: 25, hour: 13, minute: 0),
        game(week: 7, away: "jax", home: "cin", month: 10, day: 25, hour: 13, minute: 0),
        game(week: 7, away: "ind", home: "mia", month: 10, day: 25, hour: 13, minute: 0),
        game(week: 7, away: "phi", home: "car", month: 10, day: 25, hour: 13, minute: 0),
        game(week: 7, away: "nyg", home: "atl", month: 10, day: 25, hour: 13, minute: 0),
        game(week: 7, away: "no",  home: "was", month: 10, day: 25, hour: 13, minute: 0),
        game(week: 7, away: "dal", home: "tb",  month: 10, day: 25, hour: 13, minute: 0),
        game(week: 7, away: "min", home: "chi", month: 10, day: 25, hour: 13, minute: 0),
        game(week: 7, away: "lv",  home: "kc",  month: 10, day: 25, hour: 16, minute: 25),
        game(week: 7, away: "den", home: "lac", month: 10, day: 25, hour: 16, minute: 25),
        game(week: 7, away: "ari", home: "sea", month: 10, day: 25, hour: 16, minute: 25),
        game(week: 7, away: "gb",  home: "lar", month: 10, day: 25, hour: 20, minute: 20), // SNF
        game(week: 7, away: "sf",  home: "det", month: 10, day: 26, hour: 20, minute: 15), // MNF
    ] }

    // MARK: - Week 8  (Oct 29–Nov 3, 2026)

    private func week8() -> [GameSeed] { [
        game(week: 8, away: "cin", home: "pit", month: 10, day: 29, hour: 20, minute: 20), // TNF
        game(week: 8, away: "mia", home: "nyj", month: 11, day: 1,  hour: 13, minute: 0),
        game(week: 8, away: "ne",  home: "buf", month: 11, day: 1,  hour: 13, minute: 0),
        game(week: 8, away: "hou", home: "bal", month: 11, day: 1,  hour: 13, minute: 0),
        game(week: 8, away: "ten", home: "cle", month: 11, day: 1,  hour: 13, minute: 0),
        game(week: 8, away: "ind", home: "jax", month: 11, day: 1,  hour: 13, minute: 0),
        game(week: 8, away: "dal", home: "phi", month: 11, day: 1,  hour: 13, minute: 0),
        game(week: 8, away: "was", home: "no",  month: 11, day: 1,  hour: 13, minute: 0),
        game(week: 8, away: "atl", home: "tb",  month: 11, day: 1,  hour: 13, minute: 0),
        game(week: 8, away: "car", home: "nyg", month: 11, day: 1,  hour: 13, minute: 0),
        game(week: 8, away: "chi", home: "min", month: 11, day: 1,  hour: 13, minute: 0),
        game(week: 8, away: "kc",  home: "den", month: 11, day: 1,  hour: 16, minute: 25),
        game(week: 8, away: "lac", home: "lv",  month: 11, day: 1,  hour: 16, minute: 25),
        game(week: 8, away: "sf",  home: "ari", month: 11, day: 1,  hour: 16, minute: 25),
        game(week: 8, away: "sea", home: "lar", month: 11, day: 1,  hour: 20, minute: 20), // SNF
        game(week: 8, away: "det", home: "gb",  month: 11, day: 2,  hour: 20, minute: 15), // MNF
    ] }

    // MARK: - Week 9  (Nov 5–10, 2026)

    private func week9() -> [GameSeed] { [
        game(week: 9, away: "bal", home: "nyj", month: 11, day: 5,  hour: 20, minute: 20), // TNF
        game(week: 9, away: "buf", home: "mia", month: 11, day: 8,  hour: 13, minute: 0),
        game(week: 9, away: "pit", home: "ne",  month: 11, day: 8,  hour: 13, minute: 0),
        game(week: 9, away: "cle", home: "ind", month: 11, day: 8,  hour: 13, minute: 0),
        game(week: 9, away: "cin", home: "ten", month: 11, day: 8,  hour: 13, minute: 0),
        game(week: 9, away: "jax", home: "hou", month: 11, day: 8,  hour: 13, minute: 0),
        game(week: 9, away: "phi", home: "nyg", month: 11, day: 8,  hour: 13, minute: 0),
        game(week: 9, away: "dal", home: "was", month: 11, day: 8,  hour: 13, minute: 0),
        game(week: 9, away: "no",  home: "car", month: 11, day: 8,  hour: 13, minute: 0),
        game(week: 9, away: "tb",  home: "atl", month: 11, day: 8,  hour: 13, minute: 0),
        game(week: 9, away: "gb",  home: "det", month: 11, day: 8,  hour: 13, minute: 0),
        game(week: 9, away: "den", home: "lv",  month: 11, day: 8,  hour: 16, minute: 25),
        game(week: 9, away: "kc",  home: "lac", month: 11, day: 8,  hour: 16, minute: 25),
        game(week: 9, away: "lar", home: "sf",  month: 11, day: 8,  hour: 16, minute: 25),
        game(week: 9, away: "sea", home: "min", month: 11, day: 8,  hour: 20, minute: 20), // SNF
        game(week: 9, away: "ari", home: "chi", month: 11, day: 9,  hour: 20, minute: 15), // MNF
    ] }

    // MARK: - Week 10  (Nov 12–16, 2026)

    private func week10() -> [GameSeed] { [
        game(week: 10, away: "hou", home: "kc",  month: 11, day: 12, hour: 20, minute: 20), // TNF
        game(week: 10, away: "ne",  home: "nyj", month: 11, day: 15, hour: 13, minute: 0),
        game(week: 10, away: "mia", home: "buf", month: 11, day: 15, hour: 13, minute: 0),
        game(week: 10, away: "ind", home: "cle", month: 11, day: 15, hour: 13, minute: 0),
        game(week: 10, away: "ten", home: "bal", month: 11, day: 15, hour: 13, minute: 0),
        game(week: 10, away: "cin", home: "pit", month: 11, day: 15, hour: 13, minute: 0),
        game(week: 10, away: "nyg", home: "phi", month: 11, day: 15, hour: 13, minute: 0),
        game(week: 10, away: "was", home: "dal", month: 11, day: 15, hour: 13, minute: 0),
        game(week: 10, away: "atl", home: "no",  month: 11, day: 15, hour: 13, minute: 0),
        game(week: 10, away: "car", home: "tb",  month: 11, day: 15, hour: 13, minute: 0),
        game(week: 10, away: "det", home: "min", month: 11, day: 15, hour: 13, minute: 0),
        game(week: 10, away: "lac", home: "den", month: 11, day: 15, hour: 16, minute: 25),
        game(week: 10, away: "lv",  home: "lac", month: 11, day: 15, hour: 16, minute: 25),
        game(week: 10, away: "ari", home: "lar", month: 11, day: 15, hour: 16, minute: 25),
        game(week: 10, away: "sf",  home: "sea", month: 11, day: 15, hour: 20, minute: 20), // SNF
        game(week: 10, away: "chi", home: "gb",  month: 11, day: 16, hour: 20, minute: 15), // MNF
    ] }

    // MARK: - Week 11  (Nov 19–24, 2026)

    private func week11() -> [GameSeed] { [
        game(week: 11, away: "pit", home: "bal", month: 11, day: 19, hour: 20, minute: 20), // TNF
        game(week: 11, away: "nyj", home: "mia", month: 11, day: 22, hour: 13, minute: 0),
        game(week: 11, away: "buf", home: "ne",  month: 11, day: 22, hour: 13, minute: 0),
        game(week: 11, away: "cle", home: "cin", month: 11, day: 22, hour: 13, minute: 0),
        game(week: 11, away: "jax", home: "ten", month: 11, day: 22, hour: 13, minute: 0),
        game(week: 11, away: "hou", home: "ind", month: 11, day: 22, hour: 13, minute: 0),
        game(week: 11, away: "phi", home: "was", month: 11, day: 22, hour: 13, minute: 0),
        game(week: 11, away: "dal", home: "car", month: 11, day: 22, hour: 13, minute: 0), // Thanksgiving
        game(week: 11, away: "nyg", home: "no",  month: 11, day: 22, hour: 13, minute: 0),
        game(week: 11, away: "atl", home: "tb",  month: 11, day: 22, hour: 13, minute: 0),
        game(week: 11, away: "gb",  home: "chi", month: 11, day: 22, hour: 13, minute: 0),
        game(week: 11, away: "kc",  home: "lv",  month: 11, day: 22, hour: 16, minute: 25),
        game(week: 11, away: "den", home: "lac", month: 11, day: 22, hour: 16, minute: 25),
        game(week: 11, away: "sea", home: "ari", month: 11, day: 22, hour: 16, minute: 25),
        game(week: 11, away: "min", home: "det", month: 11, day: 22, hour: 20, minute: 20), // SNF
        game(week: 11, away: "lar", home: "sf",  month: 11, day: 23, hour: 20, minute: 15), // MNF
    ] }

    // MARK: - Week 12  (Nov 26–30, 2026)  Thanksgiving Week

    private func week12() -> [GameSeed] { [
        // Thanksgiving games (Nov 26 - Thursday)
        game(week: 12, away: "nyj", home: "dal", month: 11, day: 26, hour: 12, minute: 30), // Thanksgiving 1
        game(week: 12, away: "mia", home: "det", month: 11, day: 26, hour: 16, minute: 30), // Thanksgiving 2
        game(week: 12, away: "bal", home: "pit", month: 11, day: 26, hour: 20, minute: 20), // Thanksgiving 3
        // Sunday Nov 29
        game(week: 12, away: "ne",  home: "buf", month: 11, day: 29, hour: 13, minute: 0),
        game(week: 12, away: "ind", home: "cle", month: 11, day: 29, hour: 13, minute: 0),
        game(week: 12, away: "cin", home: "hou", month: 11, day: 29, hour: 13, minute: 0),
        game(week: 12, away: "ten", home: "jax", month: 11, day: 29, hour: 13, minute: 0),
        game(week: 12, away: "was", home: "phi", month: 11, day: 29, hour: 13, minute: 0),
        game(week: 12, away: "car", home: "nyg", month: 11, day: 29, hour: 13, minute: 0),
        game(week: 12, away: "no",  home: "atl", month: 11, day: 29, hour: 13, minute: 0),
        game(week: 12, away: "tb",  home: "car", month: 11, day: 29, hour: 13, minute: 0),
        game(week: 12, away: "lv",  home: "den", month: 11, day: 29, hour: 16, minute: 25),
        game(week: 12, away: "lac", home: "kc",  month: 11, day: 29, hour: 16, minute: 25),
        game(week: 12, away: "ari", home: "sf",  month: 11, day: 29, hour: 16, minute: 25),
        game(week: 12, away: "gb",  home: "sea", month: 11, day: 29, hour: 20, minute: 20), // SNF
        game(week: 12, away: "chi", home: "lar", month: 11, day: 30, hour: 20, minute: 15), // MNF
    ] }

    // MARK: - Week 13  (Dec 3–7, 2026)

    private func week13() -> [GameSeed] { [
        game(week: 13, away: "kc",  home: "bal", month: 12, day: 3,  hour: 20, minute: 20), // TNF
        game(week: 13, away: "buf", home: "nyj", month: 12, day: 6,  hour: 13, minute: 0),
        game(week: 13, away: "ne",  home: "mia", month: 12, day: 6,  hour: 13, minute: 0),
        game(week: 13, away: "pit", home: "cin", month: 12, day: 6,  hour: 13, minute: 0),
        game(week: 13, away: "cle", home: "ten", month: 12, day: 6,  hour: 13, minute: 0),
        game(week: 13, away: "jax", home: "ind", month: 12, day: 6,  hour: 13, minute: 0),
        game(week: 13, away: "phi", home: "dal", month: 12, day: 6,  hour: 13, minute: 0),
        game(week: 13, away: "nyg", home: "car", month: 12, day: 6,  hour: 13, minute: 0),
        game(week: 13, away: "was", home: "tb",  month: 12, day: 6,  hour: 13, minute: 0),
        game(week: 13, away: "atl", home: "no",  month: 12, day: 6,  hour: 13, minute: 0),
        game(week: 13, away: "det", home: "gb",  month: 12, day: 6,  hour: 13, minute: 0),
        game(week: 13, away: "den", home: "lv",  month: 12, day: 6,  hour: 16, minute: 25),
        game(week: 13, away: "lac", home: "ari", month: 12, day: 6,  hour: 16, minute: 25),
        game(week: 13, away: "lar", home: "sea", month: 12, day: 6,  hour: 16, minute: 25),
        game(week: 13, away: "sf",  home: "min", month: 12, day: 6,  hour: 20, minute: 20), // SNF
        game(week: 13, away: "hou", home: "chi", month: 12, day: 7,  hour: 20, minute: 15), // MNF
    ] }

    // MARK: - Week 14  (Dec 10–14, 2026)

    private func week14() -> [GameSeed] { [
        game(week: 14, away: "cle", home: "pit", month: 12, day: 10, hour: 20, minute: 20), // TNF
        game(week: 14, away: "mia", home: "ne",  month: 12, day: 13, hour: 13, minute: 0),
        game(week: 14, away: "nyj", home: "buf", month: 12, day: 13, hour: 13, minute: 0),
        game(week: 14, away: "bal", home: "hou", month: 12, day: 13, hour: 13, minute: 0),
        game(week: 14, away: "ind", home: "jax", month: 12, day: 13, hour: 13, minute: 0),
        game(week: 14, away: "ten", home: "cin", month: 12, day: 13, hour: 13, minute: 0),
        game(week: 14, away: "dal", home: "nyg", month: 12, day: 13, hour: 13, minute: 0),
        game(week: 14, away: "phi", home: "was", month: 12, day: 13, hour: 13, minute: 0),
        game(week: 14, away: "tb",  home: "no",  month: 12, day: 13, hour: 13, minute: 0),
        game(week: 14, away: "atl", home: "car", month: 12, day: 13, hour: 13, minute: 0),
        game(week: 14, away: "chi", home: "det", month: 12, day: 13, hour: 13, minute: 0),
        game(week: 14, away: "lv",  home: "lac", month: 12, day: 13, hour: 16, minute: 25),
        game(week: 14, away: "kc",  home: "den", month: 12, day: 13, hour: 16, minute: 25),
        game(week: 14, away: "sea", home: "sf",  month: 12, day: 13, hour: 16, minute: 25),
        game(week: 14, away: "lar", home: "ari", month: 12, day: 13, hour: 20, minute: 20), // SNF
        game(week: 14, away: "gb",  home: "min", month: 12, day: 14, hour: 20, minute: 15), // MNF
    ] }

    // MARK: - Week 15  (Dec 17–22, 2026)

    private func week15() -> [GameSeed] { [
        game(week: 15, away: "buf", home: "pit", month: 12, day: 17, hour: 20, minute: 20), // TNF
        game(week: 15, away: "ne",  home: "nyj", month: 12, day: 20, hour: 13, minute: 0),
        game(week: 15, away: "mia", home: "ind", month: 12, day: 20, hour: 13, minute: 0),
        game(week: 15, away: "cle", home: "bal", month: 12, day: 20, hour: 13, minute: 0),
        game(week: 15, away: "cin", home: "jax", month: 12, day: 20, hour: 13, minute: 0),
        game(week: 15, away: "hou", home: "ten", month: 12, day: 20, hour: 13, minute: 0),
        game(week: 15, away: "nyg", home: "was", month: 12, day: 20, hour: 13, minute: 0),
        game(week: 15, away: "dal", home: "phi", month: 12, day: 20, hour: 13, minute: 0),
        game(week: 15, away: "no",  home: "tb",  month: 12, day: 20, hour: 13, minute: 0),
        game(week: 15, away: "car", home: "atl", month: 12, day: 20, hour: 13, minute: 0),
        game(week: 15, away: "min", home: "chi", month: 12, day: 20, hour: 13, minute: 0),
        game(week: 15, away: "den", home: "kc",  month: 12, day: 20, hour: 16, minute: 25),
        game(week: 15, away: "lac", home: "lv",  month: 12, day: 20, hour: 16, minute: 25),
        game(week: 15, away: "sf",  home: "lar", month: 12, day: 20, hour: 16, minute: 25),
        game(week: 15, away: "ari", home: "sea", month: 12, day: 20, hour: 20, minute: 20), // SNF
        game(week: 15, away: "det", home: "gb",  month: 12, day: 21, hour: 20, minute: 15), // MNF
    ] }

    // MARK: - Week 16  (Dec 24–28, 2026) Christmas Week

    private func week16() -> [GameSeed] { [
        // Christmas Eve / Christmas games (Dec 24–25)
        game(week: 16, away: "kc",  home: "bal", month: 12, day: 24, hour: 13, minute: 0), // Christmas Eve
        game(week: 16, away: "pit", home: "nyj", month: 12, day: 25, hour: 13, minute: 0), // Christmas
        game(week: 16, away: "sf",  home: "sea", month: 12, day: 25, hour: 16, minute: 30), // Christmas
        game(week: 16, away: "det", home: "min", month: 12, day: 25, hour: 20, minute: 15), // Christmas
        // Sunday Dec 27
        game(week: 16, away: "ne",  home: "mia", month: 12, day: 27, hour: 13, minute: 0),
        game(week: 16, away: "buf", home: "nyj", month: 12, day: 27, hour: 13, minute: 0),
        game(week: 16, away: "cle", home: "cin", month: 12, day: 27, hour: 13, minute: 0),
        game(week: 16, away: "ind", home: "hou", month: 12, day: 27, hour: 13, minute: 0),
        game(week: 16, away: "ten", home: "jax", month: 12, day: 27, hour: 13, minute: 0),
        game(week: 16, away: "was", home: "nyg", month: 12, day: 27, hour: 13, minute: 0),
        game(week: 16, away: "phi", home: "dal", month: 12, day: 27, hour: 13, minute: 0),
        game(week: 16, away: "atl", home: "no",  month: 12, day: 27, hour: 13, minute: 0),
        game(week: 16, away: "tb",  home: "car", month: 12, day: 27, hour: 13, minute: 0),
        game(week: 16, away: "chi", home: "gb",  month: 12, day: 27, hour: 13, minute: 0),
        game(week: 16, away: "lac", home: "lv",  month: 12, day: 27, hour: 16, minute: 25),
        game(week: 16, away: "den", home: "lar", month: 12, day: 27, hour: 16, minute: 25),
        game(week: 16, away: "ari", home: "kc",  month: 12, day: 27, hour: 20, minute: 20), // SNF
        // Monday Dec 28 MNF
        game(week: 16, away: "gb",  home: "chi", month: 12, day: 28, hour: 20, minute: 15),
    ] }
}

// MARK: - Seeder Admin Trigger View

struct NFLPickEmSeederView: View {
    @ObservedObject var store: NFLPickEmStore

    @State private var status: String = ""
    @State private var isRunning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seed 2026 NFL Schedule")
                .font(.headline)

            Text("Seeds all 16 weeks (≈256 games) into Firestore. Idempotent — safe to re-run. Does NOT overwrite game results.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !status.isEmpty {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(isRunning ? "Seeding…" : "Seed Schedule to Firestore") {
                Task { await runSeed() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRunning)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func runSeed() async {
        isRunning = true
        status = "Seeding…"
        let seeder = NFLPickEmSeeder()
        do {
            try await seeder.seed()
            status = "✅ Done! Schedule seeded successfully."
        } catch {
            status = "❌ Error: \(error.localizedDescription)"
        }
        isRunning = false
    }
}
