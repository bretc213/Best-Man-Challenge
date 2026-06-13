//
//  WeeklyChallengeSeeder2026W47.swift
//  Best Man Challenge
//
//  Week 47: NFL Logo Quiz — 32 teams
//  Dates: Nov 23–29, 2026
//  Uses setData(merge: true) — document already exists as TBD placeholder.
//
//  NOTE: Requires logo assets in the Xcode asset catalog named:
//  nfl_ari, nfl_atl, nfl_bal, nfl_buf, nfl_car, nfl_chi, nfl_cin, nfl_cle,
//  nfl_dal, nfl_den, nfl_det, nfl_gnb, nfl_hou, nfl_ind, nfl_jax, nfl_kan,
//  nfl_lac, nfl_lar, nfl_lv, nfl_mia, nfl_min, nfl_ne, nfl_no, nfl_nyg,
//  nfl_nyj, nfl_phi, nfl_pit, nfl_sea, nfl_sf, nfl_tb, nfl_ten, nfl_was
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W47 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w47"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()
            if snap.exists,
               let title = snap.data()?["title"] as? String,
               !title.contains("TBD") {
                print("ℹ️ W47 already seeded — skipping.")
                return
            }
            try await ref.setData(buildData(), merge: true)
            print("✅ W47 NFL Logo Quiz seeded.")
        } catch {
            print("❌ W47 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func buildData() -> [String: Any] {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026; components.month = 11; components.day = 23
        components.hour = 0; components.minute = 0; components.second = 0
        let startDate = calendar.date(from: components)!
        components.day = 30
        let endDate = calendar.date(from: components)!

        let teams: [(id: String, name: String, img: String)] = [
            ("q_ari",  "Arizona Cardinals",         "nfl_ari"),
            ("q_atl",  "Atlanta Falcons",            "nfl_atl"),
            ("q_bal",  "Baltimore Ravens",           "nfl_bal"),
            ("q_buf",  "Buffalo Bills",              "nfl_buf"),
            ("q_car",  "Carolina Panthers",          "nfl_car"),
            ("q_chi",  "Chicago Bears",              "nfl_chi"),
            ("q_cin",  "Cincinnati Bengals",         "nfl_cin"),
            ("q_cle",  "Cleveland Browns",           "nfl_cle"),
            ("q_dal",  "Dallas Cowboys",             "nfl_dal"),
            ("q_den",  "Denver Broncos",             "nfl_den"),
            ("q_det",  "Detroit Lions",              "nfl_det"),
            ("q_gnb",  "Green Bay Packers",          "nfl_gnb"),
            ("q_hou",  "Houston Texans",             "nfl_hou"),
            ("q_ind",  "Indianapolis Colts",         "nfl_ind"),
            ("q_jax",  "Jacksonville Jaguars",       "nfl_jax"),
            ("q_kan",  "Kansas City Chiefs",         "nfl_kan"),
            ("q_lac",  "Los Angeles Chargers",       "nfl_lac"),
            ("q_lar",  "Los Angeles Rams",           "nfl_lar"),
            ("q_lv",   "Las Vegas Raiders",          "nfl_lv"),
            ("q_mia",  "Miami Dolphins",             "nfl_mia"),
            ("q_min",  "Minnesota Vikings",          "nfl_min"),
            ("q_ne",   "New England Patriots",       "nfl_ne"),
            ("q_no",   "New Orleans Saints",         "nfl_no"),
            ("q_nyg",  "New York Giants",            "nfl_nyg"),
            ("q_nyj",  "New York Jets",              "nfl_nyj"),
            ("q_phi",  "Philadelphia Eagles",        "nfl_phi"),
            ("q_pit",  "Pittsburgh Steelers",        "nfl_pit"),
            ("q_sea",  "Seattle Seahawks",           "nfl_sea"),
            ("q_sf",   "San Francisco 49ers",        "nfl_sf"),
            ("q_tb",   "Tampa Bay Buccaneers",       "nfl_tb"),
            ("q_ten",  "Tennessee Titans",           "nfl_ten"),
            ("q_was",  "Washington Commanders",      "nfl_was"),
        ]

        let imageQuestions: [[String: Any]] = teams.shuffled().map { team in
            [
                "id": team.id,
                "prompt": "Which NFL team does this logo belong to?",
                "image_name": team.img,
                "answer": team.name,
                "acceptable_answers": acceptableAnswers(for: team.name),
                "allow_fuzzy_match": true,
                "fuzzy_distance": 2
            ]
        }

        return [
            "week": 47,
            "weekInt": 47,
            "title": "Week 47: NFL Logo Quiz",
            "description": "Can you name all 32 NFL teams by their logo? Type the team name (city or nickname both count). Each correct answer is worth 1 point.",
            "type": "image_quiz",
            "game_format": "image_quiz",

            "is_active": false,
            "is_finalized": false,
            "finalized_at": NSNull(),

            "max_points": 32,
            "winner_bonus": 1,
            "winner_bonuses_applied": false,
            "winners": [],

            "start_date": Timestamp(date: startDate),
            "end_date": Timestamp(date: endDate),

            "quiz": [
                "points_per_correct": 1,
                "image_questions": imageQuestions
            ],

            "updated_at": FieldValue.serverTimestamp()
        ]
    }

    /// Multiple acceptable answers per team (city, nickname, abbreviation)
    private static func acceptableAnswers(for fullName: String) -> [String] {
        let parts = fullName.components(separatedBy: " ")
        var answers: [String] = [fullName]

        // Add just the nickname (last word, or last two for multi-word nicknames)
        if parts.count >= 2 {
            answers.append(parts.last!)
            if parts.count == 3 {
                answers.append("\(parts[1]) \(parts[2])")
            }
        }

        // City only
        answers.append(parts.first!)

        // Special cases
        switch fullName {
        case "Green Bay Packers":   answers += ["GB", "Packers"]
        case "New England Patriots": answers += ["NE", "Patriots", "Pats"]
        case "Kansas City Chiefs":  answers += ["KC", "Chiefs"]
        case "San Francisco 49ers": answers += ["SF", "Niners", "49ers"]
        case "Los Angeles Rams":    answers += ["LA Rams", "Rams"]
        case "Los Angeles Chargers": answers += ["LA Chargers", "Chargers"]
        case "New York Giants":     answers += ["NYG", "Giants"]
        case "New York Jets":       answers += ["NYJ", "Jets"]
        case "Las Vegas Raiders":   answers += ["Raiders", "LV Raiders"]
        case "Washington Commanders": answers += ["Washington", "Commanders"]
        default: break
        }

        return Array(Set(answers))
    }
}
