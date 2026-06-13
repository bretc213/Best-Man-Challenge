//
//  WeeklyChallengeSeeder2026W48.swift
//  Best Man Challenge
//
//  Week 48: MLB Logo Quiz — 30 teams
//  Dates: Nov 30–Dec 6, 2026
//  Uses setData(merge: true) — document already exists as TBD placeholder.
//
//  NOTE: Requires logo assets in the Xcode asset catalog named:
//  mlb_ari, mlb_atl, mlb_bal, mlb_bos, mlb_chc, mlb_chw, mlb_cin, mlb_cle,
//  mlb_col, mlb_det, mlb_hou, mlb_kan, mlb_laa, mlb_lad, mlb_mia, mlb_mil,
//  mlb_min, mlb_nym, mlb_nyy, mlb_oak, mlb_phi, mlb_pit, mlb_sd, mlb_sea,
//  mlb_sf, mlb_stl, mlb_tb, mlb_tex, mlb_tor, mlb_was
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W48 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w48"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()
            if snap.exists,
               let title = snap.data()?["title"] as? String,
               !title.contains("TBD") {
                print("ℹ️ W48 already seeded — skipping.")
                return
            }
            try await ref.setData(buildData(), merge: true)
            print("✅ W48 MLB Logo Quiz seeded.")
        } catch {
            print("❌ W48 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func buildData() -> [String: Any] {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026; components.month = 11; components.day = 30
        components.hour = 0; components.minute = 0; components.second = 0
        let startDate = calendar.date(from: components)!
        components.month = 12; components.day = 7
        let endDate = calendar.date(from: components)!

        let teams: [(id: String, name: String, img: String)] = [
            ("q_ari",  "Arizona Diamondbacks",       "mlb_ari"),
            ("q_atl",  "Atlanta Braves",             "mlb_atl"),
            ("q_bal",  "Baltimore Orioles",          "mlb_bal"),
            ("q_bos",  "Boston Red Sox",             "mlb_bos"),
            ("q_chc",  "Chicago Cubs",               "mlb_chc"),
            ("q_chw",  "Chicago White Sox",          "mlb_chw"),
            ("q_cin",  "Cincinnati Reds",            "mlb_cin"),
            ("q_cle",  "Cleveland Guardians",        "mlb_cle"),
            ("q_col",  "Colorado Rockies",           "mlb_col"),
            ("q_det",  "Detroit Tigers",             "mlb_det"),
            ("q_hou",  "Houston Astros",             "mlb_hou"),
            ("q_kan",  "Kansas City Royals",         "mlb_kan"),
            ("q_laa",  "Los Angeles Angels",         "mlb_laa"),
            ("q_lad",  "Los Angeles Dodgers",        "mlb_lad"),
            ("q_mia",  "Miami Marlins",              "mlb_mia"),
            ("q_mil",  "Milwaukee Brewers",          "mlb_mil"),
            ("q_min",  "Minnesota Twins",            "mlb_min"),
            ("q_nym",  "New York Mets",              "mlb_nym"),
            ("q_nyy",  "New York Yankees",           "mlb_nyy"),
            ("q_oak",  "Oakland Athletics",          "mlb_oak"),
            ("q_phi",  "Philadelphia Phillies",      "mlb_phi"),
            ("q_pit",  "Pittsburgh Pirates",         "mlb_pit"),
            ("q_sd",   "San Diego Padres",           "mlb_sd"),
            ("q_sea",  "Seattle Mariners",           "mlb_sea"),
            ("q_sf",   "San Francisco Giants",       "mlb_sf"),
            ("q_stl",  "St. Louis Cardinals",        "mlb_stl"),
            ("q_tb",   "Tampa Bay Rays",             "mlb_tb"),
            ("q_tex",  "Texas Rangers",              "mlb_tex"),
            ("q_tor",  "Toronto Blue Jays",          "mlb_tor"),
            ("q_was",  "Washington Nationals",       "mlb_was"),
        ]

        let imageQuestions: [[String: Any]] = teams.shuffled().map { team in
            [
                "id": team.id,
                "prompt": "Which MLB team does this logo belong to?",
                "image_name": team.img,
                "answer": team.name,
                "acceptable_answers": acceptableAnswers(for: team.name),
                "allow_fuzzy_match": true,
                "fuzzy_distance": 2
            ]
        }

        return [
            "week": 48,
            "weekInt": 48,
            "title": "Week 48: MLB Logo Quiz",
            "description": "Name all 30 MLB teams by their logo. Type the team name — city or nickname both count. Each correct answer earns 1 point.",
            "type": "image_quiz",
            "game_format": "image_quiz",

            "is_active": false,
            "is_finalized": false,
            "finalized_at": NSNull(),

            "max_points": 30,
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

    private static func acceptableAnswers(for fullName: String) -> [String] {
        let parts = fullName.components(separatedBy: " ")
        var answers: [String] = [fullName]

        if parts.count >= 2 {
            answers.append(parts.last!)
            if parts.count == 3 {
                answers.append("\(parts[1]) \(parts[2])")
            }
        }
        answers.append(parts.first!)

        // Special cases
        switch fullName {
        case "Arizona Diamondbacks": answers += ["D-Backs", "Dbacks"]
        case "Boston Red Sox":       answers += ["Red Sox", "BoSox"]
        case "Chicago White Sox":    answers += ["White Sox", "Sox"]
        case "Cleveland Guardians":  answers += ["Guardians", "Cleveland"]
        case "Kansas City Royals":   answers += ["KC", "KC Royals", "Royals"]
        case "Los Angeles Angels":   answers += ["Angels", "Halos", "LAA"]
        case "Los Angeles Dodgers":  answers += ["Dodgers", "LAD"]
        case "New York Mets":        answers += ["Mets", "NYM"]
        case "New York Yankees":     answers += ["Yankees", "NYY", "Yanks"]
        case "Oakland Athletics":    answers += ["A's", "Athletics"]
        case "San Diego Padres":     answers += ["Padres", "SD"]
        case "San Francisco Giants": answers += ["Giants", "SF Giants"]
        case "St. Louis Cardinals":  answers += ["Cardinals", "STL", "St Louis Cardinals"]
        case "Tampa Bay Rays":       answers += ["Rays", "TB Rays"]
        case "Washington Nationals": answers += ["Nationals", "Nats"]
        default: break
        }

        return Array(Set(answers))
    }
}
