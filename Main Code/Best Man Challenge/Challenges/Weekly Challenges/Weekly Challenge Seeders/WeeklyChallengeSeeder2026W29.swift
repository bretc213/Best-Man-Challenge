//
//  WeeklyChallengeSeeder2026W29.swift
//  Best Man Challenge
//
//  Week 29: Triple Wordle — BRIDE, RINGS, AISLE
//  Dates: Jul 20–26, 2026
//  (Was W31 — moved earlier in schedule)
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

            // Skip if already seeded with Triple Wordle content
            if snap.exists,
               let title = snap.data()?["title"] as? String,
               title.contains("Triple Wordle") {
                print("ℹ️ W29 Triple Wordle already seeded — skipping.")
                return
            }

            // setData without merge — fully replaces any prior content at this doc ID
            try await ref.setData(buildData())
            print("✅ W29 Triple Wordle seeded.")
        } catch {
            print("❌ W29 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func buildData() -> [String: Any] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 20
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let startDate = cal.date(from: comps)!
        comps.day = 27
        let endDate = cal.date(from: comps)!

        return [
            "week": 29,
            "weekInt": 29,
            "title": "Week 29: Triple Wordle",
            "description": "Three wedding-themed Wordle puzzles in one week. Solve all three words for maximum points — the fewer guesses you use, the more points you earn.",
            "type": "multi_wordle",
            "game_format": "multi_wordle",

            "is_active": false,
            "is_finalized": false,
            "finalized_at": NSNull(),

            "max_points": 21,
            "winner_bonus": 0,
            "winner_bonuses_applied": false,
            "winners": [],

            "start_date": Timestamp(date: startDate),
            "end_date": Timestamp(date: endDate),

            "multi_wordle": [
                "words": [
                    ["id": "word1", "answer": "BRIDE", "word_length": 5, "max_attempts": 6, "label": "BRIDE"],
                    ["id": "word2", "answer": "RINGS", "word_length": 5, "max_attempts": 6, "label": "RINGS"],
                    ["id": "word3", "answer": "AISLE", "word_length": 5, "max_attempts": 6, "label": "AISLE"]
                ]
            ],

            "updated_at": FieldValue.serverTimestamp()
        ]
    }
}
