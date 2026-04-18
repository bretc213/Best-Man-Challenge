import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W14 {

    // Bump this if you want to re-run seeding on the same install
    static let didSeedKey = "didSeedWeeklyChallenge_2026_w14_prop_bets_v1"

    static func seedIfNeeded() async {
        if UserDefaults.standard.bool(forKey: didSeedKey) {
            print("ℹ️ Week 14 already seeded (UserDefaults).")
            return
        }

        do {
            try await seed()
            UserDefaults.standard.set(true, forKey: didSeedKey)
            print("✅ Week 14 seeded and flag saved.")
        } catch {
            print("❌ Week 14 seed failed:", error.localizedDescription)
        }
    }

    /// Seeds/updates the challenge doc and props subcollection.
    /// - Top-level doc uses merge:true so you can iterate safely.
    /// - Props are upserted with merge:true.
    private static func seed() async throws {
        let db = Firestore.firestore()

        let challengeId = "2026_w14"
        let challengeRef = db.collection("weekly_challenges").document(challengeId)

        // Masters starts Thursday morning ET.
        // Lock a little before first tee time.
        let locksAt   = makeTimestampLA(year: 2026, month: 4, day: 9, hour: 4, minute: 30)

        let startDate = makeTimestampLA(year: 2026, month: 4, day: 7, hour: 0, minute: 0)
        let endDate   = makeTimestampLA(year: 2026, month: 4, day: 12, hour: 23, minute: 59)

        let challengeData: [String: Any] = [
            "week": 14,
            "title": "Masters Weekend Prop Bets",
            "description": "Pick props for Masters weekend. Includes finish props, score props, and tournament specials.",
            "type": "prop_bets",

            "startDate": startDate,
            "endDate": endDate,
            "is_active": true,
            "is_finalized": false,
            "finalized_at": NSNull(),
            "answer": NSNull(),
            "max_points": NSNull(),
            "winner_bonus": 1,
            "winner_bonuses_applied": false,
            "winners": [],

            // prop-bets lock
            "locksAt": locksAt,

            "updated_at": FieldValue.serverTimestamp()
        ]

        let props: [[String: Any]] = [
            makeOUProp(
                id: "p01",
                position: 1,
                prompt: "Winning Score (better than 11.5 under par)",
                market: "winning_score_under_par",
                line: 11.5,
                overOdds: -110,
                underOdds: -110
            ),

            makeOUProp(
                id: "p02",
                position: 2,
                prompt: "Scottie Scheffler — Finish Position (5.5)",
                market: "scheffler_finish_position",
                line: 5.5,
                overOdds: -110,
                underOdds: -110
            ),

            makeOUProp(
                id: "p03",
                position: 3,
                prompt: "Jon Rahm — Finish Position (9.5)",
                market: "rahm_finish_position",
                line: 9.5,
                overOdds: -110,
                underOdds: -110
            ),

            makeOUProp(
                id: "p04",
                position: 4,
                prompt: "Bryson DeChambeau — Finish Position (10.5)",
                market: "dechambeau_finish_position",
                line: 10.5,
                overOdds: -110,
                underOdds: -110
            ),

            makeOUProp(
                id: "p05",
                position: 5,
                prompt: "Rory McIlroy — Finish Position (8.5)",
                market: "mcilroy_finish_position",
                line: 8.5,
                overOdds: -110,
                underOdds: -110
            ),

            makeOUProp(
                id: "p06",
                position: 6,
                prompt: "Ludvig Aberg — Finish Position (12.5)",
                market: "aberg_finish_position",
                line: 12.5,
                overOdds: -110,
                underOdds: -110
            ),

            makeOUProp(
                id: "p07",
                position: 7,
                prompt: "Xander Schauffele — Finish Position (12.5)",
                market: "schauffele_finish_position",
                line: 12.5,
                overOdds: -110,
                underOdds: -110
            ),

            makeMCProp(
                id: "p08",
                position: 8,
                prompt: "Winning Nationality",
                market: "winner_nationality",
                options: [
                    ("USA", -125),
                    ("Europe", +175),
                    ("Rest of World", +550)
                ]
            ),

            makeMCProp(
                id: "p09",
                position: 9,
                prompt: "Will there be a playoff?",
                market: "playoff_yes_no",
                options: [
                    ("Yes", +350),
                    ("No", -500)
                ]
            ),

            makeOUProp(
                id: "p10",
                position: 10,
                prompt: "Lowest Round of the Tournament (65.5)",
                market: "lowest_round_score",
                line: 65.5,
                overOdds: -110,
                underOdds: -110
            )
        ]

        let batch = db.batch()

        batch.setData(challengeData, forDocument: challengeRef, merge: true)

        let activeSnap = try await db.collection("weekly_challenges")
            .whereField("is_active", isEqualTo: true)
            .getDocuments()

        for d in activeSnap.documents {
            if d.documentID != challengeId {
                batch.setData(["is_active": false], forDocument: d.reference, merge: true)
            }
        }

        let propsRef = challengeRef.collection("props")
        for prop in props {
            guard let id = prop["id"] as? String else { continue }
            batch.setData(prop, forDocument: propsRef.document(id), merge: true)
        }

        try await batch.commit()
        print("✅ Seeded/updated weekly_challenges/\(challengeId) and props; deactivated other active challenges.")
    }

    // MARK: - Builders

    private static func makeOUProp(
        id: String,
        position: Int,
        prompt: String,
        market: String,
        line: Double,
        overOdds: Int,
        underOdds: Int
    ) -> [String: Any] {
        [
            "id": id,
            "position": position,
            "kind": "over_under",
            "prompt": prompt,
            "market": market,
            "line": line,
            "options": [
                ["id": "over",  "position": 0, "label": "OVER",  "odds_american": overOdds],
                ["id": "under", "position": 1, "label": "UNDER", "odds_american": underOdds]
            ],
            "is_active": true,
            "updated_at": FieldValue.serverTimestamp()
        ]
    }

    private static func makeMCProp(
        id: String,
        position: Int,
        prompt: String,
        market: String,
        options: [(String, Int)]
    ) -> [String: Any] {
        let optionDicts: [[String: Any]] = options.enumerated().map { idx, item in
            [
                "id": "opt_\(idx)",
                "position": idx,
                "label": item.0,
                "odds_american": item.1
            ]
        }

        return [
            "id": id,
            "position": position,
            "kind": "multiple_choice",
            "prompt": prompt,
            "market": market,
            "options": optionDicts,
            "is_active": true,
            "updated_at": FieldValue.serverTimestamp()
        ]
    }

    // MARK: - Timestamp helper

    private static func makeTimestampLA(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Timestamp {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let comps = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        let date = cal.date(from: comps) ?? Date()
        return Timestamp(date: date)
    }
}
