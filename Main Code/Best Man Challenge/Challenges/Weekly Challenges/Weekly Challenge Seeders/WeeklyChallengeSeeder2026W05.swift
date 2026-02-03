import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W05 {

    // Bump this if you want to re-run seeding on the same install
    static let didSeedKey = "didSeedWeeklyChallenge_2026_w05_prop_bets_v3"

    static func seedIfNeeded() async {
        if UserDefaults.standard.bool(forKey: didSeedKey) {
            print("ℹ️ Week 5 already seeded (UserDefaults).")
            return
        }

        do {
            try await seed()
            UserDefaults.standard.set(true, forKey: didSeedKey)
            print("✅ Week 5 seeded and flag saved.")
        } catch {
            print("❌ Week 5 seed failed:", error.localizedDescription)
        }
    }

    /// Seeds/updates the challenge doc and seeds props subcollection.
    /// - If the doc exists, we MERGE the top-level fields so you can iterate safely.
    /// - Props are written with merge:true so they can be updated without deleting.
    private static func seed() async throws {
        let db = Firestore.firestore()

        let challengeId = "2026_w05"
        let challengeRef = db.collection("weekly_challenges").document(challengeId)

        // Kickoff lock (edit to real kickoff time you want)
        let locksAt = makeTimestampLA(year: 2026, month: 2, day: 8, hour: 15, minute: 30) // 3:30pm PT example

        // Optional: if you still want start/end for display/history consistency
        // You can make start = now and end = kickoff, or whatever you prefer.
        let startDate = makeTimestampLA(year: 2026, month: 2, day: 3, hour: 0, minute: 0)
        let endDate   = makeTimestampLA(year: 2026, month: 3, day: 8, hour: 23, minute: 59) // example like your week 9 style

        // ✅ Standard fields (matching your other weeks) + prop bets specifics
        let challengeData: [String: Any] = [
            "week": 5,
            "title": "Super Bowl LX Props",
            "description": "Pick props (Over/Under + multiple choice) for Super Bowl LX. Lines include odds.",
            "type": "prop_bets",

            // Standard lifecycle fields you showed in week 9
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

            // Prop-bets-specific lock (kickoff)
            "locksAt": locksAt,

            // Useful metadata
            "updated_at": FieldValue.serverTimestamp()
        ]

        // ✅ Your props list (add more as you like)
        // IMPORTANT: `position` is what guarantees stable ordering.
        let props: [[String: Any]] = [
            makeOUProp(id: "p01", position: 1,  prompt: "Sam Darnold — Passing Yards", market: "darnold_pass_yards", line: 228.5, overOdds: -113, underOdds: -111),
            makeOUProp(id: "p02", position: 2,  prompt: "Sam Darnold — Passing TD", market: "darnold_pass_td", line: 1.5, overOdds: -118, underOdds: -108),
            makeOUProp(id: "p03", position: 3,  prompt: "Drake Maye — Passing Yards", market: "maye_pass_yards", line: 220.5, overOdds: -113, underOdds: -111),
            makeOUProp(id: "p04", position: 4,  prompt: "Drake Maye — Rushing Yards", market: "maye_rush_yards", line: 37.5, overOdds: -112, underOdds: -112),

            makeOUProp(id: "p05", position: 5,  prompt: "DeMarcus Lawrence — Sacks", market: "lawrence_sacks", line: 0.25, overOdds: -104, underOdds: -121),
            makeOUProp(id: "p06", position: 6,  prompt: "Leonard Williams — Sacks", market: "williams_sacks", line: 0.25, overOdds: +126, underOdds: -159),

            makeMCProp(id: "p07", position: 7,  prompt: "Coin Toss Result", market: "coin_toss",
                       options: [("Heads", +100), ("Tails", +100)]),

            makeMCProp(id: "p08", position: 8,  prompt: "Gatorade Color", market: "gatorade_color",
                       options: [("Orange", +225), ("Yellow/Green/Lime", +260), ("Blue", +260), ("Purple", +750), ("Clear/Water", +1100), ("Red/Pink", +1100), ("No Gatorade Bath", +5000)]),

            makeOUProp(id: "p09", position: 9,  prompt: "National Anthem Length (seconds)", market: "anthem_seconds", line: 120.0, overOdds: -125, underOdds: -105),

            makeMCProp(id: "p10", position: 10, prompt: "First Bay Area landmark shown", market: "landmark_first",
                       options: [("Golden Gate Bridge", -500), ("Alcatraz Island", +300)])
        ]

        // ✅ Batch write:
        // - Upsert challenge doc (merge true so you can rerun without deletes)
        // - Deactivate other active weekly challenges
        // - Upsert props (merge true)
        let batch = db.batch()

        batch.setData(challengeData, forDocument: challengeRef, merge: true)

        // Deactivate any other active challenges so your app doesn't randomly load another one
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
