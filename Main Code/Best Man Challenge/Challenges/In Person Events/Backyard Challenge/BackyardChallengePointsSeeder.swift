//
//  BackyardChallengePointsSeeder.swift
//  Best Man Challenge
//
//  Seeds point_awards and increments players.total_points for the
//  Backyard Challenge (May 24, 2026).
//
//  Awards written:
//    • backyard_bucket_golf_bonus  — Isaiah +5, Mitch +3, Valentino +1
//    • backyard_cornhole_bonus     — Joel +5, Danny +3, Mitch +1
//    • backyard_ladderball_bonus   — Mitch +5, Matt C +3, Joel +1
//    • backyard_qb54_bonus         — Mitch +5, Danny +3, Matt C +1
//    • backyard_challenge          — Overall standings (11 players, ×3 baked into basePoints)
//
//  Idempotent: checks for the marker doc before writing. Safe to call multiple times.
//

import Foundation
import FirebaseFirestore

enum BackyardChallengePointsSeeder {

    // Marker: if this doc exists, the seed already ran.
    private static let markerDocId = "backyard_challenge_mitchz"

    // MARK: - Entry point

    static func seedIfNeeded() async {
        let db = Firestore.firestore()

        do {
            let snap = try await db.collection("point_awards")
                .document(markerDocId)
                .getDocument()

            if snap.exists {
                print("ℹ️ Backyard Challenge points already seeded — skipping.")
                return
            }

            try await seed(db: db)
            print("✅ Backyard Challenge points seeded successfully.")
        } catch {
            print("❌ BackyardChallengePointsSeeder.seedIfNeeded failed:", error.localizedDescription)
        }
    }

    // MARK: - Seed

    static func seed(db: Firestore = Firestore.firestore()) async throws {
        let now = FieldValue.serverTimestamp()
        let awards = allAwards(now: now)

        // All awards + player increments fit comfortably under the 500-op batch limit.
        let batch = db.batch()

        for award in awards {
            // Write point_awards/{docId}
            let awardRef = db.collection("point_awards").document(award.docId)
            batch.setData(award.firestoreData, forDocument: awardRef, merge: false)

            // Increment players/{playerId}.total_points
            let playerRef = db.collection("players").document(award.playerId)
            batch.updateData(
                ["total_points": FieldValue.increment(award.totalPoints)],
                forDocument: playerRef
            )
        }

        try await batch.commit()
    }

    // MARK: - Award model

    private struct Award {
        let playerId:       String
        let challengeId:    String
        let challengeTitle: String
        let basePoints:     Double  // already post-multiplication — stored as-is
        let bonusPoints:    Double
        let multiplier:     Int?    // metadata only; no math applied here

        var totalPoints: Double { basePoints + bonusPoints }

        var docId: String { "\(challengeId)_\(playerId)" }

        var firestoreData: [String: Any] {
            [
                "playerId":       playerId,
                "challengeId":    challengeId,
                "challengeTitle": challengeTitle,
                "basePoints":     basePoints,
                "bonusPoints":    bonusPoints,
                "multiplier":     multiplier.map { $0 as Any } ?? NSNull(),
                "points":         totalPoints,
                "createdAt":      FieldValue.serverTimestamp(),
                "updatedAt":      FieldValue.serverTimestamp(),
            ]
        }
    }

    // MARK: - All awards

    private static func allAwards(now: FieldValue) -> [Award] {
        subEventBonusAwards() + overallAwards()
    }

    // MARK: - Sub-event bonus awards
    //   basePoints = 0, bonusPoints = prize, multiplier = nil
    //   points = bonusPoints

    private static func subEventBonusAwards() -> [Award] {
        let events: [(id: String, title: String, entries: [(String, Double)])] = [
            (
                id:    "backyard_bucket_golf_bonus",
                title: "Backyard Challenge — Bucket Golf Bonus",
                entries: [
                    ("isaiahs",    5),
                    ("mitchz",     3),
                    ("valentinom", 1),
                ]
            ),
            (
                id:    "backyard_cornhole_bonus",
                title: "Backyard Challenge — Cornhole Bonus",
                entries: [
                    ("joelr",  5),
                    ("dannyo", 3),
                    ("mitchz", 1),
                ]
            ),
            (
                id:    "backyard_ladderball_bonus",
                title: "Backyard Challenge — Ladder Ball Bonus",
                entries: [
                    ("mitchz",   5),
                    ("matthewc", 3),
                    ("joelr",    1),
                ]
            ),
            (
                id:    "backyard_qb54_bonus",
                title: "Backyard Challenge — QB54 Bonus",
                entries: [
                    ("mitchz",   5),
                    ("dannyo",   3),
                    ("matthewc", 1),
                ]
            ),
        ]

        return events.flatMap { event in
            event.entries.map { (playerId, bonus) in
                Award(
                    playerId:       playerId,
                    challengeId:    event.id,
                    challengeTitle: event.title,
                    basePoints:     0,
                    bonusPoints:    bonus,
                    multiplier:     nil
                )
            }
        }
    }

    // MARK: - Overall backyard challenge awards
    //   basePoints = raw rank value (no multiplication — multiplier field is metadata only)
    //   multiplier = 3 (display only)
    //   Mitch gets +3 bonus for finishing above Bret (host / no award)
    //
    //   points = basePoints + bonusPoints
    //
    //   Mitch:     45 + 3 = 48
    //   Joel:      36
    //   Isaiah:    30
    //   Danny:     24
    //   Matt C.:   19.5
    //   Valentino: 19.5
    //   Matt P.:   15
    //   Ronnie:    12
    //   Jake:       9
    //   Kyle:       6
    //   Anthony:    3

    private static func overallAwards() -> [Award] {
        let entries: [(playerId: String, base: Double, bonus: Double)] = [
            ("mitchz",     45,   3),
            ("joelr",      36,   0),
            ("isaiahs",    30,   0),
            ("dannyo",     24,   0),
            ("matthewc",   19.5, 0),
            ("valentinom", 19.5, 0),
            ("matthewp",   15,   0),
            ("ronaldp",    12,   0),
            ("jakeo",       9,   0),
            ("kylel",       6,   0),
            ("anthonyc",    3,   0),
        ]

        return entries.map { entry in
            Award(
                playerId:       entry.playerId,
                challengeId:    "backyard_challenge",
                challengeTitle: "Backyard Challenge — Overall",
                basePoints:     entry.base,
                bonusPoints:    entry.bonus,
                multiplier:     3
            )
        }
    }
}
