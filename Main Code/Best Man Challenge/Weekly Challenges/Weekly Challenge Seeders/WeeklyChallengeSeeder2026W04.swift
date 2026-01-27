//
//  WeeklyChallengeSeeder2026W04.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/27/26.
//


//
//  WeeklyChallengeSeeder2026W04.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/26/26.
//  Week 4 theme: Movie Trivia (harder, but fair)
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W04 {

    static func seedQuiz() async throws {
        let db = Firestore.firestore()
        let ref = db.collection("weekly_challenges").document("2026_w04")

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

        // Week 4: Movie Trivia (harder but accessible)
        let questions: [[String: Any]] = [
            // Remember the Titans
            makeQuestion(
                id: "q1",
                prompt: "Remember the Titans: Who is appointed as the new head coach of T.C. Williams High School?",
                correct: "Herman Boone",
                wrong: ["Bill Yoast", "Red Pollard", "Tyrell Johnson"]
            ),

            // Wedding Crashers
            makeQuestion(
                id: "q2",
                prompt: "Wedding Crashers: What government job does John Beckwith hold?",
                correct: "Divorce mediator",
                wrong: ["Family court lawyer", "Marriage counselor", "Lobbyist"]
            ),

            // Cars 2
            makeQuestion(
                id: "q3",
                prompt: "Cars 2: What alternative fuel is promoted during the World Grand Prix?",
                correct: "Allinol",
                wrong: ["BioOctane", "Ethanol-X", "EcoFuel"]
            ),

            // Harry Potter 3
            makeQuestion(
                id: "q4",
                prompt: "Harry Potter and the Prisoner of Azkaban: What creature pulls the carriages to Hogwarts?",
                correct: "Thestrals",
                wrong: ["Hippogriffs", "Centaurs", "Grindylows"]
            ),

            // Bull Durham
            makeQuestion(
                id: "q5",
                prompt: "Bull Durham: What minor league team do the characters play for?",
                correct: "Durham Bulls",
                wrong: ["Richmond Braves", "Carolina Mudcats", "Nashville Sounds"]
            ),

            // Moneyball
            makeQuestion(
                id: "q6",
                prompt: "Moneyball: Which statistic does Billy Beane prioritize over batting average?",
                correct: "On-base percentage",
                wrong: ["Slugging percentage", "Runs batted in", "Home runs"]
            ),

            // The Town
            makeQuestion(
                id: "q7",
                prompt: "The Town: The film is primarily set in which Boston neighborhood?",
                correct: "Charlestown",
                wrong: ["South Boston", "Dorchester", "Beacon Hill"]
            ),

            // Pitch Perfect
            makeQuestion(
                id: "q8",
                prompt: "Pitch Perfect: What song do the Barden Bellas perform in the final competition?",
                correct: "Don't You (Forget About Me)",
                wrong: ["Cups", "No Diggity", "Just the Way You Are"]
            ),

            // Friday Night Lights
            makeQuestion(
                id: "q9",
                prompt: "Friday Night Lights: What is the name of the Permian High School football team?",
                correct: "The Panthers",
                wrong: ["The Lions", "The Bulldogs", "The Eagles"]
            ),

            // Miracle
            makeQuestion(
                id: "q10",
                prompt: "Miracle: Who is the head coach of the U.S. Olympic hockey team?",
                correct: "Herb Brooks",
                wrong: ["Mike Eruzione", "Al Michaels", "Scotty Bowman"]
            )
        ]

        // Week 4 window: Mon Jan 26, 2026 → Sun Feb 1, 2026 (ET)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current

        let startDate = cal.date(from: DateComponents(year: 2026, month: 1, day: 26, hour: 0, minute: 0))!
        let endDate   = cal.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 23, minute: 59))!

        let data: [String: Any] = [
            "week": 4,
            "title": "Week 4: Movie Trivia",
            "description": "10-question movie trivia quiz — slightly harder this week. One question per movie. 1 point per correct answer.",
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

        try await ref.setData(data, merge: false)
        print("✅ Seeded weekly_challenges/2026_w04 as harder Movie Trivia quiz (overwritten).")
    }
}
