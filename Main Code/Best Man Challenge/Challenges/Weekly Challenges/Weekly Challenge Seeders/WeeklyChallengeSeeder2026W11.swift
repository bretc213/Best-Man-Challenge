//
//  WeeklyChallengeSeeder2026W11.swift
//  Best Man Challenge
//
//  Week 11: Name That Pixar Character
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W11 {

    static let didSeedKey = "didSeedWeeklyChallenge_2026_w11_pixar_image_quiz_v1"

    static func seedIfNeeded() async {
        if UserDefaults.standard.bool(forKey: didSeedKey) {
            print("⚠️ Week 11 already seeded on this device — skipping")
            return
        }

        do {
            try await seedQuiz()
            UserDefaults.standard.set(true, forKey: didSeedKey)
        } catch {
            print("❌ Week 11 seed failed: \(error.localizedDescription)")
        }
    }

    static func seedQuiz() async throws {
        let db = Firestore.firestore()
        let ref = db.collection("weekly_challenges").document("2026_w11")

        let snap = try await ref.getDocument()
        if snap.exists {
            print("⚠️ Week 11 already exists in Firestore — skipping seed")
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
                "prompt": "Name this Pixar character",
                "image_name": imageName,
                "answer": answer.lowercased(),
                "acceptable_answers": acceptableAnswers.map { $0.lowercased() },
                "allow_fuzzy_match": allowFuzzyMatch,
                "fuzzy_distance": fuzzyDistance
            ]
        }

        let questions: [[String: Any]] = [
            makeImageQuestion(id: "q1", imageName: "woody", answer: "Woody", acceptableAnswers: ["Woody"]),
            makeImageQuestion(id: "q2", imageName: "buzz_lightyear", answer: "Buzz Lightyear", acceptableAnswers: ["Buzz", "Buzz Lightyear"]),
            makeImageQuestion(id: "q3", imageName: "lightning_mcqueen", answer: "Lightning McQueen", acceptableAnswers: ["McQueen", "Lightning", "Lightning McQueen"]),
            makeImageQuestion(id: "q4", imageName: "nemo", answer: "Nemo", acceptableAnswers: ["Nemo"]),
            makeImageQuestion(id: "q5", imageName: "dory", answer: "Dory", acceptableAnswers: ["Dory"]),
            makeImageQuestion(id: "q6", imageName: "sully", answer: "Sully", acceptableAnswers: ["Sully", "James P Sullivan", "James Sullivan"]),
            makeImageQuestion(id: "q7", imageName: "mike_wazowski", answer: "Mike Wazowski", acceptableAnswers: ["Mike", "Mike Wazowski"]),
            makeImageQuestion(id: "q8", imageName: "remy", answer: "Remy", acceptableAnswers: ["Remy"]),
            makeImageQuestion(id: "q9", imageName: "wall_e", answer: "WALL-E", acceptableAnswers: ["Wall-E", "Wall E", "Walle", "WALL-E"]),
            makeImageQuestion(id: "q10", imageName: "joy", answer: "Joy", acceptableAnswers: ["Joy"])
        ]

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current

        let startDate = cal.date(from: DateComponents(
            year: 2026, month: 3, day: 16, hour: 0, minute: 0
        ))!

        let endDate = cal.date(from: DateComponents(
            year: 2026, month: 3, day: 22, hour: 23, minute: 59
        ))!

        let rules: [String] = [
            "You will see 10 Pixar character images.",
            "Type the name of each character.",
            "Small typos may still be accepted.",
            "Some common shortened answers are also accepted.",
            "Each correct answer is worth 1 point.",
            "Highest score wins the weekly challenge bonus."
        ]

        let data: [String: Any] = [
            "week": 11,
            "title": "Week 11: Name That Pixar Character",
            "description": "Identify the Pixar character from each image. 1 point per correct answer.",
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
        print("✅ Seeded weekly_challenges/2026_w11 (Pixar image quiz).")
    }
}
