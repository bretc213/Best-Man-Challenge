//
//  WeeklyChallengeSeeder2026W27.swift
//  Best Man Challenge
//
//  Week 27: MLB Home Run Derby
//  Date: Monday, July 13, 2026 — Citizens Bank Park, Philadelphia
//  Broadcast: Netflix, 7 PM ET coverage / 8 PM ET first swing
//
//  Format (new swing-based):
//    Round 1  — all 8 hit, 20 swings each, top 4 advance by HR total
//    Semis    — 1v4 and 2v3, 15 swings each, top 2 advance
//    Final    — 2 players, 15 swings each
//    Tiebreak — R1: longest HR | Semis/Final: 3 extra swings each
//
//  Participants:
//    Bryce Harper         Philadelphia Phillies   NL
//    Kyle Schwarber       Philadelphia Phillies   NL
//    Jac Caglianone       Kansas City Royals      AL
//    Junior Caminero      Tampa Bay Rays          AL
//    Willson Contreras    Boston Red Sox          AL
//    Munetaka Murakami    Chicago White Sox       AL
//    Ben Rice             New York Yankees        AL
//    Jordan Walker        St. Louis Cardinals     NL
//    (AL: 5 players  |  NL: 3 players)
//
//  Props (11 pts total, 1 pt each):
//    p1–p4   Pick the 4 Semifinalists
//    p5–p6   Pick the 2 Finalists
//    p7      Pick the HRD Champion
//    p8      Will a Phillies player (Harper or Schwarber) win? Yes / No
//    p9      AL vs NL — who hits more HRs in Round 1?
//    p10     Round 1 total HRs — Over/Under 44.5
//    p11     Total Derby HRs — Over/Under 72.5
//
//  ⚠️  Grading notes for p1–p6 (Semifinalist / Finalist picks):
//    Each prop is a single-select from all 8 players.
//    After results, set correct_option_id on each slot to one of the
//    actual semifinalists / finalists — match as many players' picks
//    as possible across the 4/2 slots.
//
//  ⚠️  O/U lines (p10, p11) are estimates — adjust before locking if needed.
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W27 {

    // MARK: - Option IDs (shared across all pick-a-player props)

    private static let options: [[String: Any]] = [
        ["id": "opt_harper",     "position": 1, "label": "Bryce Harper (PHI)"],
        ["id": "opt_schwarber",  "position": 2, "label": "Kyle Schwarber (PHI)"],
        ["id": "opt_caglianone", "position": 3, "label": "Jac Caglianone (KC)"],
        ["id": "opt_caminero",   "position": 4, "label": "Junior Caminero (TB)"],
        ["id": "opt_contreras",  "position": 5, "label": "Willson Contreras (BOS)"],
        ["id": "opt_murakami",   "position": 6, "label": "Munetaka Murakami (CWS)"],
        ["id": "opt_rice",       "position": 7, "label": "Ben Rice (NYY)"],
        ["id": "opt_walker",     "position": 8, "label": "Jordan Walker (STL)"]
    ]

    // MARK: - Entry point

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w27"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()

            // Skip if already seeded with real HRD content.
            // Title never changes when admin finalizes/deactivates — unlike is_active.
            if snap.exists,
               let title = snap.data()?["title"] as? String,
               title.contains("Home Run Derby") {
                print("ℹ️ W27 Home Run Derby already seeded — skipping.")
                return
            }

            // Build the seed data. On re-runs (doc already exists), strip is_active so
            // we never override what admin has set — only a fresh doc gets is_active: true.
            var data = buildChallengeData()
            if snap.exists {
                data.removeValue(forKey: "is_active")
            }

            try await ref.setData(data, merge: true)
            print("✅ W27 Home Run Derby challenge doc seeded.")

            // Seed props (checks each individually — safe to re-run)
            await seedProps(db: db, challengeId: challengeId)

        } catch {
            print("❌ W27 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    // MARK: - Challenge document

    private static func buildChallengeData() -> [String: Any] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 6
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let startDate = cal.date(from: comps)!

        // Picks lock at first swing — July 13, 8 PM EDT = July 14, 00:00 UTC
        comps.day = 14; comps.hour = 0; comps.minute = 0
        let locksAt = cal.date(from: comps)!

        // Challenge window closes end of July 14
        comps.hour = 23; comps.minute = 59
        let endDate = cal.date(from: comps)!

        return [
            "week": 27,
            "weekInt": 27,
            "title": "Week 27: Home Run Derby",
            "description": "The 2026 T-Mobile Home Run Derby is Monday, July 13 at Citizens Bank Park in Philly. New this year: swing-based format — 20 swings in Round 1, 15 in the Semis and Final. Pick your semifinalists, finalists, champion, and nail the prop bets for up to 11 points.",
            "type": "prop_bets",
            "game_format": "prop_bets",

            "is_active": true,
            "is_finalized": false,
            "finalized_at": NSNull(),

            "max_points": 11,
            "winner_bonus": 1,
            "winner_bonuses_applied": false,
            "winners": [],

            "start_date": Timestamp(date: startDate),
            "end_date": Timestamp(date: endDate),
            "locksAt": Timestamp(date: locksAt),

            "updated_at": FieldValue.serverTimestamp()
        ]
    }

    // MARK: - Props subcollection

    static func seedProps(db: Firestore, challengeId: String) async {
        let propsRef = db.collection("weekly_challenges").document(challengeId).collection("props")

        let props: [[String: Any]] = [

            // ── Semifinalist picks (4 pts) ───────────────────────────────
            [
                "id": "p1_semi1",
                "position": 1,
                "kind": "multiple_choice",
                "prompt": "Semifinalist Pick #1 — who makes the Top 4 in Round 1?",
                "market": "Semifinalist #1",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": options
            ],
            [
                "id": "p2_semi2",
                "position": 2,
                "kind": "multiple_choice",
                "prompt": "Semifinalist Pick #2 — who makes the Top 4 in Round 1?",
                "market": "Semifinalist #2",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": options
            ],
            [
                "id": "p3_semi3",
                "position": 3,
                "kind": "multiple_choice",
                "prompt": "Semifinalist Pick #3 — who makes the Top 4 in Round 1?",
                "market": "Semifinalist #3",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": options
            ],
            [
                "id": "p4_semi4",
                "position": 4,
                "kind": "multiple_choice",
                "prompt": "Semifinalist Pick #4 — who makes the Top 4 in Round 1?",
                "market": "Semifinalist #4",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": options
            ],

            // ── Finalist picks (2 pts) ───────────────────────────────────
            [
                "id": "p5_finalist1",
                "position": 5,
                "kind": "multiple_choice",
                "prompt": "Finalist Pick #1 — who reaches the Championship round?",
                "market": "Finalist #1",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": options
            ],
            [
                "id": "p6_finalist2",
                "position": 6,
                "kind": "multiple_choice",
                "prompt": "Finalist Pick #2 — who reaches the Championship round?",
                "market": "Finalist #2",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": options
            ],

            // ── Champion pick (1 pt) ─────────────────────────────────────
            [
                "id": "p7_winner",
                "position": 7,
                "kind": "multiple_choice",
                "prompt": "Who wins the 2026 Home Run Derby?",
                "market": "HRD Champion",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": options
            ],

            // ── Phillies prop (1 pt) ─────────────────────────────────────
            [
                "id": "p8_philly",
                "position": 8,
                "kind": "multiple_choice",
                "prompt": "Will a Phillies player (Harper or Schwarber) win the Home Run Derby?",
                "market": "Hometown Hero",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": [
                    ["id": "p8_yes", "position": 1, "label": "Yes — Philly wins it"],
                    ["id": "p8_no",  "position": 2, "label": "No — the field wins"]
                ]
            ],

            // ── AL vs NL Round 1 HRs (1 pt) ─────────────────────────────
            //    AL (5): Caglianone, Caminero, Contreras, Murakami, Rice
            //    NL (3): Harper, Schwarber, Walker
            [
                "id": "p9_al_nl",
                "position": 9,
                "kind": "multiple_choice",
                "prompt": "Combined Round 1 home runs — AL (5 players) vs NL (3 players). Who hits more?",
                "market": "AL vs NL Round 1",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": [
                    ["id": "p9_al", "position": 1, "label": "AL hits more (Caglianone, Caminero, Contreras, Murakami, Rice)"],
                    ["id": "p9_nl", "position": 2, "label": "NL hits more (Harper, Schwarber, Walker)"]
                ]
            ],

            // ── Round 1 total HRs O/U (1 pt) ────────────────────────────
            //    8 players × 20 swings. Line: 44.5
            //    ⚠️ Adjust before Derby starts if needed
            [
                "id": "p10_r1_ou",
                "position": 10,
                "kind": "over_under",
                "prompt": "Total home runs hit in Round 1 (all 8 players, 20 swings each)",
                "market": "Round 1 Total HRs",
                "line": 44.5,
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": [
                    ["id": "p10_over",  "position": 1, "label": "Over 44.5"],
                    ["id": "p10_under", "position": 2, "label": "Under 44.5"]
                ]
            ],

            // ── Total Derby HRs O/U (1 pt) ───────────────────────────────
            //    R1 (160 swings) + Semis (60) + Final (30) = 250 total swings
            //    Line: 72.5
            //    ⚠️ Adjust before Derby starts if needed
            [
                "id": "p11_total_ou",
                "position": 11,
                "kind": "over_under",
                "prompt": "Total home runs across the entire Derby (all rounds combined)",
                "market": "Total Derby HRs",
                "line": 72.5,
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": [
                    ["id": "p11_over",  "position": 1, "label": "Over 72.5"],
                    ["id": "p11_under", "position": 2, "label": "Under 72.5"]
                ]
            ]
        ]

        for prop in props {
            guard let propId = prop["id"] as? String else { continue }
            let propRef = propsRef.document(propId)
            do {
                let snap = try await propRef.getDocument()
                if snap.exists {
                    print("ℹ️ W27 prop \(propId) already exists — skipping.")
                    continue
                }
                try await propRef.setData(prop)
                print("✅ W27 prop \(propId) seeded.")
            } catch {
                print("❌ W27 prop \(propId) failed:", error.localizedDescription)
            }
        }
    }
}
