//
//  WeeklyChallengeSeeder2026W33.swift
//  Best Man Challenge
//
//  Week 33: NFL Preseason Pick 'Em
//  Dates: Aug 17–23, 2026  |  Games: Saturday, Aug 22, 2026
//  Mechanic: STRAIGHT PICK 'EM built on the existing Prop Bets engine.
//            Each of the 10 Saturday games is one multiple_choice "prop" with
//            two options (away team / home team). Pick the winner of each game.
//
//  Scoring (matches schedule: 10 pts max):
//    1 point per correct game. 10 games = 10 pts.
//    PropBetsStore computes max_score = number of graded props, +1 per exact match.
//
//  LOCK: Saturday, Aug 22 @ 9:00 AM PT — first kickoff (Commanders @ Lions, 12 PM ET).
//        Picks are editable until then, then the whole board locks at once.
//
//  ⚠️ IMPORTANT — why every game gets a UNIQUE market + UNIQUE option ids:
//    PropBetsStore.recomputeScore() and PropBetsAdminGradingVM.gradeAllSubmissions()
//    both group props by (sorted option-id set) + (market split on " #"). Any props
//    that share BOTH an option-id pool AND a market base get "pool scored" and would
//    also trip the duplicate-pick validator. A pick 'em must NOT pool — so each game
//    uses a distinct market string (no " #") and team-abbreviation option ids
//    (e.g. "was"/"det"), guaranteeing each game is scored as an independent
//    exact-match prop. Do NOT collapse these to shared opt_0/opt_1 ids.
//
//  ADMIN GRADING: Weekly Challenges → (W33, prop bets) → "Grade Prop Bets".
//    Tap the winning team on each game, then "Grade All Submissions".
//
//  SAFE RE-SEED: If the challenge doc already exists we skip entirely, so a
//    re-launch never wipes correct_option_id answers you've already set.
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W33 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w33"
        let challengeRef = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await challengeRef.getDocument()

            // Once seeded, never touch it again — protects graded answers + player picks.
            if snap.exists, (snap.data()?["type"] as? String) == "prop_bets" {
                print("ℹ️ W33 NFL Preseason Pick 'Em already seeded — skipping.")
                return
            }

            try await seed(db: db, challengeRef: challengeRef, challengeId: challengeId)
            print("✅ W33 NFL Preseason Pick 'Em seeded (10 games).")
        } catch {
            print("❌ W33 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func seed(db: Firestore, challengeRef: DocumentReference, challengeId: String) async throws {

        // 🔒 Lock at first kickoff — Sat Aug 22, 2026 @ 9:00 AM Pacific.
        let locksAt   = makeTimestampLA(year: 2026, month: 8, day: 22, hour: 9,  minute: 0)
        let startDate = makeTimestampLA(year: 2026, month: 8, day: 17, hour: 0,  minute: 0)
        let endDate   = makeTimestampLA(year: 2026, month: 8, day: 23, hour: 23, minute: 59)

        // Top-level challenge doc. Parsed by WeeklyChallengeManager.parseWeeklyChallenge
        // (requires week/title/description/type; reads startDate/endDate/locksAt Timestamps).
        //
        // is_active is seeded FALSE so this doesn't clobber the currently-live challenge.
        // Flip is_active → true (your normal activation flow) to open picks for the week;
        // the board then auto-locks at locksAt.
        let challengeData: [String: Any] = [
            "week": 33,
            "weekInt": 33,
            "title": "Week 33: NFL Preseason Pick 'Em",
            "description": "Pick the winner of all 10 Saturday preseason games (Aug 22). 1 point per correct pick — 10 points up for grabs. You can change your picks any time until the first kickoff (Sat 9:00 AM PT), then the board locks.",
            "type": "prop_bets",
            "game_format": "pick_em",

            "is_active": false,
            "is_finalized": false,
            "finalized_at": NSNull(),
            "answer": NSNull(),

            "max_points": 10,
            "winner_bonus": 0,
            "winner_bonuses_applied": false,
            "winners": [],

            "startDate": startDate,
            "endDate": endDate,
            "locksAt": locksAt,

            "created_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp()
        ]

        // The 10 Saturday, Aug 22, 2026 games — away @ home (position = display order).
        // Option position 0 = away, 1 = home. Option ids = team abbreviations (unique per game).
        let games: [Game] = [
            Game(pos: 1,  market: "nfl_pre_w2_was_det", away: ("was", "Washington Commanders"), home: ("det", "Detroit Lions")),
            Game(pos: 2,  market: "nfl_pre_w2_buf_cle", away: ("buf", "Buffalo Bills"),          home: ("cle", "Cleveland Browns")),
            Game(pos: 3,  market: "nfl_pre_w2_atl_ind", away: ("atl", "Atlanta Falcons"),        home: ("ind", "Indianapolis Colts")),
            Game(pos: 4,  market: "nfl_pre_w2_bal_min", away: ("bal", "Baltimore Ravens"),       home: ("min", "Minnesota Vikings")),
            Game(pos: 5,  market: "nfl_pre_w2_no_lar",  away: ("no",  "New Orleans Saints"),     home: ("lar", "Los Angeles Rams")),
            Game(pos: 6,  market: "nfl_pre_w2_nyg_mia", away: ("nyg", "New York Giants"),        home: ("mia", "Miami Dolphins")),
            Game(pos: 7,  market: "nfl_pre_w2_chi_cin", away: ("chi", "Chicago Bears"),          home: ("cin", "Cincinnati Bengals")),
            Game(pos: 8,  market: "nfl_pre_w2_phi_ne",  away: ("phi", "Philadelphia Eagles"),    home: ("ne",  "New England Patriots")),
            Game(pos: 9,  market: "nfl_pre_w2_kc_tb",   away: ("kc",  "Kansas City Chiefs"),     home: ("tb",  "Tampa Bay Buccaneers")),
            Game(pos: 10, market: "nfl_pre_w2_dal_ari", away: ("dal", "Dallas Cowboys"),         home: ("ari", "Arizona Cardinals"))
        ]

        let batch = db.batch()

        // Overwrite the doc so required fields are present + correctly typed.
        batch.setData(challengeData, forDocument: challengeRef, merge: false)

        // Seed the games as props.
        let propsRef = challengeRef.collection("props")
        for game in games {
            let propId = "g\(String(format: "%02d", game.pos))"   // g01…g10
            batch.setData(game.propDict(id: propId), forDocument: propsRef.document(propId), merge: false)
        }

        try await batch.commit()
        print("✅ Seeded weekly_challenges/\(challengeId) + \(games.count) game props.")
    }

    // MARK: - Game model / builder

    private struct Game {
        let pos: Int
        let market: String
        let away: (id: String, name: String)   // shown first (position 0)
        let home: (id: String, name: String)   // shown second (position 1)

        var prompt: String {
            // e.g. "Game 1: Commanders @ Lions"
            "Game \(pos): \(shortName(away.name)) @ \(shortName(home.name))"
        }

        func propDict(id: String) -> [String: Any] {
            let options: [[String: Any]] = [
                ["id": away.id, "position": 0, "label": away.name],   // no odds — labels only
                ["id": home.id, "position": 1, "label": home.name]
            ]
            return [
                "id": id,
                "position": pos,
                "kind": "multiple_choice",
                "prompt": prompt,
                "market": market,                 // UNIQUE per game — keeps scoring independent
                "options": options,

                // Admin sets these when grading results:
                "correct_option_id": NSNull(),
                "is_finalized": false,
                "finalized_at": NSNull(),

                "is_active": true,
                "updated_at": FieldValue.serverTimestamp()
            ]
        }

        /// "Washington Commanders" -> "Commanders" for a compact prompt.
        private func shortName(_ full: String) -> String {
            full.components(separatedBy: " ").last ?? full
        }
    }

    // MARK: - Helpers

    private static func makeTimestampLA(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Timestamp {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let comps = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        let date = cal.date(from: comps) ?? Date()
        return Timestamp(date: date)
    }
}
