//
//  WeeklyChallengeSeeder2026W07.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 2/16/26.
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W07 {

    // ✅ NEW key so it runs even if you seeded something before
    static let didSeedKey = "didSeedWeeklyChallenge_2026_w07_wordle_required_fields_v1"

    static func seedIfNeeded() async {
        if UserDefaults.standard.bool(forKey: didSeedKey) {
            print("ℹ️ Week 7 already seeded (UserDefaults).")
            return
        }

        do {
            try await seed()
            UserDefaults.standard.set(true, forKey: didSeedKey)
            print("✅ Week 7 seeded and flag saved.")
        } catch {
            print("❌ Week 7 seed failed:", error.localizedDescription)
        }
    }

    private static func seed() async throws {
        let db = Firestore.firestore()

        let challengeId = "2026_w07"
        let challengeRef = db.collection("weekly_challenges").document(challengeId)

        // ✅ Dates (LA timezone)
        let startDate = makeTimestampLA(year: 2026, month: 2, day: 16, hour: 0, minute: 0)
        let endDate   = makeTimestampLA(year: 2026, month: 2, day: 22, hour: 23, minute: 59)

        // 🔒 Wordle locks Wed 12:00am (you can adjust)
        let locksAt   = makeTimestampLA(year: 2026, month: 2, day: 18, hour: 0, minute: 0)

        // ✅ Wordle config
        let wordLength = 5
        let maxAttempts = 6

        // ✅ REQUIRED fields guaranteed (correct types, never missing)
        // NOTE: merge: false below ensures these fields truly exist on the doc
        let challengeData: [String: Any] = [
            // ---- Core fields (your screenshot contract) ----
            "week": 7, // Int
            "title": "Week 7: Wordle", // String
            "description": "Guess the weekly \(wordLength)-letter word in \(maxAttempts) tries. Admin will post the word when ready.", // String
            "type": "wordle", // String (must match ChallengeType decoding if applicable)

            "startDate": startDate, // Timestamp
            "endDate": endDate,     // Timestamp

            // ✅ keep answer present for ALL challenges (null here; wordle uses nested wordle.answer too)
            "answer": NSNull(),

            // ---- Lifecycle fields ----
            "is_active": true,
            "is_finalized": false,
            "finalized_at": NSNull(),

            // ---- Scoring/winners fields (present for ALL challenges) ----
            "max_points": NSNull(),              // leave null unless you need it
            "winner_bonus": 1,
            "winner_bonuses_applied": false,
            "winners": [],

            // ---- Locking (used by multiple challenge types) ----
            "locksAt": locksAt,

            // ---- Optional compatibility helper (harmless) ----
            "weekInt": 7,

            // ---- ✅ Wordle extras ----
            "game_format": "wordle",
            "wordle": [
                "word_length": wordLength,
                "max_attempts": maxAttempts,

                // ✅ blank at seed time; admin fills later
                // Use "" (string) here so your UI can treat empty as "not ready"
                "answer": ""
            ],

            // ---- Timestamps ----
            "created_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp()
        ]

        let batch = db.batch()

        // 🔥 Overwrite the doc so required fields definitely exist + correctly typed
        batch.setData(challengeData, forDocument: challengeRef, merge: false)

        // Deactivate other active weekly challenges
        let activeSnap = try await db.collection("weekly_challenges")
            .whereField("is_active", isEqualTo: true)
            .getDocuments()

        for d in activeSnap.documents where d.documentID != challengeId {
            batch.setData(["is_active": false], forDocument: d.reference, merge: true)
        }

        try await batch.commit()
        print("✅ Seeded weekly_challenges/\(challengeId) with required fields + Wordle extras.")
    }

    private static func makeTimestampLA(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Timestamp {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let comps = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        let date = cal.date(from: comps) ?? Date()
        return Timestamp(date: date)
    }
}
