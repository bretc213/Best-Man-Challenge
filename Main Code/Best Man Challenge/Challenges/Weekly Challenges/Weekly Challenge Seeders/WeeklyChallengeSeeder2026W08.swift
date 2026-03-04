//
//  WeeklyChallengeSeeder2026W08.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 2/25/26.
//  Week 8 theme: Him or Her (Bret & Fiancé)
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W08 {

    // ✅ NEW key so it runs even if you seeded something before
    // (device-level guard; Firestore guard below is the real "global" guard)
    static let didSeedKey = "didSeedWeeklyChallenge_2026_w08_him_or_her_v1"

    static func seedIfNeeded() async {
        // Optional device-level guard (keeps logs clean during dev)
        if UserDefaults.standard.bool(forKey: didSeedKey) {
            print("⚠️ Week 8 already seeded on this device — skipping")
            return
        }

        do {
            try await seedQuiz()
            UserDefaults.standard.set(true, forKey: didSeedKey)
        } catch {
            print("❌ Week 8 seed failed: \(error.localizedDescription)")
        }
    }

    static func seedQuiz() async throws {
        let db = Firestore.firestore()
        let ref = db.collection("weekly_challenges").document("2026_w08")

        // 🔒 GLOBAL GUARD — prevents reseeding across ALL devices/builds
        let snap = try await ref.getDocument()
        if snap.exists {
            print("⚠️ Week 8 already exists in Firestore — skipping seed")
            return
        }

        // Helper to build a 2-option (Him/Her) question with FIXED option order
        // ❌ NO SHUFFLE — quiz is immutable once seeded
        func makeHimHerQuestion(
            id: String,
            prompt: String,
            correct: String
        ) -> [String: Any] {

            let options = ["Him", "Her"] // fixed order
            let correctIndex = options.firstIndex(of: correct) ?? 0

            return [
                "id": id,
                "prompt": prompt,
                "options": options,
                "correct_index": correctIndex
            ]
        }

        // Week 8: Him or Her — shuffled to avoid streaky answers
        let questions: [[String: Any]] = [
            makeHimHerQuestion(
                id: "q1",
                prompt: "Who said “I love you” first?",
                correct: "Him"
            ),
            makeHimHerQuestion(
                id: "q2",
                prompt: "Who knew it was serious first?",
                correct: "Her"
            ),
            makeHimHerQuestion(
                id: "q3",
                prompt: "Who watches the baby more?",
                correct: "Him"
            ),
            makeHimHerQuestion(
                id: "q4",
                prompt: "Who is more stubborn?",
                correct: "Her"
            ),
            makeHimHerQuestion(
                id: "q5",
                prompt: "Who has more screen time?",
                correct: "Him"
            ),
            makeHimHerQuestion(
                id: "q6",
                prompt: "Who does more of the cooking?",
                correct: "Her"
            ),
            makeHimHerQuestion(
                id: "q7",
                prompt: "Who is more likely to say “we don’t need that”?",
                correct: "Him"
            ),
            makeHimHerQuestion(
                id: "q8",
                prompt: "Who texts back faster?",
                correct: "Her"
            ),
            makeHimHerQuestion(
                id: "q9",
                prompt: "Who made the first move?",
                correct: "Him"
            ),
            makeHimHerQuestion(
                id: "q10",
                prompt: "Who is more likely to fall asleep first?",
                correct: "Her"
            )
        ]

        // Week 8 window: Mon Feb 23, 2026 → Sun Mar 1, 2026 (ET)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current

        let startDate = cal.date(from: DateComponents(
            year: 2026, month: 2, day: 23, hour: 0, minute: 0
        ))!

        let endDate = cal.date(from: DateComponents(
            year: 2026, month: 3, day: 1, hour: 23, minute: 59
        ))!

        let data: [String: Any] = [
            "week": 8,
            "title": "Week 8: Him or Her",
            "description": "10-question Him or Her quiz about Bret & his fiancé. 1 point per correct answer.",
            "type": "quiz",

            "startDate": Timestamp(date: startDate),
            "endDate": Timestamp(date: endDate),

            "is_active": true,

            "quiz": [
                "points_per_correct": 1,
                "questions": questions
            ],

            // Winner bonus scaffolding
            "winner_bonus": 1,
            "winner_bonuses_applied": false,
            "is_finalized": false,
            "winners": [],
            "max_points": NSNull(),
            "finalized_at": NSNull(),

            "updated_at": FieldValue.serverTimestamp()
        ]

        // ❗ Safe because we guarded above
        try await ref.setData(data, merge: false)
        print("✅ Seeded weekly_challenges/2026_w08 (immutable, fixed option order Him/Her).")
    }
}
