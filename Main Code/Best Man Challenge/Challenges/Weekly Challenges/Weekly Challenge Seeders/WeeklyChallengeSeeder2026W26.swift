//
//  WeeklyChallengeSeeder2026W26.swift
//  Best Man Challenge
//
//  Week 26: July 4th Cookout Photo Challenge
//  Dates: Jun 29–Jul 5, 2026
//  Uses setData(merge: true) — document already exists as TBD placeholder.
//
//  5 prompts × 2 pts per submission = 10 base pts
//  Amanda votes 1 winner per category (+1 pt each) = 5 bonus pts
//  Max: 15 pts
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W26 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w26"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()
            if snap.exists,
               let title = snap.data()?["title"] as? String,
               !title.contains("TBD") {
                print("ℹ️ W26 already seeded — skipping.")
                return
            }
            try await ref.setData(buildData(), merge: true)
            print("✅ W26 July 4th Cookout Photo Challenge seeded.")
        } catch {
            print("❌ W26 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func buildData() -> [String: Any] {
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 29
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let startDate = calendar.date(from: comps)!
        comps.month = 7; comps.day = 6
        let endDate = calendar.date(from: comps)!

        return [
            "week": 26,
            "weekInt": 26,
            "title": "Week 26: July 4th Cookout Challenge",
            "description": "It's the 4th of July — show us how you celebrate! Submit a photo for each of the 5 prompts. Amanda votes on 1 winner per category for a bonus point. 2 pts per submission + up to 5 bonus pts = 15 max.",
            "type": "photo_challenge",
            "game_format": "photo_challenge",

            "is_active": false,
            "is_finalized": false,
            "finalized_at": NSNull(),

            "max_points": 15,
            "winner_bonus": 1,
            "winner_bonuses_applied": false,
            "winners": [],

            "start_date": Timestamp(date: startDate),
            "end_date": Timestamp(date: endDate),

            "photo_challenge": [
                "points_per_submission": 2,
                "bonus_points_per_winner": 1,
                "judge_name": "Amanda",
                "prompts": [
                    [
                        "id": "p1",
                        "label": "Food",
                        "emoji": "🍖",
                        "description": "Show us what's on the grill (or the plate). Best cookout spread wins."
                    ],
                    [
                        "id": "p2",
                        "label": "Fireworks",
                        "emoji": "🎆",
                        "description": "Catch a fireworks shot — live, sparklers, anything that explodes."
                    ],
                    [
                        "id": "p3",
                        "label": "Fit",
                        "emoji": "👕",
                        "description": "Show off your July 4th fit. Red, white, and blue encouraged."
                    ],
                    [
                        "id": "p4",
                        "label": "Drinks",
                        "emoji": "🍺",
                        "description": "What are you drinking this weekend? Beers, cocktails, whatever."
                    ],
                    [
                        "id": "p5",
                        "label": "Freestyle",
                        "emoji": "🇺🇸",
                        "description": "Your best July 4th moment — anything goes."
                    ]
                ]
            ],

            "updated_at": FieldValue.serverTimestamp()
        ]
    }
}
