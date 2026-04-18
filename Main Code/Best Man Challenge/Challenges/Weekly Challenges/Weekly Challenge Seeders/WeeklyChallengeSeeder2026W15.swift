//
//  WeeklyChallengeSeeder2026W15.swift
//  Best Man Challenge
//
//  Week 15 theme: Bret's Hot Take Sports Quiz
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W15 {

    static func seedIfNeeded() async {
        do {
            let db = Firestore.firestore()
            let ref = db.collection("weekly_challenges").document("2026_w15")

            // Prevent reseeding
            let snap = try await ref.getDocument()
            if snap.exists {
                print("⚠️ Week 15 already exists — skipping seed")
                return
            }

            func makeQuestion(
                id: String,
                prompt: String,
                correct: String,
                wrong: [String]
            ) -> [String: Any] {

                let options = wrong + [correct]
                let correctIndex = options.firstIndex(of: correct) ?? 0

                return [
                    "id": id,
                    "prompt": prompt,
                    "options": options,
                    "correct_index": correctIndex
                ]
            }

            let questions: [[String: Any]] = [

                makeQuestion(
                    id: "q1",
                    prompt: "Who does Bret believe is the greatest basketball player of all time?",
                    correct: "LeBron James",
                    wrong: ["Michael Jordan", "Kobe Bryant", "Stephen Curry"]
                ),

                makeQuestion(
                    id: "q2",
                    prompt: "Which sport does Bret think is the hardest to win a championship in?",
                    correct: "NFL",
                    wrong: ["NBA", "MLB", "NHL"]
                ),

                makeQuestion(
                    id: "q3",
                    prompt: "What does Bret think is the best postseason in sports?",
                    correct: "Stanley Cup Playoffs",
                    wrong: ["March Madness", "NFL Playoffs", "MLB Postseason"]
                ),

                makeQuestion(
                    id: "q4",
                    prompt: "Which sport does Bret think requires the most pure athleticism?",
                    correct: "Football",
                    wrong: ["Basketball", "Baseball", "Hockey"]
                ),

                makeQuestion(
                    id: "q5",
                    prompt: "What does Bret think is the most difficult single skill in sports?",
                    correct: "Shooting a golf major-winning round",
                    wrong: [
                        "Hitting a baseball",
                        "Making a game-winning field goal",
                        "Saving a penalty shot"
                    ]
                ),

                makeQuestion(
                    id: "q6",
                    prompt: "Which moment does Bret think has the highest pressure in sports?",
                    correct: "Bottom 9th bases loaded at-bat",
                    wrong: [
                        "Final putt to win The Masters",
                        "Super Bowl game-winning drive",
                        "Game 7 Stanley Cup overtime"
                    ]
                ),

                makeQuestion(
                    id: "q7",
                    prompt: "Which championship would Bret want the most?",
                    correct: "Masters Green Jacket",
                    wrong: ["Super Bowl", "NBA Championship", "Stanley Cup"]
                ),

                makeQuestion(
                    id: "q8",
                    prompt: "What does Bret think is the most impressive individual achievement in sports?",
                    correct: "Perfect game",
                    wrong: [
                        "Hole-in-one in a major",
                        "Triple-double in NBA Finals",
                        "5-touchdown playoff game"
                    ]
                ),

                makeQuestion(
                    id: "q9",
                    prompt: "Which sport does Bret think would be the hardest to go pro in starting today?",
                    correct: "Football",
                    wrong: ["Golf", "Baseball", "Hockey"]
                ),

                makeQuestion(
                    id: "q10",
                    prompt: "Who would Bret trust most in a must-win game today?",
                    correct: "Patrick Mahomes",
                    wrong: ["LeBron James", "Shohei Ohtani", "Stephen Curry"]
                )
            ]

            // Week 15 dates
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current

            let startDate = cal.date(from: DateComponents(
                year: 2026, month: 4, day: 13, hour: 0, minute: 0
            ))!

            let endDate = cal.date(from: DateComponents(
                year: 2026, month: 4, day: 19, hour: 23, minute: 59
            ))!

            let data: [String: Any] = [
                "week": 15,
                "title": "Week 15: Bret’s Hot Take Sports Quiz",
                "description": "10-question sports hot take quiz. Guess Bret’s answers. Each question is worth 2 points.",
                "type": "quiz",

                "startDate": Timestamp(date: startDate),
                "endDate": Timestamp(date: endDate),

                "is_active": true,

                "quiz": [
                    "points_per_correct": 2,
                    "questions": questions
                ],

                "winner_bonus": 0,
                "winner_bonuses_applied": false,
                "is_finalized": false,
                "winners": [],
                "max_points": 20,
                "finalized_at": NSNull(),

                "updated_at": FieldValue.serverTimestamp()
            ]

            try await ref.setData(data, merge: false)
            print("✅ Seeded weekly_challenges/2026_w15")

        } catch {
            print("❌ Week 15 seed failed:", error.localizedDescription)
        }
    }
}
