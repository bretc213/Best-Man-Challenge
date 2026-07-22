//
//  WeeklyChallengeSeeder2026W30.swift
//  Best Man Challenge
//
//  Week 30: Bret & Amanda Edition Scavenger Hunt
//  Dates: Jul 27–Aug 2, 2026
//  10 items × 1 pt each = 10 base pts
//  Item 10 earns +1 bonus pt if BOTH Bret AND Amanda are in the photo
//  Max points: 11
//  (Was W29 — moved later in schedule)
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
               title.contains("Bret") || title.contains("Amanda") {
                print("ℹ️ W30 Bret & Amanda Scavenger Hunt already seeded — skipping.")
                return
            }
            try await ref.setData(buildData())
            print("✅ W30 Bret & Amanda Scavenger Hunt seeded.")
        } catch {
            print("❌ W30 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func buildData() -> [String: Any] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 27
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let startDate = cal.date(from: comps)!
        comps.month = 8; comps.day = 3
        let endDate = cal.date(from: comps)!

        let items: [[String: Any]] = [
            ["id": "item1",  "position": 1,  "clue": "A ship and a bottle",                              "emoji": "⚓", "point_value": 1, "bonus_eligible": false],
            ["id": "item2",  "position": 2,  "clue": "The Infinity logo",                                "emoji": "∞", "point_value": 1, "bonus_eligible": false],
            ["id": "item3",  "position": 3,  "clue": "A baseball jersey holding something random",       "emoji": "⚾", "point_value": 1, "bonus_eligible": false],
            ["id": "item4",  "position": 4,  "clue": "Watching your favorite rom-com",                   "emoji": "🎬", "point_value": 1, "bonus_eligible": false],
            ["id": "item5",  "position": 5,  "clue": "Photo in a Yankees or Dodgers hat",                "emoji": "🧢", "point_value": 1, "bonus_eligible": false],
            ["id": "item6",  "position": 6,  "clue": "Drinking a Jack in the Box shake",                 "emoji": "🥤", "point_value": 1, "bonus_eligible": false],
            ["id": "item7",  "position": 7,  "clue": "Screenshot of your favorite country song playing", "emoji": "🎵", "point_value": 1, "bonus_eligible": false],
            ["id": "item8",  "position": 8,  "clue": "Eating your favorite Mexican food dish",           "emoji": "🌮", "point_value": 1, "bonus_eligible": false],
            ["id": "item9",  "position": 9,  "clue": "Drinking a cup of coffee",                        "emoji": "☕", "point_value": 1, "bonus_eligible": false],
            ["id": "item10", "position": 10, "clue": "Your favorite photo with Bret or Amanda",          "emoji": "💛", "point_value": 1, "bonus_eligible": true,
             "bonus_clue": "+1 bonus point if BOTH Bret AND Amanda are in the photo"]
        ]

        return [
            "week": 30,
            "weekInt": 30,
            "title": "Week 30: Bret & Amanda Edition",
            "description": "A personal scavenger hunt inspired by Bret & Amanda's world. Find all 10 items and snap photo proof. Item 10 earns a bonus point if BOTH Bret AND Amanda are in the photo.",
            "type": "scavenger_hunt",
            "game_format": "scavenger_hunt",
            "is_active": false,
            "is_finalized": false,
            "finalized_at": NSNull(),
            "max_points": 11,
            "winner_bonus": 0,
            "winner_bonuses_applied": false,
            "winners": [],
            "start_date": Timestamp(date: startDate),
            "end_date": Timestamp(date: endDate),
            "scavenger_hunt": [
                "points_per_item": 1,
                "bonus_item_id": "item10",
                "authenticity_note": "Photos must be real and taken by you. No AI-generated images, no Google screenshots.",
                "items": items
            ],
            "updated_at": FieldValue.serverTimestamp()
        ]
    }
}
