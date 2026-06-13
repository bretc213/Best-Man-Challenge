//
//  WeeklyChallengeSeeder2026W24.swift
//  Best Man Challenge
//
//  Week 24: World Cup History Quiz — 10 questions, 1 pt each
//  Dates: Jun 15–21, 2026
//  Uses setData(merge: true) — document already exists as TBD placeholder.
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W24 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w24"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()
            if snap.exists,
               let title = snap.data()?["title"] as? String,
               !title.contains("TBD") {
                print("ℹ️ W24 already seeded — skipping.")
                return
            }
            try await ref.setData(buildData(), merge: true)
            print("✅ W24 World Cup History Quiz seeded.")
        } catch {
            print("❌ W24 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func buildData() -> [String: Any] {
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 15
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let startDate = calendar.date(from: comps)!
        comps.day = 22
        let endDate = calendar.date(from: comps)!

        return [
            "week": 24,
            "weekInt": 24,
            "title": "Week 24: World Cup History Quiz",
            "description": "The World Cup group stage is live — how well do you know your World Cup history? 10 questions, 1 point each.",
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
                    // A=0, B=1, C=2, D=3  |  Distribution: A×3, B×3, C×2, D×2
                    [
                        "id": "q1",
                        "prompt": "Which country has won the most FIFA World Cups?",
                        "options": ["Germany", "Brazil", "Italy", "Argentina"],
                        "correct_index": 1  // B - Brazil
                    ],
                    [
                        "id": "q2",
                        "prompt": "Who scored the most goals in a single World Cup tournament (13 goals in 1958)?",
                        "options": ["Just Fontaine", "Pelé", "Gerd Müller", "Ronaldo"],
                        "correct_index": 0  // A - Just Fontaine
                    ],
                    [
                        "id": "q3",
                        "prompt": "What country hosted the very first FIFA World Cup in 1930?",
                        "options": ["Uruguay", "Brazil", "France", "England"],
                        "correct_index": 0  // A - Uruguay
                    ],
                    [
                        "id": "q4",
                        "prompt": "Which player is famous for the 'Hand of God' goal?",
                        "options": ["Pelé", "Diego Maradona", "Zinedine Zidane", "Ronaldo"],
                        "correct_index": 1  // B - Diego Maradona
                    ],
                    [
                        "id": "q5",
                        "prompt": "Besides 2026, what other year did the USA host the World Cup?",
                        "options": ["1990", "1994", "1998", "2002"],
                        "correct_index": 1  // B - 1994
                    ],
                    [
                        "id": "q6",
                        "prompt": "Which country won the 2022 FIFA World Cup in Qatar?",
                        "options": ["France", "England", "Argentina", "Brazil"],
                        "correct_index": 2  // C - Argentina
                    ],
                    [
                        "id": "q7",
                        "prompt": "How many teams advance to the knockout round in the expanded 2026 World Cup format?",
                        "options": ["24", "28", "36", "32"],
                        "correct_index": 3  // D - 32
                    ],
                    [
                        "id": "q8",
                        "prompt": "Who holds the all-time record for most career World Cup goals with 16?",
                        "options": ["Ronaldo (Brazil)", "Gerd Müller", "Pelé", "Miroslav Klose"],
                        "correct_index": 3  // D - Miroslav Klose
                    ],
                    [
                        "id": "q9",
                        "prompt": "What is the original name of the FIFA World Cup trophy?",
                        "options": ["Jules Rimet", "Golden Boot", "FIFA Gold Cup", "World Cup Chalice"],
                        "correct_index": 0  // A - Jules Rimet
                    ],
                    [
                        "id": "q10",
                        "prompt": "Which country has appeared in the most FIFA World Cup finals (8 total)?",
                        "options": ["Brazil", "Italy", "Germany", "Argentina"],
                        "correct_index": 2  // C - Germany
                    ]
                ]
            ],

            "updated_at": FieldValue.serverTimestamp()
        ]
    }
}
