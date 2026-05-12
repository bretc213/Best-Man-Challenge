//
//  WeeklyChallengeSeeder2026W17.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 4/27/26.
//


//
//  WeeklyChallengeSeeder2026W17.swift
//  Best Man Challenge
//
//  Firestore-backed weekly quiz seeder for Week 17
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W17 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w17"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()

            if snap.exists {
                print("ℹ️ Week 17 already exists — skipping seed.")
                return
            }

            try await createDocument(ref: ref)
            print("✅ Week 17 Country Music Quiz created.")
        } catch {
            print("❌ Week 17 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func createDocument(ref: DocumentReference) async throws {
        let data: [String: Any] = [

            "week": 17,
            "weekInt": 17,
            "title": "Week 17: Country Music Quiz",
            "description": "Test your country music knowledge with lyrics, artists, and hit songs.",
            "type": "quiz",
            "game_format": "quiz",

            "is_active": true,
            "is_finalized": false,
            "finalized_at": NSNull(),

            "max_points": 20,
            "winner_bonus": 1,
            "winner_bonuses_applied": false,
            "winners": [],

            "quiz": [
                "points_per_correct": 2,
                "questions": [
                    [
                        "id": "q1",
                        "prompt": "Fill in the lyric: “Cause I’m a ___ boy, I ain’t got no choice”",
                        "options": ["Red dirt", "Backwoods", "Ramblin’", "Southern"],
                        "correct_index": 2
                    ],
                    [
                        "id": "q2",
                        "prompt": "What artist sings “Tennessee Whiskey”?",
                        "options": ["Chris Stapleton", "Luke Combs", "Eric Church", "Jason Aldean"],
                        "correct_index": 0
                    ],
                    [
                        "id": "q3",
                        "prompt": "Which song is by Luke Combs?",
                        "options": ["Sand in My Boots", "Beer Never Broke My Heart", "Body Like a Back Road", "Cruise"],
                        "correct_index": 1
                    ],
                    [
                        "id": "q4",
                        "prompt": "Fill in the lyric: “I got friends in low ___”",
                        "options": ["Roads", "Places", "Bars", "Towns"],
                        "correct_index": 1
                    ],
                    [
                        "id": "q5",
                        "prompt": "What artist sings “Body Like a Back Road”?",
                        "options": ["Morgan Wallen", "Sam Hunt", "Thomas Rhett", "Kane Brown"],
                        "correct_index": 1
                    ],
                    [
                        "id": "q6",
                        "prompt": "Which song is by Morgan Wallen?",
                        "options": ["Last Night", "Wagon Wheel", "Die a Happy Man", "Hurricane"],
                        "correct_index": 0
                    ],
                    [
                        "id": "q7",
                        "prompt": "Fill in the lyric: “Take me home, country ___”",
                        "options": ["Girl", "Roads", "Life", "Nights"],
                        "correct_index": 1
                    ],
                    [
                        "id": "q8",
                        "prompt": "What artist sings “Chicken Fried”?",
                        "options": ["Zac Brown Band", "Dierks Bentley", "Blake Shelton", "Brad Paisley"],
                        "correct_index": 0
                    ],
                    [
                        "id": "q9",
                        "prompt": "Which song is by George Strait?",
                        "options": ["Humble and Kind", "Amarillo By Morning", "Buy Dirt", "You Proof"],
                        "correct_index": 1
                    ],
                    [
                        "id": "q10",
                        "prompt": "Fill in the lyric: “Save a horse, ride a ___”",
                        "options": ["Cowboy", "Truck", "Saddle", "Bull"],
                        "correct_index": 0
                    ]
                ]
            ],

            "created_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp()
        ]

        try await ref.setData(data, merge: false)
    }
}