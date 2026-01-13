// this doesn't run, task to run this seeder is commented out

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W02 {

    static let didSeedKey = "didSeedWeeklyChallenge_2026_w02"

    /// Call this on app launch. It will seed once and then never again.
    static func seedIfNeeded() async {
        // ✅ Local guard (prevents repeated overwrites)
        if UserDefaults.standard.bool(forKey: didSeedKey) {
            print("ℹ️ Week 2 already seeded (UserDefaults).")
            return
        }

        do {
            try await seedQuizOnce()
            UserDefaults.standard.set(true, forKey: didSeedKey)
            print("✅ Week 2 seeded and flag saved.")
        } catch {
            print("❌ Week 2 seed failed:", error.localizedDescription)
        }
    }

    /// Seeds the document only if it doesn't already exist.
    private static func seedQuizOnce() async throws {
        let db = Firestore.firestore()
        let ref = db.collection("weekly_challenges").document("2026_w02")

        // ✅ Firestore guard (prevents overwriting if doc already exists)
        let existing = try await ref.getDocument()
        if existing.exists {
            print("ℹ️ weekly_challenges/2026_w02 already exists. Skipping seed.")
            return
        }

        func makeOUQuestion(id: String, prompt: String) -> [String: Any] {
            [
                "id": id,
                "prompt": prompt,
                "options": ["OVER", "UNDER"],
                "correct_index": NSNull() // unknown until games complete
            ]
        }

        let questions: [[String: Any]] = [
            makeOUQuestion(id: "q1",  prompt: "Broncos vs Bills — Total Points (46.5)"),
            makeOUQuestion(id: "q2",  prompt: "Seahawks vs 49ers — Total Points (45.5)"),
            makeOUQuestion(id: "q3",  prompt: "Patriots vs Texans — Total Points (43.5)"),
            makeOUQuestion(id: "q4",  prompt: "Bears vs Rams — Total Points (50.5)"),
            makeOUQuestion(id: "q5",  prompt: "Puka Nacua — Receiving Yards (100.5)"),
            makeOUQuestion(id: "q6",  prompt: "Caleb Williams — Passing Yards (230.5)"),
            makeOUQuestion(id: "q7",  prompt: "Jaxon Smith-Njigba — Receiving Yards (91.5)"),
            makeOUQuestion(id: "q8",  prompt: "Christian McCaffrey — Receiving Yards (48.5)"),
            makeOUQuestion(id: "q9",  prompt: "Josh Allen — Rushing Yards (37.5)"),
            makeOUQuestion(id: "q10", prompt: "Courtland Sutton — Receiving Yards (48.5)"),
            makeOUQuestion(id: "q11", prompt: "Drake Maye — Passing Yards (232.5)"),
            makeOUQuestion(id: "q12", prompt: "CJ Stroud — Total Turnovers (1.5)")
        ]

        // Use your timestamps (you can change these later)
        let start = Timestamp(date: Date(timeIntervalSince1970: 1736553600))
        let end   = Timestamp(date: Date(timeIntervalSince1970: 1737072000))

        let data: [String: Any] = [
            "week": 2,
            "title": "NFL Divisional Round Props",
            "description": "Pick OVER or UNDER for each prop based on this weekend’s playoff games.",
            "type": "quiz",
            "startDate": start,
            "endDate": end,
            "is_active": true,
            "quiz": [
                "points_per_correct": 1,
                "questions": questions
            ],
            "updated_at": FieldValue.serverTimestamp()
        ]

        // ✅ Create (no overwrite because we checked exists)
        try await ref.setData(data, merge: false)

        // ✅ Optional: deactivate week 1
        try await db.collection("weekly_challenges")
            .document("2026_w01")
            .setData(["is_active": false], merge: true)

        print("✅ Seeded weekly_challenges/2026_w02 and deactivated 2026_w01.")
    }
}
