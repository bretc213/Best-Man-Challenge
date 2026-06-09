//
//  WeeklyChallengeSeeder2026W20.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 5/18/26.
//


//
//  WeeklyChallengeSeeder2026W20.swift
//  Best Man Challenge
//
//  Firestore-backed weekly quiz seeder for Week 20
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W20 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w20"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()

            if snap.exists {
                print("ℹ️ Week 20 already exists — skipping seed.")
                return
            }

            try await createDocument(ref: ref)
            print("✅ Week 20 Amanda Quiz created.")
        } catch {
            print("❌ Week 20 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func createDocument(ref: DocumentReference) async throws {
        let data: [String: Any] = [

            "week": 20,
            "weekInt": 20,
            "title": "Week 20: How Well Do You Know Amanda?",
            "description": "Answer 10 fun questions about Amanda. Each correct answer is worth 1 point.",
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
                        "prompt": "What is Amanda’s favorite movie?",
                        "options": ["13 Going on 30", "Forrest Gump", "Princess Diaries", "Encanto"],
                        "correct_index": 1
                    ],
                    [
                        "id": "q2",
                        "prompt": "What is Amanda’s favorite flower?",
                        "options": ["Hydrangeas", "Roses", "Sunflowers", "Tulips"],
                        "correct_index": 0
                    ],
                    [
                        "id": "q3",
                        "prompt": "What is Amanda’s favorite type of food?",
                        "options": ["Italian", "Belizean", "Mexican", "American"],
                        "correct_index": 2
                    ],
                    [
                        "id": "q4",
                        "prompt": "What is Amanda’s go-to drink?",
                        "options": ["Vodka Cran", "Deep Eddy’s Lemonade", "Twisted Tea", "Margarita"],
                        "correct_index": 3
                    ],
                    [
                        "id": "q5",
                        "prompt": "What is Amanda’s go-to fast food spot?",
                        "options": ["Chick-fil-A", "In-N-Out", "McDonald’s", "Taco Bell"],
                        "correct_index": 1
                    ],
                    [
                        "id": "q6",
                        "prompt": "What is Amanda’s favorite type of dessert?",
                        "options": ["Ice Cream", "Brownies", "Tiramisu", "Cheesecake"],
                        "correct_index": 2
                    ],
                    [
                        "id": "q7",
                        "prompt": "What is Amanda’s favorite color?",
                        "options": ["Yellow", "Pink", "Blue", "Burnt Orange"],
                        "correct_index": 0
                    ],
                    [
                        "id": "q8",
                        "prompt": "What is Amanda’s favorite TV show?",
                        "options": ["How I Met Your Mother", "Friends", "Grey’s Anatomy", "The Office"],
                        "correct_index": 1
                    ],
                    [
                        "id": "q9",
                        "prompt": "What does Amanda prefer for a night out?",
                        "options": ["Clubbing", "Dinner and drinks", "Bar hopping", "Concert"],
                        "correct_index": 1
                    ],
                    [
                        "id": "q10",
                        "prompt": "What is Amanda most likely to binge watch?",
                        "options": ["Reality TV", "Crime shows", "Rom-com movies", "Sitcoms"],
                        "correct_index": 2
                    ]
                ]
            ],

            "created_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp()
        ]

        try await ref.setData(data, merge: false)
    }
}