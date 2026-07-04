//
//  WeeklyChallengeSeeder2026W27.swift
//  Best Man Challenge
//
//  Week 27: MLB All-Star Challenge (PLACEHOLDER)
//  Dates: Jul 6–12, 2026
//
//  ╔══════════════════════════════════════════════════════════════════╗
//  ║  ⚠️  UPDATE REQUIRED AFTER ALL-STAR ROSTERS DROP               ║
//  ║                                                                  ║
//  ║  1. Replace placeholder description with event details           ║
//  ║  2. Set is_active: true                                          ║
//  ║  3. Seed real MLB All-Star props via seedPropsIfNeeded()         ║
//  ║     (Home Run Derby picks, All-Star Game props, etc.)            ║
//  ║  4. Set locksAt to actual game time                              ║
//  ╚══════════════════════════════════════════════════════════════════╝
//
//  NOTE: This seeder force-overwrites any existing W27 doc (old World Cup
//  content) and clears the old props subcollection on first run.
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

            // Skip only if already seeded with MLB All-Star content
            if snap.exists,
               let title = snap.data()?["title"] as? String,
               title.contains("All-Star") || title.contains("MLB") {
                print("ℹ️ W27 MLB All-Star already seeded — skipping.")
                return
            }

            // Force-overwrite (replaces old World Cup content)
            try await ref.setData(buildChallengeData(), merge: false)
            print("✅ W27 MLB All-Star placeholder seeded.")

            // Clear old World Cup props from subcollection
            await clearOldProps(db: db, challengeId: challengeId)

        } catch {
            print("❌ W27 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    // MARK: - Clear old props

    private static func clearOldProps(db: Firestore, challengeId: String) async {
        let propsRef = db.collection("weekly_challenges").document(challengeId).collection("props")
        do {
            let snap = try await propsRef.getDocuments()
            for doc in snap.documents {
                try await doc.reference.delete()
            }
            if !snap.documents.isEmpty {
                print("🗑️ W27: cleared \(snap.documents.count) old props.")
            }
        } catch {
            print("⚠️ W27 clearOldProps failed:", error.localizedDescription)
        }
    }

    // MARK: - Challenge document

    private static func buildChallengeData() -> [String: Any] {
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 6
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let startDate = calendar.date(from: comps)!

        comps.day = 13
        let endDate = calendar.date(from: comps)!

        return [
            "week": 27,
            "weekInt": 27,
            "title": "Week 27: MLB All-Star Challenge",
            "description": "Props for the Home Run Derby and All-Star Game are dropping soon — we're waiting on rosters and event details. Check back once everything is announced.",
            "type": "prop_bets",
            "game_format": "prop_bets",

            "is_active": false,
            "is_finalized": false,
            "finalized_at": NSNull(),

            "max_points": 10,           // ⚠️ update when real props are set
            "winner_bonus": 1,
            "winner_bonuses_applied": false,
            "winners": [],

            "start_date": Timestamp(date: startDate),
            "end_date": Timestamp(date: endDate),
            // locksAt intentionally omitted — set once game time is confirmed

            "updated_at": FieldValue.serverTimestamp()
        ]
    }

    // MARK: - Props subcollection (call after rosters drop)

    // ⚠️ Fill in once All-Star rosters + event details are announced.
    static func seedPropsIfNeeded(db: Firestore, challengeId: String) async {
        // TODO: Add HRD picks, All-Star Game props, etc.
        print("⚠️ W27 MLB All-Star props not yet seeded — waiting for roster info.")
    }
}
