//
//  WeeklyChallengeSeeder2026W23.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 6/8/26.
//


//
//  WeeklyChallengeSeeder2026W23.swift
//  Best Man Challenge
//
//  Firestore-backed weekly quiz seeder for Week 23
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W23 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w23"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()

            if snap.exists {
                print("ℹ️ Week 23 already exists — skipping seed.")
                return
            }

            try await createDocument(ref: ref)
            print("✅ Week 23 Nicholas Sparks Quiz created.")
        } catch {
            print("❌ Week 23 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func createDocument(ref: DocumentReference) async throws {
        let data: [String: Any] = [

            "week": 23,
            "weekInt": 23,
            "title": "Week 23: Nicholas Sparks Movie Trivia",
            "description": "Think you know your rom-coms? Test your knowledge of Nicholas Sparks movies. Each correct answer is worth 1 point.",
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
                        "prompt": "In 'The Notebook,' what are the names of the two main characters?",
                        "options": ["Noah & Allie", "Jake & Rachel", "John & Savannah", "Luke & Sophia"],
                        "correct_index": 0
                    ],
                    [
                        "id": "q2",
                        "prompt": "In 'A Walk to Remember,' what illness does Jamie Sullivan have?",
                        "options": ["Cancer", "Leukemia", "Lupus", "MS"],
                        "correct_index": 1
                    ],
                    [
                        "id": "q3",
                        "prompt": "Which actor played Noah Calhoun in 'The Notebook'?",
                        "options": ["Channing Tatum", "Ryan Gosling", "Zac Efron", "Josh Duhamel"],
                        "correct_index": 1
                    ],
                    [
                        "id": "q4",
                        "prompt": "In 'Dear John,' what branch of the military does John serve in?",
                        "options": ["Navy", "Army", "Marines", "Air Force"],
                        "correct_index": 1
                    ],
                    [
                        "id": "q5",
                        "prompt": "In 'The Lucky One,' Zac Efron's character Logan is a veteran of which conflict?",
                        "options": ["Vietnam", "Gulf War", "Iraq War", "Afghanistan"],
                        "correct_index": 2
                    ],
                    [
                        "id": "q6",
                        "prompt": "In 'Nights in Rodanthe,' where does the couple fall in love?",
                        "options": ["A lighthouse", "A beachfront inn", "A mountain cabin", "A vineyard"],
                        "correct_index": 1
                    ],
                    [
                        "id": "q7",
                        "prompt": "Which Nicholas Sparks movie features a bull rider as the male lead?",
                        "options": ["Safe Haven", "The Choice", "The Longest Ride", "The Best of Me"],
                        "correct_index": 2
                    ],
                    [
                        "id": "q8",
                        "prompt": "In 'The Last Song,' which pop star played the female lead?",
                        "options": ["Selena Gomez", "Demi Lovato", "Miley Cyrus", "Taylor Swift"],
                        "correct_index": 2
                    ],
                    [
                        "id": "q9",
                        "prompt": "Which actress starred alongside Ryan Gosling in 'The Notebook'?",
                        "options": ["Amanda Seyfried", "Rachel McAdams", "Julianne Hough", "Mandy Moore"],
                        "correct_index": 1
                    ],
                    [
                        "id": "q10",
                        "prompt": "In 'Safe Haven,' what is the main character Katie hiding from?",
                        "options": ["A stalker", "Witness protection", "An abusive cop husband", "A dangerous cult"],
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
