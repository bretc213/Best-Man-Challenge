//
//  WeeklyChallengeSeeder2026W03.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/19/26.
//


//
//  WeeklyChallengeSeeder2026W03.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/19/26.
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W03 {

    static func seedQuiz() async throws {
        let db = Firestore.firestore()
        let ref = db.collection("weekly_challenges").document("2026_w03")

        // Helper to build a question with shuffled options while keeping correct_index accurate
        func makeQuestion(id: String, prompt: String, correct: String, wrong: [String]) -> [String: Any] {
            var options = wrong + [correct]
            options.shuffle()
            let correctIndex = options.firstIndex(of: correct) ?? 0

            return [
                "id": id,
                "prompt": prompt,
                "options": options,
                "correct_index": correctIndex
            ]
        }

        // C-BEST-ish: fast, objective, mixed difficulty
        let questions: [[String: Any]] = [
            makeQuestion(
                id: "q1",
                prompt: "Math: What is 15% of 240?",
                correct: "36",
                wrong: ["24", "48", "60"]
            ),
            makeQuestion(
                id: "q2",
                prompt: "Science: What is the chemical symbol for gold?",
                correct: "Au",
                wrong: ["Ag", "Gd", "Go"]
            ),
            makeQuestion(
                id: "q3",
                prompt: "History: The Magna Carta was signed in which country?",
                correct: "England",
                wrong: ["France", "Spain", "Italy"]
            ),
            makeQuestion(
                id: "q4",
                prompt: "Math: A train travels 180 miles in 3 hours. What is its average speed?",
                correct: "60 mph",
                wrong: ["45 mph", "50 mph", "90 mph"]
            ),
            makeQuestion(
                id: "q5",
                prompt: "Science: Which planet is known for its prominent rings?",
                correct: "Saturn",
                wrong: ["Mars", "Venus", "Mercury"]
            ),
            makeQuestion(
                id: "q6",
                prompt: "Civics: How many amendments are in the U.S. Constitution?",
                correct: "27",
                wrong: ["10", "21", "33"]
            ),
            makeQuestion(
                id: "q7",
                prompt: "Math: Solve 7^2 - 5^2.",
                correct: "24",
                wrong: ["12", "20", "49"]
            ),
            makeQuestion(
                id: "q8",
                prompt: "Science: DNA stands for what?",
                correct: "Deoxyribonucleic acid",
                wrong: ["Dinitrogen acid", "Dynamic nuclear array", "Deoxygenated nitrogen atom"]
            ),
            makeQuestion(
                id: "q9",
                prompt: "Geography: What is the largest ocean on Earth?",
                correct: "Pacific Ocean",
                wrong: ["Atlantic Ocean", "Indian Ocean", "Arctic Ocean"]
            ),
            makeQuestion(
                id: "q10",
                prompt: "Science: What is the process by which plants make food using sunlight?",
                correct: "Photosynthesis",
                wrong: ["Respiration", "Fermentation", "Condensation"]
            )
        ]

        // Required by your loader:
        // week(Int), title(String), description(String), type(String),
        // startDate(Timestamp), endDate(Timestamp)

        // ✅ Put reasonable dates for Week 3.
        // If you prefer: just copy your Week 1 pattern and update week/start/end.
        //
        // NOTE: These example timestamps are placeholders.
        // Change to your actual desired week window.
        let start = Timestamp(date: Date(timeIntervalSince1970: 1736928000)) // example
        let end   = Timestamp(date: Date(timeIntervalSince1970: 1737532800)) // example (+7 days)

        let data: [String: Any] = [
            "week": 3,
            "title": "Week 3: Timed General Knowledge",
            "description": "10-question timed quiz (5 minutes) across math, science, history, and civics. 1 point per correct answer.",
            "type": "quiz",
            "startDate": start,
            "endDate": end,

            "is_active": true,

            "quiz": [
                "points_per_correct": 1,
                "questions": questions
            ],

            // Winner bonus scaffolding fields (safe to include even if already merged in Step 1)
            "winner_bonus": 1,
            "winner_bonuses_applied": false,
            "is_finalized": false,
            "winners": [],
            "max_points": NSNull(),
            "finalized_at": NSNull(),

            "updated_at": FieldValue.serverTimestamp()
        ]

        // 🔥 Overwrite entire doc (same as Week 1 approach)
        // This will replace any prior quiz content for 2026_w03.
        try await ref.setData(data, merge: false)
        print("✅ Seeded weekly_challenges/2026_w03 as timed general knowledge quiz (overwritten).")
    }
}
