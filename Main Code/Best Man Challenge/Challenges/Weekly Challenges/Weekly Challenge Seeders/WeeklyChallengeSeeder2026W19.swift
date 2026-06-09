//
//  WeeklyChallengeSeeder2026W19.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 5/13/26.
//


//
//  WeeklyChallengeSeeder2026W19.swift
//  Best Man Challenge
//
//  Week 19 Wordle Seeder
//  Includes answer = "SWIPE"
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W19 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w19"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()

            if snap.exists {
                print("ℹ️ Week 19 already exists — skipping seed.")
                return
            }

            try await createDocument(ref: ref)
            print("✅ Week 19 created (first-time only).")

        } catch {
            print("❌ seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func createDocument(ref: DocumentReference) async throws {

        let wordLength = 5
        let maxAttempts = 6
        let answer = "SWIPE"

        let data: [String: Any] = [

            // Core required fields
            "week": 19,
            "title": "Week 19: Wordle",
            "description": "Guess the weekly \(wordLength)-letter word in \(maxAttempts) tries.",
            "type": "wordle",

            // Lifecycle defaults
            "is_active": true,
            "is_finalized": false,
            "finalized_at": NSNull(),

            // Scoring defaults
            "max_points": NSNull(),
            "winner_bonus": 1,
            "winner_bonuses_applied": false,
            "winners": [],

            // Compatibility helpers
            "weekInt": 19,
            "game_format": "wordle",

            // Wordle config (NOW includes answer)
            "wordle": [
                "word_length": wordLength,
                "max_attempts": maxAttempts,
                "answer": answer.lowercased() // keep consistent with your engine if needed
            ],

            // Timestamps
            "created_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp()
        ]

        try await ref.setData(data, merge: false)
    }
}