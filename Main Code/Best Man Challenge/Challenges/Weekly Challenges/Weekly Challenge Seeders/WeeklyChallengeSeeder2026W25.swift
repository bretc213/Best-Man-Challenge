//
//  WeeklyChallengeSeeder2026W25.swift
//  Best Man Challenge
//
//  Week 25: Halfway Point Challenge 🏆
//  Dates: Jun 22–28, 2026
//
//  5 progressive mini-games, 6 pts each = 30 pts total
//  Complete a round to unlock the next.
//
//  Round 1 — Ride the Bus   (card game, 4 questions in a row)
//  Round 2 — Blackjack      (beat the dealer 100x, streak multiplier)
//  Round 3 — Yahtzee Lite   (6 lower-section categories)
//  Round 4 — Memory         (6×4 player face grid, 12 strikes max)
//  Round 5 — Mastermind     (5 pegs, 7 colors, no repeats)
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W25 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w25"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()
            if snap.exists,
               let title = snap.data()?["title"] as? String,
               !title.contains("TBD") {
                print("ℹ️ W25 already seeded — skipping.")
                return
            }
            try await ref.setData(buildData(), merge: true)
            print("✅ W25 Halfway Point Challenge seeded.")
        } catch {
            print("❌ W25 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func buildData() -> [String: Any] {
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 22
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let startDate = calendar.date(from: comps)!
        comps.day = 29
        let endDate = calendar.date(from: comps)!

        return [
            "week": 25,
            "weekInt": 25,
            "title": "Week 25: Halfway Point Challenge",
            "description": "You've made it to the halfway point — now prove it. Five mini-games stand between you and 30 points. Complete each round to unlock the next. No shortcuts.",
            "type": "halfway_challenge",
            "game_format": "halfway_challenge",

            "is_active": false,
            "is_finalized": false,
            "finalized_at": NSNull(),

            "max_points": 30,
            "points_per_round": 6,
            "total_rounds": 5,
            "winner_bonus": 1,
            "winner_bonuses_applied": false,
            "winners": [],

            "start_date": Timestamp(date: startDate),
            "end_date": Timestamp(date: endDate),

            "halfway_challenge": [
                "rounds": [
                    [
                        "id": "round1",
                        "position": 1,
                        "title": "Ride the Bus",
                        "emoji": "🚌",
                        "description": "Answer all 4 card questions in a row without a mistake. Mess up — start back at Q1.",
                        "points": 6
                    ],
                    [
                        "id": "round2",
                        "position": 2,
                        "title": "Blackjack",
                        "emoji": "🃏",
                        "description": "Beat the dealer 100 times. Build a win streak to multiply your progress — lose and your multiplier resets.",
                        "points": 6
                    ],
                    [
                        "id": "round3",
                        "position": 3,
                        "title": "Yahtzee",
                        "emoji": "🎲",
                        "description": "Complete all 6 lower-section categories: three/four of a kind, full house, straights, and Yahtzee.",
                        "points": 6
                    ],
                    [
                        "id": "round4",
                        "position": 4,
                        "title": "Memory",
                        "emoji": "🧠",
                        "description": "Match all 12 pairs of groomsmen photos. 12 strikes and the board resets.",
                        "points": 6
                    ],
                    [
                        "id": "round5",
                        "position": 5,
                        "title": "Mastermind",
                        "emoji": "🔵",
                        "description": "Crack the 5-color code. You'll get exact/misplaced/wrong counts — no position hints.",
                        "points": 6
                    ]
                ]
            ],

            "updated_at": FieldValue.serverTimestamp()
        ]
    }
}
