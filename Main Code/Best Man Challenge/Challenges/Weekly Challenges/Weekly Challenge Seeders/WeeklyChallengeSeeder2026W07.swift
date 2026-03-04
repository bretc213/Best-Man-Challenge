//
//  WeeklyChallengeSeeder2026W07.swift
//  Best Man Challenge
//
//  FUTURE-PROOF VERSION
//  Firestore is source of truth for dates + answers.
//  This seeder only creates the document if it does NOT exist.
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W07 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w07"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()

            if snap.exists {
                print("ℹ️ Week 7 already exists — skipping seed.")
                return
            }

            try await createDocument(ref: ref)
            print("✅ Week 7 created (first-time only).")

        } catch {
            print("❌ seedIfNeeded failed:", error.localizedDescription)
        }
    }

    /// Creates the doc ONLY if it doesn't exist.
    /// DOES NOT include startDate / endDate / locksAt / answer fields.
    /// Those are now controlled entirely in Firestore.
    private static func createDocument(ref: DocumentReference) async throws {

        let wordLength = 5
        let maxAttempts = 6

        let data: [String: Any] = [

            // Core required fields
            "week": 7,
            "title": "Week 7: Wordle",
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
            "weekInt": 7,
            "game_format": "wordle",

            // Wordle rules only (NO answer seeded)
            "wordle": [
                "word_length": wordLength,
                "max_attempts": maxAttempts
            ],

            // Timestamps
            "created_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp()
        ]

        // SAFE CREATE:
        // This will fail if the document already exists.
        try await ref.setData(data, merge: false)
    }
}
