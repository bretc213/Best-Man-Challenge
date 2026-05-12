//
//  WeeklyChallengeSeeder2026W16.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 4/21/26.
//


//
//  WeeklyChallengeSeeder2026W16.swift
//  Best Man Challenge
//
//  Firestore-backed weekly Wordle seeder for Week 16
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W16 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w16"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()

            if snap.exists {
                print("ℹ️ Week 16 already exists — skipping seed.")
                return
            }

            try await createDocument(ref: ref)
            print("✅ Week 16 created (first-time only).")

        } catch {
            print("❌ seedIfNeeded failed:", error.localizedDescription)
        }
    }

    /// Creates the doc ONLY if it doesn't exist.
    private static func createDocument(ref: DocumentReference) async throws {
        let wordLength = 6
        let maxAttempts = 6
        let answer = "PIXAR"

        let data: [String: Any] = [

            // Core required fields
            "week": 16,
            "title": "Week 16: Wordle",
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
            "weekInt": 16,
            "game_format": "wordle",

            // Wordle rules
            "wordle": [
                "word_length": wordLength,
                "max_attempts": maxAttempts,
                "answer": answer
            ],

            // Optional top-level answer copy if any old logic still reads it
            "answer": answer,

            // Timestamps
            "created_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp()
        ]

        try await ref.setData(data, merge: false)
    }
}