//
//  WeeklyChallengeSeeder2026W35.swift
//  Best Man Challenge
//
//  Week 35: CFB Week 1 Ranked Pick 'Em
//  Dates: Aug 31 – Sep 7, 2026  |  Games: opening weekend (Thu Sep 3 – Mon Sep 7)
//  Mechanic: STRAIGHT PICK 'EM on the Prop Bets engine (same approach as W33).
//            Each ranked team's Week 1 game = one multiple_choice prop with two
//            options (the two teams). Pick the winner. 1 point per game.
//
//  SOURCE: 2026 AFCA Coaches Poll Top 25 (AP preseason poll not yet published at
//  build time). Matchups pulled per-team from ESPN's 2026 schedule data.
//
//  BOARD = 23 games / 23 points. Notes on how we got there:
//    • LSU (#13) hosts Clemson (#23) — ONE game covers both ranked teams.
//    • USC (#14) is EXCLUDED: their opener is Sat Aug 29, a week before the rest
//      of the slate. A pick 'em locks the whole board at once, so USC's game would
//      be over before picks lock. To include USC you'd need a separate/earlier
//      board. (25 ranked − USC − Clemson-folded-into-LSU = 23 games.)
//
//  LOCK: Thu Sep 3 @ 5:00 PM PT — first kickoff of the slate (Missouri, 8pm ET).
//        Whole board locks then; games run Sep 3 (Thu) → Sep 7 (Mon, Labor Day).
//
//  Unique market + unique option ids per game (see W33 note): required so the
//  prop engine scores each game independently instead of pool-scoring them.
//
//  ADMIN GRADING: Weekly Challenges → (W35) → "Grade Prop Bets" → tap each
//  winner → "Grade All Submissions".
//
//  is_active seeded FALSE — flip to true to open picks. Safe re-seed: skips if
//  the doc already exists (won't wipe graded answers/picks).
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W35 {

    static let isReadyToSeed = true

    static func seedIfNeeded() async {
        guard isReadyToSeed else {
            print("ℹ️ W35 not ready — skipping.")
            return
        }

        let db = Firestore.firestore()
        let challengeId = "2026_w35"
        let challengeRef = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await challengeRef.getDocument()
            if snap.exists, (snap.data()?["type"] as? String) == "prop_bets" {
                print("ℹ️ W35 CFB Ranked Pick 'Em already seeded — skipping.")
                return
            }
            guard !games.isEmpty else {
                print("❌ W35 has no games — aborting seed.")
                return
            }
            try await seed(db: db, challengeRef: challengeRef, challengeId: challengeId)
            print("✅ W35 CFB Week 1 Ranked Pick 'Em seeded (\(games.count) games).")
        } catch {
            print("❌ W35 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    // MARK: - The 23 games (away shown first, home second). pos = display order.
    //
    // Ordered by the ranked team's Coaches Poll rank. For each game the RANKED
    // side is noted in the trailing comment.
    private static let games: [Game] = [
        Game(pos: 1,  market: "cfb_w1_g01", away: ("ballstate", "Ball State"),        home: ("ohiost", "Ohio State")),        // #1 Ohio State (H)
        Game(pos: 2,  market: "cfb_w1_g02", away: ("boisest", "Boise State"),         home: ("oregon", "Oregon")),            // #2 Oregon (H)
        Game(pos: 3,  market: "cfb_w1_g03", away: ("tnst", "Tennessee State"),        home: ("georgia", "Georgia")),          // #3 Georgia (H)
        Game(pos: 4,  market: "cfb_w1_g04", away: ("txst", "Texas State"),            home: ("texas", "Texas")),              // #4 Texas (H)
        Game(pos: 5,  market: "cfb_w1_g05", away: ("notredame", "Notre Dame"),        home: ("wisconsin", "Wisconsin")),      // #5 Notre Dame (neutral, Lambeau Field)
        Game(pos: 6,  market: "cfb_w1_g06", away: ("northtexas", "North Texas"),      home: ("indiana", "Indiana")),          // #6 Indiana (H)
        Game(pos: 7,  market: "cfb_w1_g07", away: ("miami", "Miami (FL)"),            home: ("stanford", "Stanford")),        // #7 Miami (A)
        Game(pos: 8,  market: "cfb_w1_g08", away: ("mostate", "Missouri State"),      home: ("texasam", "Texas A&M")),        // #8 Texas A&M (H)
        Game(pos: 9,  market: "cfb_w1_g09", away: ("utep", "UTEP"),                   home: ("oklahoma", "Oklahoma")),        // #9 Oklahoma (H)
        Game(pos: 10, market: "cfb_w1_g10", away: ("olemiss", "Ole Miss"),            home: ("louisville", "Louisville")),    // #10 Ole Miss (neutral, Music City Kickoff)
        Game(pos: 11, market: "cfb_w1_g11", away: ("ecu", "East Carolina"),           home: ("alabama", "Alabama")),          // #11 Alabama (H)
        Game(pos: 12, market: "cfb_w1_g12", away: ("acu", "Abilene Christian"),       home: ("texastech", "Texas Tech")),     // #12 Texas Tech (H)
        Game(pos: 13, market: "cfb_w1_g13", away: ("clemson", "Clemson"),             home: ("lsu", "LSU")),                  // #13 LSU (H) vs #23 Clemson — RANKED vs RANKED
        Game(pos: 14, market: "cfb_w1_g14", away: ("utahtech", "Utah Tech"),          home: ("byu", "BYU")),                  // #15 BYU (H)
        Game(pos: 15, market: "cfb_w1_g15", away: ("wmich", "Western Michigan"),      home: ("michigan", "Michigan")),        // #16 Michigan (H)
        Game(pos: 16, market: "cfb_w1_g16", away: ("marshall", "Marshall"),           home: ("pennst", "Penn State")),        // #17 Penn State (H)
        Game(pos: 17, market: "cfb_w1_g17", away: ("furman", "Furman"),               home: ("tennessee", "Tennessee")),      // #18 Tennessee (H)
        Game(pos: 18, market: "cfb_w1_g18", away: ("wazzu", "Washington State"),      home: ("washington", "Washington")),    // #19 Washington (H) — Apple Cup
        Game(pos: 19, market: "cfb_w1_g19", away: ("smu", "SMU"),                     home: ("fsu", "Florida State")),        // #20 SMU (A) — Labor Day, Mon Sep 7
        Game(pos: 20, market: "cfb_w1_g20", away: ("idaho", "Idaho"),                 home: ("utah", "Utah")),                // #21 Utah (H)
        Game(pos: 21, market: "cfb_w1_g21", away: ("niu", "Northern Illinois"),       home: ("iowa", "Iowa")),                // #22 Iowa (H)
        Game(pos: 22, market: "cfb_w1_g22", away: ("oregonst", "Oregon State"),       home: ("houston", "Houston")),          // #24 Houston (H)
        Game(pos: 23, market: "cfb_w1_g23", away: ("uapb", "Arkansas-Pine Bluff"),    home: ("missouri", "Missouri"))         // #25 Missouri (H)
    ]

    private static func seed(db: Firestore, challengeRef: DocumentReference, challengeId: String) async throws {

        // Lock at first kickoff of the slate: Missouri, Thu Sep 3 @ 8pm ET = 5pm PT.
        let locksAt   = makeTimestampLA(year: 2026, month: 9, day: 3,  hour: 17, minute: 0)
        let startDate = makeTimestampLA(year: 2026, month: 8, day: 31, hour: 0,  minute: 0)
        let endDate   = makeTimestampLA(year: 2026, month: 9, day: 7,  hour: 23, minute: 59)

        let challengeData: [String: Any] = [
            "week": 35,
            "weekInt": 35,
            "title": "Week 35: CFB Week 1 Ranked Pick 'Em",
            "description": "Opening weekend! Pick the winner of every ranked team's Week 1 game — \(games.count) games, 1 point each. Featuring Clemson at LSU. Picks lock Thursday at 5pm PT (first kickoff).",
            "type": "prop_bets",
            "game_format": "pick_em",

            "is_active": false,
            "is_finalized": false,
            "finalized_at": NSNull(),
            "answer": NSNull(),

            "max_points": games.count,       // 23 — 1 pt per game
            "winner_bonus": 0,
            "winner_bonuses_applied": false,
            "winners": [],

            "startDate": startDate,
            "endDate": endDate,
            "locksAt": locksAt,

            "created_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp()
        ]

        let batch = db.batch()
        batch.setData(challengeData, forDocument: challengeRef, merge: false)

        let propsRef = challengeRef.collection("props")
        for game in games {
            let propId = "g\(String(format: "%02d", game.pos))"
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

        // Full names in the prompt (college names don't shorten cleanly).
        var prompt: String { "Game \(pos): \(away.name) @ \(home.name)" }

        func propDict(id: String) -> [String: Any] {
            let options: [[String: Any]] = [
                ["id": away.id, "position": 0, "label": away.name],
                ["id": home.id, "position": 1, "label": home.name]
            ]
            return [
                "id": id,
                "position": pos,
                "kind": "multiple_choice",
                "prompt": prompt,
                "market": market,
                "options": options,
                "correct_option_id": NSNull(),
                "is_finalized": false,
                "finalized_at": NSNull(),
                "is_active": true,
                "updated_at": FieldValue.serverTimestamp()
            ]
        }
    }

    private static func makeTimestampLA(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Timestamp {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let comps = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return Timestamp(date: cal.date(from: comps) ?? Date())
    }
}
