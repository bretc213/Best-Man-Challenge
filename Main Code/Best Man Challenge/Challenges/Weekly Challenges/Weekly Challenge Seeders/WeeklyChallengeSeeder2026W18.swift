//
//  WeeklyChallengeSeeder2026W18.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 5/4/26.
//


//
//  WeeklyChallengeSeeder2026W18.swift
//  Best Man Challenge
//
//  Firestore-backed weekly quiz seeder for Week 18
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W18 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w18"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()

            if snap.exists {
                print("ℹ️ Week 18 already exists — skipping seed.")
                return
            }

            try await createDocument(ref: ref)
            print("✅ Week 18 Yankees Quiz created.")
        } catch {
            print("❌ Week 18 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func createDocument(ref: DocumentReference) async throws {
        let data: [String: Any] = [

            "week": 18,
            "weekInt": 18,
            "title": "Week 18: Yankees Quiz",
            "description": "Test your Yankees knowledge with a mix of easy, medium, and real fan questions.",
            "type": "quiz",
            "game_format": "quiz",

            "is_active": true,
            "is_finalized": false,
            "finalized_at": NSNull(),

            "max_points": 10,
            "winner_bonus": 1,
            "winner_bonuses_applied": false,
            "winners": [],

            "quiz": [
                "points_per_correct": 1,
                "questions": [
                    [
                        "id": "q1",
                        "prompt": "How many World Series have the Yankees won?",
                        "options": ["27", "25", "28", "26"],
                        "correct_index": 0
                    ],
                    [
                        "id": "q2",
                        "prompt": "Who is the Yankees’ all-time home run leader?",
                        "options": ["Mickey Mantle", "Babe Ruth", "Lou Gehrig", "Joe DiMaggio"],
                        "correct_index": 1
                    ],
                    [
                        "id": "q3",
                        "prompt": "What year did the Yankees last win the World Series?",
                        "options": ["2007", "2010", "2008", "2009"],
                        "correct_index": 3
                    ],
                    [
                        "id": "q4",
                        "prompt": "Which Yankees pitcher threw a perfect game in 1999?",
                        "options": ["Roger Clemens", "Mariano Rivera", "David Cone", "Andy Pettitte"],
                        "correct_index": 2
                    ],
                    [
                        "id": "q5",
                        "prompt": "Who hit the famous “Mr. November” walk-off home run in the 2001 World Series?",
                        "options": ["Scott Brosius", "Tino Martinez", "Bernie Williams", "Derek Jeter"],
                        "correct_index": 3
                    ],
                    [
                        "id": "q6",
                        "prompt": "Who was the Yankees’ manager during the 1996–2000 dynasty?",
                        "options": ["Joe Torre", "Joe Girardi", "Buck Showalter", "Don Mattingly"],
                        "correct_index": 0
                    ],
                    [
                        "id": "q7",
                        "prompt": "Which Yankees player won the 2022 AL MVP?",
                        "options": ["Giancarlo Stanton", "Aaron Judge", "Anthony Rizzo", "Gleyber Torres"],
                        "correct_index": 1
                    ],
                    [
                        "id": "q8",
                        "prompt": "What number did Mariano Rivera wear?",
                        "options": ["34", "40", "46", "42"],
                        "correct_index": 3
                    ],
                    [
                        "id": "q9",
                        "prompt": "Which Yankees player had a 56-game hitting streak?",
                        "options": ["Joe DiMaggio", "Babe Ruth", "Mickey Mantle", "Lou Gehrig"],
                        "correct_index": 0
                    ],
                    [
                        "id": "q10",
                        "prompt": "Which team did the Yankees defeat in the 2009 World Series?",
                        "options": ["Los Angeles Dodgers", "Philadelphia Phillies", "Boston Red Sox", "New York Mets"],
                        "correct_index": 1
                    ]
                ]
            ],

            "created_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp()
        ]

        try await ref.setData(data, merge: false)
    }
}