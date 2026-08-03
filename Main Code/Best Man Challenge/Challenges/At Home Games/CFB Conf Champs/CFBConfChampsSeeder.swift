//
//  CFBConfChampsSeeder.swift
//  Best Man Challenge
//
//  Seeds the CFB Conference Championships game into Firestore.
//
//  USAGE (from the Admin tab or a one-off button):
//      let seeder = CFBConfChampsSeeder()
//      try await seeder.seedAll(phase1Lock: <first Power-4 game date>)
//
//  Firestore layout:
//      at_home_games/cfb_conf_champs_2026                      – tile
//      cfb_conf_champs_2026/data/conferences/{confId}         – config + live state
//      cfb_conf_champs_2026/data/picks/{playerId}            – player entries
//
//  Idempotent: setData(merge: true) so re-running preserves admin-entered
//  finalists/champions and player picks while refreshing config.
//

import Foundation
import FirebaseFirestore

final class CFBConfChampsSeeder {

    private let db = Firestore.firestore()
    private let challengeId = CFBData.challengeId

    // MARK: - Main entry

    /// Creates the at_home_games tile AND seeds all 10 conference config docs.
    /// - Parameter phase1Lock: kickoff of the first Power-4 game (shared Phase 1 lock).
    func seedAll(phase1Lock: Date) async throws {
        try await seedAtHomeTile()
        try await seedConferences(phase1Lock: phase1Lock)
    }

    // MARK: - Tile

    /// Creates (or updates) the at_home_games tile. Starts in "coming_up".
    func seedAtHomeTile() async throws {
        let existing = try await db.collection("at_home_games").getDocuments()
        let maxOrder = existing.documents
            .compactMap { ($0.data()["sortOrder"] as? NSNumber)?.intValue }
            .max() ?? 0

        try await db.collection("at_home_games").document(challengeId).setData([
            "title": "CFB Conf. Champs",
            "assetImage": "CFBConfChampsLogo",
            "route": challengeId,
            "state": "coming_up",
            "sortOrder": maxOrder + 1,
            "challengeId": challengeId,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)

        print("✅ CFB Conf. Champs tile created/updated.")
    }

    // MARK: - Conference config

    /// Writes the 10 conference config docs. Preserves any admin-entered
    /// finalists/champion by using merge (only sets those keys if absent).
    func seedConferences(phase1Lock: Date) async throws {
        let ref = db.collection(challengeId).document("data").collection("conferences")
        let batch = db.batch()

        for def in CFBData.conferences {
            let doc = ref.document(def.id)
            batch.setData([
                "name": def.name,
                "tier": def.tier.rawValue,
                "sortOrder": def.sortOrder,
                "teamIds": def.teamIds,
                "phase1LockAt": Timestamp(date: phase1Lock),
                "seededAt": FieldValue.serverTimestamp()
            ], forDocument: doc, merge: true)
        }

        try await batch.commit()
        print("✅ CFB Conf. Champs: \(CFBData.conferences.count) conferences seeded (\(CFBData.allTeams.count) teams).")
    }

    // MARK: - Convenience

    /// Default Phase 1 lock: first Power-4 game of the 2026 season.
    /// Kept editable in one place — adjust once the exact kickoff is known.
    static var defaultPhase1Lock: Date {
        // Placeholder: Sat, Aug 29, 2026, 12:00 PM ET (Week 0 / opening Saturday).
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 8
        comps.day = 29
        comps.hour = 12
        comps.minute = 0
        comps.timeZone = TimeZone(identifier: "America/New_York")
        return Calendar(identifier: .gregorian).date(from: comps) ?? Date()
    }
}
