//
//  WeeklyChallengeSeeder2026W27.swift
//  Best Man Challenge
//
//  Week 27: World Cup Final Prop Bets
//  Dates: Jul 6–12, 2026 (picks window) | Final: July 19
//  Uses setData(merge: true) — document already exists as TBD placeholder.
//
//  ╔══════════════════════════════════════════════════════════════════╗
//  ║  ⚠️  UPDATE REQUIRED AFTER SEMI-FINALS (~JULY 9)               ║
//  ║                                                                  ║
//  ║  1. Replace "Team A (TBD)" / "Team B (TBD)" with real finalists ║
//  ║  2. Add real betting lines (odds_american) for each prop         ║
//  ║  3. Expand from 5 props to 10 props with real lines              ║
//  ║  4. Re-run seedPropsIfNeeded() to push updates                   ║
//  ║     (or update Firestore directly via Admin grading UI)          ║
//  ╚══════════════════════════════════════════════════════════════════╝
//
//  Props live in a SUBCOLLECTION: weekly_challenges/2026_w27/props/{propId}
//  Run seedPropsIfNeeded() separately (called from seedIfNeeded below).
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W27 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w27"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()
            if snap.exists,
               let title = snap.data()?["title"] as? String,
               !title.contains("TBD") {
                print("ℹ️ W27 already seeded — skipping.")
                return
            }
            try await ref.setData(buildChallengeData(), merge: true)
            print("✅ W27 World Cup Final Props (challenge doc) seeded.")

            await seedPropsIfNeeded(db: db, challengeId: challengeId)

        } catch {
            print("❌ W27 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    // MARK: - Challenge document

    private static func buildChallengeData() -> [String: Any] {
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 6
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let startDate = calendar.date(from: comps)!

        // Picks lock at kickoff — July 19, 11:00 AM ET (15:00 UTC)
        comps.day = 19; comps.hour = 15; comps.minute = 0
        let locksAt = calendar.date(from: comps)!

        // Challenge window closes July 13 (week ends)
        comps.day = 13; comps.hour = 0; comps.minute = 0
        let endDate = calendar.date(from: comps)!

        return [
            "week": 27,
            "weekInt": 27,
            "title": "Week 27: World Cup Final Props",
            "description": "The World Cup Final is July 19 — lock in your prop picks before kickoff. Who wins? First scorer? Total goals? Pick wisely. Results scored after the Final.",
            "type": "prop_bets",
            "game_format": "prop_bets",

            "is_active": false,
            "is_finalized": false,
            "finalized_at": NSNull(),

            "max_points": 10,
            "winner_bonus": 1,
            "winner_bonuses_applied": false,
            "winners": [],

            "start_date": Timestamp(date: startDate),
            "end_date": Timestamp(date: endDate),
            "locksAt": Timestamp(date: locksAt),  // picks lock at Final kickoff

            "updated_at": FieldValue.serverTimestamp()
        ]
    }

    // MARK: - Props subcollection

    // ⚠️ Replace "Team A" / "Team B" with actual finalists after July 9 semis.
    static func seedPropsIfNeeded(db: Firestore, challengeId: String) async {
        let propsRef = db.collection("weekly_challenges").document(challengeId).collection("props")

        let props: [[String: Any]] = [
            [
                "id": "p1_winner",
                "position": 1,
                "kind": "multiple_choice",
                "prompt": "Who wins the World Cup Final?",
                "market": "Match Winner",
                "is_active": true,
                "correct_option_id": NSNull(),   // fill in after Final
                "options": [
                    ["id": "p1_a", "position": 1, "label": "Team A (TBD)"],  // ⚠️ update when known
                    ["id": "p1_b", "position": 2, "label": "Team B (TBD)"],  // ⚠️ update when known
                    ["id": "p1_draw", "position": 3, "label": "Draw / Goes to Penalties"]
                ]
            ],
            [
                "id": "p2_first_scorer",
                "position": 2,
                "kind": "multiple_choice",
                "prompt": "Will there be a goal in the first 15 minutes?",
                "market": "Early Goal",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": [
                    ["id": "p2_yes", "position": 1, "label": "Yes"],
                    ["id": "p2_no",  "position": 2, "label": "No"]
                ]
            ],
            [
                "id": "p3_total_goals",
                "position": 3,
                "kind": "over_under",
                "prompt": "Total goals in the Final (including extra time, excluding penalties)?",
                "market": "Total Goals",
                "line": 2.5,
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": [
                    ["id": "p3_over",  "position": 1, "label": "Over 2.5"],
                    ["id": "p3_under", "position": 2, "label": "Under 2.5"]
                ]
            ],
            [
                "id": "p4_penalties",
                "position": 4,
                "kind": "multiple_choice",
                "prompt": "Does the Final go to a penalty shootout?",
                "market": "Penalty Shootout",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": [
                    ["id": "p4_yes", "position": 1, "label": "Yes — it goes to pens"],
                    ["id": "p4_no",  "position": 2, "label": "No — decided in 90 or extra time"]
                ]
            ],
            [
                "id": "p5_red_card",
                "position": 5,
                "kind": "multiple_choice",
                "prompt": "Will any player receive a red card in the Final?",
                "market": "Red Card",
                "is_active": true,
                "correct_option_id": NSNull(),
                "options": [
                    ["id": "p5_yes", "position": 1, "label": "Yes"],
                    ["id": "p5_no",  "position": 2, "label": "No"]
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
                print("❌ W27 prop \(propId) seed failed:", error.localizedDescription)
            }
        }
    }
}
