//
//  WeeklyChallengeSeeder2026W28.swift
//  Best Man Challenge
//
//  Week 28: Bret & Amanda Couples Quiz — 10 questions, 1 pt each
//  Dates: Jul 13–19, 2026
//  Uses setData(merge: true) — document already exists as TBD placeholder.
//
//  Mixes trivia about Bret (from W01) and Amanda (from W20).
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W28 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w28"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()
            if snap.exists,
               let title = snap.data()?["title"] as? String,
               !title.contains("TBD") {
                print("ℹ️ W28 already seeded — skipping.")
                return
            }
            try await ref.setData(buildData(), merge: true)
            print("✅ W28 Bret & Amanda Couples Quiz seeded.")
        } catch {
            print("❌ W28 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func buildData() -> [String: Any] {
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 13
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let startDate = calendar.date(from: comps)!
        comps.day = 20
        let endDate = calendar.date(from: comps)!

        return [
            "week": 28,
            "weekInt": 28,
            "title": "Week 28: Bret & Amanda Couples Quiz",
            "description": "How well do you really know the couple? 5 questions about Bret, 5 about Amanda. 1 point per correct answer.",
            "type": "quiz",
            "game_format": "quiz",

            "is_active": false,
            "is_finalized": false,
            "finalized_at": NSNull(),

            "max_points": 10,
            "winner_bonus": 1,
            "winner_bonuses_applied": false,
            "winners": [],

            "start_date": Timestamp(date: startDate),
            "end_date": Timestamp(date: endDate),

            "quiz": [
                "points_per_correct": 1,
                "questions": [
                    // A=0, B=1, C=2, D=3
                    [
                        "id": "q1",
                        "prompt": "What is Bret's favorite movie series?",
                        "options": ["Star Wars", "Harry Potter", "Lord of the Rings", "Indiana Jones"],
                        "correct_index": 1  // B - Harry Potter
                    ],
                    [
                        "id": "q2",
                        "prompt": "What is Amanda's favorite flower?",
                        "options": ["Roses", "Sunflowers", "Hydrangeas", "Tulips"],
                        "correct_index": 2  // C - Hydrangeas
                    ],
                    [
                        "id": "q3",
                        "prompt": "Who is Bret's favorite basketball player of all time?",
                        "options": ["LeBron James", "Michael Jordan", "Kevin Durant", "Kobe Bryant"],
                        "correct_index": 3  // D - Kobe Bryant
                    ],
                    [
                        "id": "q4",
                        "prompt": "What is Amanda's favorite TV show?",
                        "options": ["Grey's Anatomy", "The Office", "Friends", "How I Met Your Mother"],
                        "correct_index": 2  // C - Friends
                    ],
                    [
                        "id": "q5",
                        "prompt": "What was Bret's first job?",
                        "options": ["Crust and Crumble", "In-N-Out", "Big League Dreams", "CSUF DOps"],
                        "correct_index": 2  // C - Big League Dreams
                    ],
                    [
                        "id": "q6",
                        "prompt": "What is Amanda's go-to drink?",
                        "options": ["Vodka Cran", "Deep Eddy's Lemonade", "Twisted Tea", "Margarita"],
                        "correct_index": 3  // D - Margarita
                    ],
                    [
                        "id": "q7",
                        "prompt": "Who is Bret's favorite quarterback of all time?",
                        "options": ["Tom Brady", "Drew Brees", "Aaron Rodgers", "Patrick Mahomes"],
                        "correct_index": 1  // B - Drew Brees
                    ],
                    [
                        "id": "q8",
                        "prompt": "What is Amanda's favorite color?",
                        "options": ["Pink", "Yellow", "Blue", "Burnt Orange"],
                        "correct_index": 1  // B - Yellow
                    ],
                    [
                        "id": "q9",
                        "prompt": "What was Bret's first dog's name?",
                        "options": ["Bambi", "Wentz", "Eleven", "Destiny"],
                        "correct_index": 3  // D - Destiny
                    ],
                    [
                        "id": "q10",
                        "prompt": "What is Amanda's favorite movie?",
                        "options": ["13 Going on 30", "Princess Diaries", "Encanto", "Forrest Gump"],
                        "correct_index": 3  // D - Forrest Gump
                    ]
                ]
            ],

            "updated_at": FieldValue.serverTimestamp()
        ]
    }
}
