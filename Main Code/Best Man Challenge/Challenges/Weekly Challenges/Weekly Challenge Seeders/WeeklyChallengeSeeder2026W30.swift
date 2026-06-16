//
//  WeeklyChallengeSeeder2026W30.swift
//  Best Man Challenge
//
//  Week 30: Photo Challenge — Summer Shenanigans
//  Dates: Jul 27–Aug 2, 2026
//  Uses setData(merge: true) — document already exists as TBD placeholder.
//
//  ⚠️ REVIEW BEFORE SEEDING: Confirm photo prompts with Bret.
//  Current prompts are suggestions — customize as needed.
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W30 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w30"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()
            if snap.exists,
               let title = snap.data()?["title"] as? String,
               !title.contains("TBD") {
                print("ℹ️ W30 already seeded — skipping.")
                return
            }
            try await ref.setData(buildData(), merge: true)
            print("✅ W30 Photo Challenge (Summer Shenanigans) seeded.")
        } catch {
            print("❌ W30 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func buildData() -> [String: Any] {
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 27
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let startDate = calendar.date(from: comps)!
        comps.month = 8; comps.day = 3
        let endDate = calendar.date(from: comps)!

        return [
            "week": 30,
            "weekInt": 30,
            "title": "Week 30: Photo Challenge — Summer Shenanigans",
            "description": "Submit photos for each prompt below. The judge picks a winner per category — winners earn bonus points. Get creative!",
            "type": "photo_challenge",
            "game_format": "photo_challenge",

            "is_active": false,
            "is_finalized": false,
            "finalized_at": NSNull(),

            "max_points": 8,    // 4 prompts × 2 pts per submission (bonus TBD)
            "winner_bonus": 2,
            "winner_bonuses_applied": false,
            "winners": [],

            "start_date": Timestamp(date: startDate),
            "end_date": Timestamp(date: endDate),

            "photo_challenge": [
                "points_per_submission": 2,
                "bonus_points_per_winner": 2,
                "judge_name": "Bret",
                "prompts": [
                    [
                        "id": "p1",
                        "label": "Best Dressed",
                        "emoji": "👔",
                        "description": "Post your best summer fit. Style points count."
                    ],
                    [
                        "id": "p2",
                        "label": "Most Adventurous",
                        "emoji": "🌊",
                        "description": "Show us something wild you did this summer — beach, hike, travel, anything."
                    ],
                    [
                        "id": "p3",
                        "label": "Grill Master",
                        "emoji": "🔥",
                        "description": "Prove your BBQ credentials. Show us what you made."
                    ],
                    [
                        "id": "p4",
                        "label": "Best Group Shot",
                        "emoji": "📸",
                        "description": "Submit a photo with other Best Man Challenge contestants."
                    ]
                ]
            ],

            "updated_at": FieldValue.serverTimestamp()
        ]
    }
}
