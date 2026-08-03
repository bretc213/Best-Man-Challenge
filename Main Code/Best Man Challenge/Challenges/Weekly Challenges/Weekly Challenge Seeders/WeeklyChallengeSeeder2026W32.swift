//
//  WeeklyChallengeSeeder2026W32.swift
//  Best Man Challenge
//
//  Week 32: Connections — Best Man Edition #1
//  Dates: Aug 10–16, 2026
//  Mechanic: NYT Connections-style. 16 words → 4 hidden groups of 4.
//            Solve each group for points. 4 mistakes allowed (max_mistakes).
//
//  Scoring (matches schedule: 10 pts max):
//    🟡 Yellow  = 1 pt   (easiest)
//    🟢 Green   = 2 pts
//    🔵 Blue    = 3 pts
//    🟣 Purple  = 4 pts  (trickiest)
//    Total = 1 + 2 + 3 + 4 = 10 pts
//
//  FIRST-DRAFT GRID — swap in personal words anytime (see PERSONALIZE notes below).
//  Medium difficulty: two deliberate red-herring traps drive the challenge —
//    • BLOCK  → reads as football (block a kick) but belongs to "___ PARTY"
//    • HOUSE  → reads as poker ("the house") but belongs to "___ PARTY"
//
//  Uses setData WITHOUT merge so it fully overwrites any earlier W32 doc.
//  Re-seeds until the connections_config is present, then skips.
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W32 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w32"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()

            // Skip only once the Connections grid is actually in place.
            if snap.exists,
               let title = snap.data()?["title"] as? String,
               title.contains("Connections"),
               snap.data()?["connections_config"] != nil {
                print("ℹ️ W32 Connections already seeded — skipping.")
                return
            }

            try await ref.setData(buildData())
            print("✅ W32 Connections (Best Man Edition #1) seeded.")
        } catch {
            print("❌ W32 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func buildData() -> [String: Any] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 10
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let startDate = cal.date(from: comps)!
        comps.day = 17                     // end = Aug 17 (Mon)
        let endDate = cal.date(from: comps)!

        // MARK: - The 16-word grid (4 categories × 4 words)
        //
        // PERSONALIZE: The four categories map to the schedule's themes
        // (Bret, Amanda, the group, the year). Keep any category's structure,
        // just swap the 4 words — e.g. make Green the guys' first names, or
        // Purple an inside-joke set. Words are auto-uppercased by the app.
        let categories: [[String: Any]] = [
            [
                "id": "yellow",
                "name": "WEDDING DAY",                       // 🟡 easiest  — the wedding
                "color": "yellow",
                "point_value": 1,
                "words": ["VOWS", "TOAST", "CAKE", "VEIL"]
            ],
            [
                "id": "green",
                "name": "POKER NIGHT",                       // 🟢 the group's game night
                "color": "green",
                "point_value": 2,
                "words": ["FOLD", "BLUFF", "CHIPS", "ANTE"]
            ],
            [
                "id": "blue",
                "name": "FOOTBALL SUNDAY",                   // 🔵 what the crew does all fall
                "color": "blue",
                "point_value": 3,
                "words": ["BLITZ", "SACK", "PUNT", "RUSH"]
            ],
            [
                "id": "purple",
                "name": "___ PARTY",                          // 🟣 trickiest — wordplay
                "color": "purple",
                "point_value": 4,
                "words": ["BACHELOR", "BLOCK", "HOUSE", "THIRD"]
            ]
        ]

        return [
            "week": 32,
            "weekInt": 32,
            "title": "Week 32: Connections — Best Man Edition #1",
            "description": "16 words, 4 hidden groups of 4. Tap four words you think belong together and hit Submit. Find all four groups — but you only get 4 mistakes. Easiest group is worth 1 point, hardest is worth 4. Watch out for words that look like they fit more than one group.",
            "type": "connections",
            "game_format": "connections",

            "is_active": false,
            "is_finalized": false,
            "finalized_at": NSNull(),

            "max_points": 10,
            "winner_bonus": 0,
            "winner_bonuses_applied": false,
            "winners": [],

            "start_date": Timestamp(date: startDate),
            "end_date": Timestamp(date: endDate),

            "connections_config": [
                "max_mistakes": 4,
                "categories": categories
            ],

            "updated_at": FieldValue.serverTimestamp()
        ]
    }
}
