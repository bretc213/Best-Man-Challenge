//
//  WeeklyChallengeSeeder2026W34.swift
//  Best Man Challenge
//
//  Week 34: College Football Hype Quiz — 10 questions, 1 pt each (10 pts max)
//  Dates: Aug 24–30, 2026  (CFB season ~1 week away)
//  Auto-scored quiz. All questions are stable HISTORICAL facts — safe to seed now.
//
//  PERSONALIZE: These are general CFB-history questions (Heisman, iconic
//  rivalries, championships). Swap any question for one tied to the teams the
//  group actually follows — keep the shape {prompt, 4 options, correct_index}.
//
//  correct_index: A=0, B=1, C=2, D=3.
//  Skips once the quiz is already in place so it won't overwrite a live doc.
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W34 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w34"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()
            if snap.exists, snap.data()?["quiz"] != nil {
                print("ℹ️ W34 CFB Hype Quiz already seeded — skipping.")
                return
            }
            try await ref.setData(buildData())
            print("✅ W34 College Football Hype Quiz seeded.")
        } catch {
            print("❌ W34 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func buildData() -> [String: Any] {
        // Manager parses startDate/endDate (camelCase Timestamps).
        let startDate = makeTimestampLA(year: 2026, month: 8, day: 24, hour: 0,  minute: 0)
        let endDate   = makeTimestampLA(year: 2026, month: 8, day: 30, hour: 23, minute: 59)

        return [
            "week": 34,
            "weekInt": 34,
            "title": "Week 34: College Football Hype Quiz",
            "description": "Kickoff is almost here. 10 questions on college football history — Heisman winners, legendary rivalries, and championship lore. 1 point each, 10 up for grabs.",
            "type": "quiz",
            "game_format": "quiz",

            "is_active": false,
            "is_finalized": false,
            "finalized_at": NSNull(),

            "max_points": 10,
            "winner_bonus": 1,
            "winner_bonuses_applied": false,
            "winners": [],

            "startDate": startDate,
            "endDate": endDate,

            "quiz": [
                "points_per_correct": 1,
                "questions": [
                    [
                        "id": "q1",
                        "prompt": "Who won the very first Heisman Trophy, back in 1935?",
                        "options": ["Red Grange", "Tom Harmon", "Davey O'Brien", "Jay Berwanger"],
                        "correct_index": 3   // D — Jay Berwanger (Chicago)
                    ],
                    [
                        "id": "q2",
                        "prompt": "Which rivalry game is known as 'The Iron Bowl'?",
                        "options": ["Ohio State vs. Michigan", "Texas vs. Oklahoma", "Alabama vs. Auburn", "Army vs. Navy"],
                        "correct_index": 2   // C — Alabama vs. Auburn
                    ],
                    [
                        "id": "q3",
                        "prompt": "The Ohio State–Michigan rivalry is simply known as what?",
                        "options": ["The Game", "The Iron Bowl", "Red River Rivalry", "Bedlam"],
                        "correct_index": 0   // A — The Game
                    ],
                    [
                        "id": "q4",
                        "prompt": "Which two teams meet each year in the Red River Rivalry?",
                        "options": ["Oklahoma & Oklahoma State", "Texas & Oklahoma", "Ole Miss & Mississippi State", "Alabama & Auburn"],
                        "correct_index": 1   // B — Texas & Oklahoma
                    ],
                    [
                        "id": "q5",
                        "prompt": "Who is the only player ever to win the Heisman Trophy twice?",
                        "options": ["Herschel Walker", "Bo Jackson", "Archie Griffin", "Tim Tebow"],
                        "correct_index": 2   // C — Archie Griffin (Ohio State, 1974 & 1975)
                    ],
                    [
                        "id": "q6",
                        "prompt": "The annual game between the U.S. Military Academy and U.S. Naval Academy is called the…",
                        "options": ["Backyard Brawl", "Army–Navy Game", "Holy War", "Egg Bowl"],
                        "correct_index": 1   // B — Army–Navy Game
                    ],
                    [
                        "id": "q7",
                        "prompt": "'Bevo,' a live Longhorn steer, is the mascot of which school?",
                        "options": ["Oklahoma State", "Colorado", "Texas A&M", "Texas"],
                        "correct_index": 3   // D — Texas
                    ],
                    [
                        "id": "q8",
                        "prompt": "In which California city is the Rose Bowl played every year?",
                        "options": ["Los Angeles", "Pasadena", "San Diego", "Anaheim"],
                        "correct_index": 1   // B — Pasadena
                    ],
                    [
                        "id": "q9",
                        "prompt": "Which team won the FIRST College Football Playoff National Championship (after the 2014 season)?",
                        "options": ["Oregon", "Alabama", "Ohio State", "Clemson"],
                        "correct_index": 2   // C — Ohio State (beat Oregon)
                    ],
                    [
                        "id": "q10",
                        "prompt": "Nick Saban won national titles as head coach at which TWO schools?",
                        "options": ["Florida & Alabama", "LSU & Alabama", "Georgia & Alabama", "Auburn & Alabama"],
                        "correct_index": 1   // B — LSU & Alabama
                    ]
                ]
            ],

            "updated_at": FieldValue.serverTimestamp()
        ]
    }

    private static func makeTimestampLA(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Timestamp {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let comps = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return Timestamp(date: cal.date(from: comps) ?? Date())
    }
}
