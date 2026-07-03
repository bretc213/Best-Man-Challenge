//
//  WeeklyChallengeSeeder2026W29.swift
//  Best Man Challenge
//
//  Week 29: Bret & Amanda Edition Scavenger Hunt
//  Dates: Jul 20–26, 2026
//  10 items × 1 pt each = 10 base pts
//  Item 10 earns +1 bonus pt if BOTH Bret AND Amanda are in the photo
//  Max points: 11
//
//  Admin grades each submission: Valid / Invalid
//  Scores are pending until admin validates.
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
            print("✅ W29 Bret & Amanda Scavenger Hunt seeded.")
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

        let items: [[String: Any]] = [
            ["id": "item1",  "position": 1,  "clue": "A ship and a bottle",                          "emoji": "⚓", "point_value": 1, "bonus_eligible": false],
            ["id": "item2",  "position": 2,  "clue": "The Infinity logo",                            "emoji": "∞", "point_value": 1, "bonus_eligible": false],
            ["id": "item3",  "position": 3,  "clue": "A baseball jersey holding something random",   "emoji": "⚾", "point_value": 1, "bonus_eligible": false],
            ["id": "item4",  "position": 4,  "clue": "Watching your favorite rom-com",               "emoji": "🎬", "point_value": 1, "bonus_eligible": false],
            ["id": "item5",  "position": 5,  "clue": "Photo in a Yankees or Dodgers hat",            "emoji": "🧢", "point_value": 1, "bonus_eligible": false],
            ["id": "item6",  "position": 6,  "clue": "Drinking a Jack in the Box shake",             "emoji": "🥤", "point_value": 1, "bonus_eligible": false],
            ["id": "item7",  "position": 7,  "clue": "Screenshot of your favorite country song playing", "emoji": "🎵", "point_value": 1, "bonus_eligible": false],
            ["id": "item8",  "position": 8,  "clue": "Eating your favorite Mexican food dish",       "emoji": "🌮", "point_value": 1, "bonus_eligible": false],
            ["id": "item9",  "position": 9,  "clue": "Drinking a cup of coffee",                    "emoji": "☕", "point_value": 1, "bonus_eligible": false],
            ["id": "item10", "position": 10, "clue": "Your favorite photo with Bret or Amanda",      "emoji": "💛", "point_value": 1, "bonus_eligible": true,
             "bonus_clue": "+1 bonus point if BOTH Bret AND Amanda are in the photo"]
        ]

        let scavengerHunt: [String: Any] = [
            "points_per_item": 1,
            "bonus_item_id": "item10",
            "authenticity_note": "Photos must be real and taken by you. No AI-generated images, no Google screenshots.",
            "items": items
        ]

        return [
            "week": 29,
            "weekInt": 29,
            "title": "Week 29: Bret & Amanda Edition",
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
            "scavenger_hunt": scavengerHunt,
            "updated_at": FieldValue.serverTimestamp()
        ]
    }
}
