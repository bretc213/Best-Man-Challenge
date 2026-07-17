//
//  WeeklyChallengeSeeder2026W28.swift
//  Best Man Challenge
//
//  Week 28: World Cup Final — Spain vs Argentina
//  Sunday July 19, 2026 | MetLife Stadium
//  10 props, 1 pt each, max 10 pts
//
//  Props live in: weekly_challenges/2026_w28/props/{propId}
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W28 {

    // MARK: - Entry point

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w28"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()

            // Skip if already seeded with real matchup data.
            // Check title — unlike is_active, this never changes when admin finalizes/deactivates.
            if snap.exists,
               let title = snap.data()?["title"] as? String,
               title.contains("Spain") || title.contains("Argentina") {
                print("ℹ️ W28 World Cup Final already seeded — skipping.")
                return
            }

            var data = buildChallengeData()
            if snap.exists {
                data.removeValue(forKey: "is_active")
            }
            try await ref.setData(data, merge: true)
            print("✅ W28 Spain vs Argentina challenge doc seeded.")

            await seedProps(db: db, challengeId: challengeId)

        } catch {
            print("❌ W28 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    // MARK: - Challenge document

    private static func buildChallengeData() -> [String: Any] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var comps = DateComponents()

        comps.year = 2026; comps.month = 7; comps.day = 13
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let startDate = cal.date(from: comps)!

        // Picks lock at kickoff — July 19, 3 PM ET = 19:00 UTC
        comps.day = 19; comps.hour = 19; comps.minute = 0
        let locksAt = cal.date(from: comps)!

        // Challenge window closes July 20
        comps.day = 20; comps.hour = 23; comps.minute = 59
        let endDate = cal.date(from: comps)!

        return [
            "week": 28,
            "weekInt": 28,
            "title": "Week 28: World Cup Final",
            "description": "Spain vs Argentina. Sunday July 19 at MetLife Stadium. Pick your props — goalscorers, BTTS, O/U, halftime result, Golden Boot, and Saturday's third-place game. 10 props, 1 pt each.",
            "type": "prop_bets",
            "game_format": "prop_bets",

            "is_active": true,
            "is_finalized": false,
            "finalized_at": NSNull(),

            "max_points": 10,
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

        // Deactivate old TBD placeholder props from initial seed
        let oldPropIds = ["p1_winner", "p2_first_scorer", "p3_total_goals", "p4_penalties", "p5_red_card"]
        for oldId in oldPropIds {
            try? await propsRef.document(oldId).setData(["is_active": false], merge: true)
        }

        let props: [[String: Any]] = [

            // ── Goalscorer props (4 pts) ─────────────────────────────────

            [
                "id": "p1_messi",
                "position": 1,
                "kind": "multiple_choice",
                "prompt": "Lionel Messi scores anytime in the Final (90 min + ET)?",
                "market": "Messi Anytime Scorer",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": [
                    ["id": "p1_yes", "position": 1, "label": "Yes — Messi scores", "odds_american": 150],
                    ["id": "p1_no",  "position": 2, "label": "No",                  "odds_american": -190]
                ]
            ],
            [
                "id": "p2_oyarzabal",
                "position": 2,
                "kind": "multiple_choice",
                "prompt": "Mikel Oyarzabal scores anytime?",
                "market": "Oyarzabal Anytime Scorer",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": [
                    ["id": "p2_yes", "position": 1, "label": "Yes — Oyarzabal scores", "odds_american": 170],
                    ["id": "p2_no",  "position": 2, "label": "No",                      "odds_american": -210]
                ]
            ],
            [
                "id": "p3_yamal",
                "position": 3,
                "kind": "multiple_choice",
                "prompt": "Lamine Yamal scores anytime?",
                "market": "Yamal Anytime Scorer",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": [
                    ["id": "p3_yes", "position": 1, "label": "Yes — Yamal scores", "odds_american": 220],
                    ["id": "p3_no",  "position": 2, "label": "No",                  "odds_american": -270]
                ]
            ],
            [
                "id": "p4_lautaro",
                "position": 4,
                "kind": "multiple_choice",
                "prompt": "Lautaro Martínez scores anytime?",
                "market": "Lautaro Anytime Scorer",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": [
                    ["id": "p4_yes", "position": 1, "label": "Yes — Lautaro scores", "odds_american": 260],
                    ["id": "p4_no",  "position": 2, "label": "No",                    "odds_american": -320]
                ]
            ],

            // ── Match props (4 pts) ──────────────────────────────────────

            [
                "id": "p5_btts",
                "position": 5,
                "kind": "multiple_choice",
                "prompt": "Both teams score in the Final (90 min + extra time)?",
                "market": "Both Teams to Score",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": [
                    ["id": "p5_yes", "position": 1, "label": "Yes — both teams score", "odds_american": -116],
                    ["id": "p5_no",  "position": 2, "label": "No",                      "odds_american": -110]
                ]
            ],
            [
                "id": "p6_ou",
                "position": 6,
                "kind": "over_under",
                "prompt": "Total goals in the Final (90 min + ET, excludes penalties)?",
                "market": "Total Goals",
                "line": 2.5,
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": [
                    ["id": "p6_over",  "position": 1, "label": "Over 2.5",  "odds_american": 106],
                    ["id": "p6_under", "position": 2, "label": "Under 2.5", "odds_american": -130]
                ]
            ],
            [
                "id": "p7_halftime",
                "position": 7,
                "kind": "multiple_choice",
                "prompt": "Who leads at half-time?",
                "market": "Half-Time Result",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": [
                    ["id": "p7_spain",     "position": 1, "label": "Spain leading at HT"],
                    ["id": "p7_draw",      "position": 2, "label": "Draw at HT (0-0 or level)", "odds_american": -110],
                    ["id": "p7_argentina", "position": 3, "label": "Argentina leading at HT"]
                ]
            ],
            [
                "id": "p8_no_goal",
                "position": 8,
                "kind": "multiple_choice",
                "prompt": "Final ends 0-0 through 120 minutes (goes to shootout with no goals)?",
                "market": "No Goalscorer",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": [
                    ["id": "p8_yes", "position": 1, "label": "Yes — no goals, straight to pens", "odds_american": 1300],
                    ["id": "p8_no",  "position": 2, "label": "No — at least one goal scored"]
                ]
            ],

            // ── Tournament props (2 pts) ─────────────────────────────────

            [
                "id": "p9_golden_boot",
                "position": 9,
                "kind": "multiple_choice",
                "prompt": "Who wins the Golden Boot (top scorer of the tournament)?",
                "market": "Golden Boot",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": [
                    ["id": "p9_messi",  "position": 1, "label": "Lionel Messi 🇦🇷 (8 goals, 4 assists — leads tiebreaker)"],
                    ["id": "p9_mbappe", "position": 2, "label": "Kylian Mbappé 🇫🇷 (8 goals — 3rd place Sat)"],
                    ["id": "p9_other",  "position": 3, "label": "Someone else scores more"]
                ]
            ],
            [
                "id": "p10_third_place",
                "position": 10,
                "kind": "multiple_choice",
                "prompt": "Third-place game Saturday July 18 — France vs England. Who wins bronze?",
                "market": "Third Place",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": [
                    ["id": "p10_france",  "position": 1, "label": "France 🇫🇷",  "odds_american": -188],
                    ["id": "p10_england", "position": 2, "label": "England 🏴󠁧󠁢󠁥󠁮󠁧󠁿", "odds_american": 148]
                ]
            ]
        ]

        for prop in props {
            guard let propId = prop["id"] as? String else { continue }
            let propRef = propsRef.document(propId)
            do {
                // Always overwrite — this is the real-data seeding pass
                try await propRef.setData(prop)
                print("✅ W28 prop \(propId) seeded.")
            } catch {
                print("❌ W28 prop \(propId) seed failed:", error.localizedDescription)
            }
        }
    }
}
