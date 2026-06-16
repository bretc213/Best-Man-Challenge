//
//  WeeklyChallengeSeeder2026W29.swift
//  Best Man Challenge
//
//  Week 29: Triple Wordle — BEACH, SUNNY, GRILL
//  Dates: Jul 20–26, 2026
//  Uses setData(merge: true) — document already exists as TBD placeholder.
//
//  Summer-themed multi-wordle. 3 words × up to 7 pts each = 21 theoretical max.
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W29 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w29"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()
            if snap.exists,
               let title = snap.data()?["title"] as? String,
               !title.contains("TBD") {
                print("ℹ️ W29 already seeded — skipping.")
                return
            }
            try await ref.setData(buildData(), merge: true)
            print("✅ W29 Triple Wordle (Summer Edition) seeded.")
        } catch {
            print("❌ W29 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func buildData() -> [String: Any] {
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 20
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let startDate = calendar.date(from: comps)!
        comps.day = 27
        let endDate = calendar.date(from: comps)!

        return [
            "week": 29,
            "weekInt": 29,
            "title": "Week 29: Summer Triple Wordle",
            "description": "Three summer-themed Wordle puzzles in one week. Solve all three words for maximum points — the fewer guesses you use, the more points you earn.",
            "type": "multi_wordle",
            "game_format": "multi_wordle",

            "is_active": false,
            "is_finalized": false,
            "finalized_at": NSNull(),

            "max_points": 21,   // 7+7+7 if each solved in 1 guess (theoretical max)
            "winner_bonus": 0,
            "winner_bonuses_applied": false,
            "winners": [],

            "start_date": Timestamp(date: startDate),
            "end_date": Timestamp(date: endDate),

            "multi_wordle": [
                "words": [
                    [
                        "id": "word1",
                        "answer": "BEACH",
                        "word_length": 5,
                        "max_attempts": 6,
                        "label": "BEACH"
                    ],
                    [
                        "id": "word2",
                        "answer": "SUNNY",
                        "word_length": 5,
                        "max_attempts": 6,
                        "label": "SUNNY"
                    ],
                    [
                        "id": "word3",
                        "answer": "GRILL",
                        "word_length": 5,
                        "max_attempts": 6,
                        "label": "GRILL"
                    ]
                ]
            ],

            "updated_at": FieldValue.serverTimestamp()
        ]
    }
}
