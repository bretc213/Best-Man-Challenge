//
//  WeeklyChallengeSeeder2026W31.swift
//  Best Man Challenge
//
//  Week 31: Triple Wordle — BRIDE, RINGS, AISLE
//  Dates: Aug 3–9, 2026
//  Uses setData(merge: true) — document already exists as TBD placeholder.
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W31 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w31"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()

            // Skip if already fully seeded (not a TBD placeholder)
            if snap.exists,
               let title = snap.data()?["title"] as? String,
               !title.contains("TBD") {
                print("ℹ️ W31 already seeded — skipping.")
                return
            }

            try await ref.setData(buildData(), merge: true)
            print("✅ W31 Triple Wordle seeded.")
        } catch {
            print("❌ W31 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func buildData() -> [String: Any] {
        // W24 = Jun 15 → W31 = Aug 3 (7 weeks later)
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 3
        components.hour = 0; components.minute = 0; components.second = 0
        let startDate = calendar.date(from: components)!
        components.day = 10    // end = Aug 10 (Mon)
        let endDate = calendar.date(from: components)!

        return [
            "week": 31,
            "weekInt": 31,
            "title": "Week 31: Triple Wordle",
            "description": "Three wedding-themed Wordle puzzles in one week. Solve all three words for maximum points — the fewer guesses you use, the more points you earn.",
            "type": "multi_wordle",
            "game_format": "multi_wordle",

            "is_active": false,
            "is_finalized": false,
            "finalized_at": NSNull(),

            "max_points": 21,   // 7+7+7 if each solved in 1 try (theoretical max)
            "winner_bonus": 0,
            "winner_bonuses_applied": false,
            "winners": [],

            "start_date": Timestamp(date: startDate),
            "end_date": Timestamp(date: endDate),

            "multi_wordle": [
                "words": [
                    [
                        "id": "word1",
                        "answer": "BRIDE",
                        "word_length": 5,
                        "max_attempts": 6,
                        "label": "BRIDE"
                    ],
                    [
                        "id": "word2",
                        "answer": "RINGS",
                        "word_length": 5,
                        "max_attempts": 6,
                        "label": "RINGS"
                    ],
                    [
                        "id": "word3",
                        "answer": "AISLE",
                        "word_length": 5,
                        "max_attempts": 6,
                        "label": "AISLE"
                    ]
                ]
            ],

            "updated_at": FieldValue.serverTimestamp()
        ]
    }
}
