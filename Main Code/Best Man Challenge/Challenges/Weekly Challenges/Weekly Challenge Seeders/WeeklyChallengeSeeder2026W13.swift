//
//  WeeklyChallengeSeeder2026W13.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 3/30/26.
//


//
//  WeeklyChallengeSeeder2026W13.swift
//  Best Man Challenge
//
//  Week 13: Name That City - Famous Bridges
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W13 {

    static let didSeedKey = "didSeedWeeklyChallenge_2026_w13_bridges_image_quiz_v1"

    static func seedIfNeeded() async {
        if UserDefaults.standard.bool(forKey: didSeedKey) {
            print("⚠️ Week 13 already seeded on this device — skipping")
            return
        }

        do {
            try await seedQuiz()
            UserDefaults.standard.set(true, forKey: didSeedKey)
        } catch {
            print("❌ Week 13 seed failed: \(error.localizedDescription)")
        }
    }

    static func seedQuiz() async throws {
        let db = Firestore.firestore()
        let ref = db.collection("weekly_challenges").document("2026_w13")

        let snap = try await ref.getDocument()
        if snap.exists {
            print("⚠️ Week 13 already exists in Firestore — skipping seed")
            return
        }

        func makeImageQuestion(
            id: String,
            imageName: String,
            answer: String,
            acceptableAnswers: [String],
            allowFuzzyMatch: Bool = true,
            fuzzyDistance: Int = 2
        ) -> [String: Any] {
            [
                "id": id,
                "prompt": "Name the city for this famous bridge",
                "image_name": imageName,
                "answer": answer.lowercased(),
                "acceptable_answers": acceptableAnswers.map { $0.lowercased() },
                "allow_fuzzy_match": allowFuzzyMatch,
                "fuzzy_distance": fuzzyDistance
            ]
        }

        let questions: [[String: Any]] = [
            makeImageQuestion(
                id: "q1",
                imageName: "bixby_bridge",
                answer: "Big Sur",
                acceptableAnswers: ["Big Sur"]
            ),
            makeImageQuestion(
                id: "q2",
                imageName: "florence_bridge",
                answer: "Florence",
                acceptableAnswers: ["Florence"]
            ),
            makeImageQuestion(
                id: "q3",
                imageName: "kobe_bridge",
                answer: "Kobe",
                acceptableAnswers: ["Kobe"]
            ),
            makeImageQuestion(
                id: "q4",
                imageName: "london_bridge",
                answer: "London",
                acceptableAnswers: ["London"]
            ),
            makeImageQuestion(
                id: "q5",
                imageName: "nyc_bridge",
                answer: "New York City",
                acceptableAnswers: ["New York City", "New York", "NYC"]
            ),
            makeImageQuestion(
                id: "q6",
                imageName: "paris_bridge",
                answer: "Paris",
                acceptableAnswers: ["Paris"]
            ),
            makeImageQuestion(
                id: "q7",
                imageName: "prague_bridge",
                answer: "Prague",
                acceptableAnswers: ["Prague"]
            ),
            makeImageQuestion(
                id: "q8",
                imageName: "san_francisco_bridge",
                answer: "San Francisco",
                acceptableAnswers: ["San Francisco", "SF"]
            ),
            makeImageQuestion(
                id: "q9",
                imageName: "sydney_bridge",
                answer: "Sydney",
                acceptableAnswers: ["Sydney"]
            ),
            makeImageQuestion(
                id: "q10",
                imageName: "venice_bridge",
                answer: "Venice",
                acceptableAnswers: ["Venice"]
            )
        ]

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .current

        let startDate = cal.date(from: DateComponents(
            year: 2026, month: 3, day: 30, hour: 0, minute: 0
        ))!

        let endDate = cal.date(from: DateComponents(
            year: 2026, month: 4, day: 5, hour: 23, minute: 59
        ))!

        let rules: [String] = [
            "You will see 10 famous bridge images.",
            "Type the city where each bridge is located.",
            "Small typos may still be accepted.",
            "Some common alternate answers are also accepted.",
            "Each correct answer is worth 1 point.",
            "Highest score wins the weekly challenge bonus."
        ]

        let data: [String: Any] = [
            "week": 13,
            "title": "Week 13: Name That City - Famous Bridges",
            "description": "Identify the city for each famous bridge. 1 point per correct answer.",
            "rules": rules,
            "type": "image_quiz",

            "startDate": Timestamp(date: startDate),
            "endDate": Timestamp(date: endDate),

            "is_active": true,
            "is_finalized": false,
            "finalized_at": NSNull(),
            "max_points": NSNull(),

            "quiz": [
                "points_per_correct": 1,
                "questions": questions
            ],

            "winner_bonus": 1,
            "winner_bonuses_applied": false,
            "winners": [],
            "updated_at": FieldValue.serverTimestamp()
        ]

        try await ref.setData(data, merge: false)
        print("✅ Seeded weekly_challenges/2026_w13 (Bridges image quiz).")
    }
}
