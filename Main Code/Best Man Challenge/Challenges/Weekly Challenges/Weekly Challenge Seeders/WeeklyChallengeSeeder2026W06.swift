//
//  WeeklyChallengeSeeder2026W06.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 2/9/26.
//


import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W06 {

    // ✅ NEW key so it runs even if you seeded something before
    static let didSeedKey = "didSeedWeeklyChallenge_2026_w06_winter_olympics_temp_v2_required_fields_fix"

    static func seedIfNeeded() async {
        if UserDefaults.standard.bool(forKey: didSeedKey) {
            print("ℹ️ Week 6 already seeded (UserDefaults).")
            return
        }

        do {
            try await seed()
            UserDefaults.standard.set(true, forKey: didSeedKey)
            print("✅ Week 6 seeded and flag saved.")
        } catch {
            print("❌ Week 6 seed failed:", error.localizedDescription)
        }
    }

    private static func seed() async throws {
        let db = Firestore.firestore()

        let challengeId = "2026_w06"
        let challengeRef = db.collection("weekly_challenges").document(challengeId)

        // 🔒 Users pick before Wed (start of Wednesday)
        let locksAt = makeTimestampLA(year: 2026, month: 2, day: 11, hour: 0, minute: 0)

        let startDate = makeTimestampLA(year: 2026, month: 2, day: 9, hour: 0, minute: 0)
        let endDate   = makeTimestampLA(year: 2026, month: 2, day: 15, hour: 23, minute: 59)

        // ✅ REQUIRED fields guaranteed (correct types, never null)
        // NOTE: merge: false below ensures these fields truly exist on the doc
        let challengeData: [String: Any] = [
            "week": 6, // Int
            "title": "Winter Olympics — Week 6 Picks", // String
            "description": "Make your picks before Wednesday. As events finalize, admin will post correct answers and the weekly leaderboard will update.", // String
            "type": "winter_olympics_temp", // String

            // Optional compatibility helpers (harmless if unused)
            "weekInt": 6,

            // Your normal lifecycle fields
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

            "locksAt": locksAt,

            "created_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp()
        ]

        // ✅ Props (multiple choice) — you finalize by setting correct_option_id
        let props: [[String: Any]] = [
            makeMCEvent(id: "e01", position: 1, prompt: "Men’s Hockey — Gold Medal Winner", market: "olympics_m_hockey_gold",
                        options: ["USA", "Canada", "Sweden", "Finland", "Other"]),
            makeMCEvent(id: "e02", position: 2, prompt: "Women’s Hockey — Gold Medal Winner", market: "olympics_w_hockey_gold",
                        options: ["USA", "Canada", "Finland", "Sweden", "Other"]),
            makeMCEvent(id: "e03", position: 3, prompt: "Most Total Medals — Country", market: "olympics_most_total_medals",
                        options: ["USA", "Canada", "Norway", "Germany", "Other"]),
            makeMCEvent(id: "e04", position: 4, prompt: "Most Gold Medals — Country", market: "olympics_most_gold_medals",
                        options: ["USA", "Canada", "Norway", "Germany", "Other"]),
            makeMCEvent(id: "e05", position: 5, prompt: "Figure Skating — Men’s Singles Gold", market: "olympics_fs_mens_singles_gold",
                        options: ["USA", "Japan", "France", "Canada", "Other"]),
            makeMCEvent(id: "e06", position: 6, prompt: "Figure Skating — Women’s Singles Gold", market: "olympics_fs_womens_singles_gold",
                        options: ["USA", "Japan", "South Korea", "Russia/Neutral", "Other"]),
            makeMCEvent(id: "e07", position: 7, prompt: "Alpine Skiing — Men’s Downhill Gold", market: "olympics_alpine_m_downhill_gold",
                        options: ["USA", "Switzerland", "Austria", "Norway", "Other"]),
            makeMCEvent(id: "e08", position: 8, prompt: "Snowboarding — Women’s Halfpipe Gold", market: "olympics_snow_w_halfpipe_gold",
                        options: ["USA", "Japan", "China", "Australia", "Other"]),
            makeMCEvent(id: "e09", position: 9, prompt: "Biathlon — Men’s Sprint Gold", market: "olympics_biathlon_m_sprint_gold",
                        options: ["Norway", "France", "Germany", "Sweden", "Other"]),
            makeMCEvent(id: "e10", position: 10, prompt: "Curling — Men’s Gold Medal Winner", market: "olympics_curling_m_gold",
                        options: ["Canada", "Sweden", "Great Britain", "USA", "Other"])
        ]

        let batch = db.batch()

        // 🔥 Important: overwrite the doc so the required fields are definitely present + correctly typed
        batch.setData(challengeData, forDocument: challengeRef, merge: false)

        // Deactivate other active weekly challenges
        let activeSnap = try await db.collection("weekly_challenges")
            .whereField("is_active", isEqualTo: true)
            .getDocuments()

        for d in activeSnap.documents where d.documentID != challengeId {
            batch.setData(["is_active": false], forDocument: d.reference, merge: true)
        }

        // Upsert props
        let propsRef = challengeRef.collection("props")
        for prop in props {
            guard let id = prop["id"] as? String else { continue }
            batch.setData(prop, forDocument: propsRef.document(id), merge: true)
        }

        try await batch.commit()
        print("✅ Seeded weekly_challenges/\(challengeId) with required fields + props.")
    }

    // MARK: - Builders

    private static func makeMCEvent(
        id: String,
        position: Int,
        prompt: String,
        market: String,
        options: [String]
    ) -> [String: Any] {
        let optionDicts: [[String: Any]] = options.enumerated().map { idx, label in
            [
                "id": "opt_\(idx)",
                "position": idx,
                "label": label
            ]
        }

        return [
            "id": id,
            "position": position,
            "kind": "multiple_choice",
            "prompt": prompt,
            "market": market,
            "options": optionDicts,

            // admin updates these as results finalize
            "correct_option_id": NSNull(),
            "is_finalized": false,
            "finalized_at": NSNull(),

            "is_active": true,
            "updated_at": FieldValue.serverTimestamp()
        ]
    }

    private static func makeTimestampLA(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Timestamp {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let comps = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        let date = cal.date(from: comps) ?? Date()
        return Timestamp(date: date)
    }
}
