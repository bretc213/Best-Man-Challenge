import Foundation
import FirebaseFirestore

final class MastersDraftService {
    private let db = Firestore.firestore()
    private let directory = PlayerDirectory()

    func draftGolfer(gameRefId: String, playerId: String, golferId: String) async throws {
        let gameRef = db.collection("masters_drafts").document(gameRefId)
        let golferRef = gameRef.collection("golfers").document(golferId)
        let rosterRef = gameRef.collection("rosters").document(playerId)

        let displayNames = await directory.fetchDisplayNames(playerIds: [playerId])
        let playerDisplayName = displayNames[playerId] ?? playerId

        try await db.runTransaction { transaction, errorPointer in
            do {
                let gameSnap = try transaction.getDocument(gameRef)
                let golferSnap = try transaction.getDocument(golferRef)
                let rosterSnap = try? transaction.getDocument(rosterRef)

                let meta = MastersDraftMeta(id: gameSnap.documentID, data: gameSnap.data() ?? [:])
                let golfer = MastersGolfer(id: golferSnap.documentID, data: golferSnap.data() ?? [:])

                guard !meta.isFinalized else {
                    throw NSError(domain: "MastersDraft", code: 1, userInfo: [NSLocalizedDescriptionKey: "Draft already finalized."])
                }
                guard meta.state == "live_draft" else {
                    throw NSError(domain: "MastersDraft", code: 2, userInfo: [NSLocalizedDescriptionKey: "Draft is not currently live."])
                }
                guard meta.currentDrafterPlayerId == playerId else {
                    throw NSError(domain: "MastersDraft", code: 3, userInfo: [NSLocalizedDescriptionKey: "It is not your turn."])
                }
                guard !golfer.isDrafted else {
                    throw NSError(domain: "MastersDraft", code: 4, userInfo: [NSLocalizedDescriptionKey: "That golfer has already been drafted."])
                }

                let currentPick = max(1, meta.currentOverallPick)
                let slot = MastersDraftScoring.snakePlayerId(
                    order: meta.draftOrder,
                    overallPick: currentPick,
                    roundCount: meta.roundCount
                )
                guard slot.playerId == playerId else {
                    throw NSError(domain: "MastersDraft", code: 5, userInfo: [NSLocalizedDescriptionKey: "Draft order moved. Please refresh."])
                }

                let now = Date()
                let nextOverallPick = currentPick + 1
                let nextSlot = MastersDraftScoring.snakePlayerId(
                    order: meta.draftOrder,
                    overallPick: nextOverallPick,
                    roundCount: meta.roundCount
                )
                let draftIsComplete = nextOverallPick > meta.totalPicks

                transaction.setData([
                    "isDrafted": true,
                    "draftedByPlayerId": playerId,
                    "draftRound": slot.round,
                    "overallPick": currentPick,
                    "status": "drafted",
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: golferRef, merge: true)

                let rosterData = rosterSnap?.data() ?? [:]
                var golferIds = (rosterData["golferIds"] as? [String]) ?? []
                var picks = (rosterData["picks"] as? [[String: Any]]) ?? []

                golferIds.append(golferId)
                picks.append([
                    "golferId": golferId,
                    "golferName": golfer.name,
                    "round": slot.round,
                    "overallPick": currentPick,
                    "draftedAt": Timestamp(date: now)
                ])

                transaction.setData([
                    "playerId": playerId,
                    "displayName": playerDisplayName,
                    "golferIds": golferIds,
                    "picks": picks,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: rosterRef, merge: true)

                var gamePayload: [String: Any] = [
                    "currentOverallPick": draftIsComplete ? meta.totalPicks : nextOverallPick,
                    "currentRound": draftIsComplete ? meta.roundCount : nextSlot.round,
                    "state": draftIsComplete ? "live_scoring" : "live_draft",
                    "lastUpdated": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ]

                if draftIsComplete {
                    gamePayload["currentDrafterPlayerId"] = FieldValue.delete()
                    gamePayload["draftCompletedAt"] = FieldValue.serverTimestamp()
                } else if let nextPlayerId = nextSlot.playerId {
                    gamePayload["currentDrafterPlayerId"] = nextPlayerId
                } else {
                    gamePayload["currentDrafterPlayerId"] = FieldValue.delete()
                }

                transaction.setData(gamePayload, forDocument: gameRef, merge: true)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            return nil
        }
    }

    func recomputeStandings(gameRefId: String) async throws {
        let gameRef = db.collection("masters_drafts").document(gameRefId)
        let golfersSnap = try await gameRef.collection("golfers").getDocuments()
        let rostersSnap = try await gameRef.collection("rosters").getDocuments()

        var golferPointsById: [String: Int] = [:]
        let batch = db.batch()

        for doc in golfersSnap.documents {
            let golfer = MastersGolfer(id: doc.documentID, data: doc.data())
            let points = MastersDraftScoring.points(for: golfer.position, status: golfer.status)
            golferPointsById[golfer.id] = points

            batch.setData([
                "leaderboardPoints": points,
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: doc.reference, merge: true)
        }

        let standingsCol = gameRef.collection("standings")
        for doc in rostersSnap.documents {
            let roster = MastersRoster(id: doc.documentID, data: doc.data())
            let perGolfer = Dictionary(uniqueKeysWithValues: roster.golferIds.map { ($0, golferPointsById[$0] ?? 0) })
            let total = perGolfer.values.reduce(0, +)

            var standingPayload: [String: Any] = [
                "playerId": roster.playerId,
                "points": total,
                "golferPoints": perGolfer,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            if let displayName = roster.displayName {
                standingPayload["displayName"] = displayName
            }

            batch.setData(standingPayload, forDocument: standingsCol.document(roster.playerId), merge: true)

            batch.setData([
                "totalPoints": total,
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: doc.reference, merge: true)
        }

        batch.setData([
            "lastUpdated": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: gameRef, merge: true)

        try await batch.commit()
    }

    func finalizeChallenge(gameRefId: String, finalizedBy: String) async throws {
        try await recomputeStandings(gameRefId: gameRefId)

        let gameRef = db.collection("masters_drafts").document(gameRefId)
        let metaSnap = try await gameRef.getDocument()
        let meta = MastersDraftMeta(id: metaSnap.documentID, data: metaSnap.data() ?? [:])

        let standingsSnap = try await gameRef.collection("standings").getDocuments()
        let standings = standingsSnap.documents
            .map { MastersStanding(id: $0.documentID, data: $0.data()) }
            .sorted {
                if $0.points != $1.points { return $0.points > $1.points }
                return ($0.displayName ?? $0.playerId) < ($1.displayName ?? $1.playerId)
            }

        let scoresByPlayer = Dictionary(uniqueKeysWithValues: standings.map { ($0.playerId, Double($0.points)) })
        let finalizer = ChallengePointsFinalizer()
        try await finalizer.finalizeChallenge(
            challengeId: gameRefId,
            scoresByPlayer: scoresByPlayer,
            multiplier: meta.pointsMultiplier,
            higherIsBetter: true
        )

        let resultPayload: [[String: Any]] = standings.enumerated().map { idx, standing in
            [
                "rank": idx + 1,
                "playerId": standing.playerId,
                "displayName": standing.displayName ?? "",
                "points": standing.points,
                "golferPoints": standing.golferPoints
            ]
        }

        try await gameRef.collection("results").document("final").setData([
            "challengeId": gameRefId,
            "title": meta.title,
            "finalizedBy": finalizedBy,
            "finalizedAt": FieldValue.serverTimestamp(),
            "pointsMultiplier": meta.pointsMultiplier,
            "standings": resultPayload
        ], merge: true)

        try await gameRef.setData([
            "state": "finalized",
            "isFinalized": true,
            "finalizedBy": finalizedBy,
            "finalizedAt": FieldValue.serverTimestamp(),
            "lastUpdated": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)

        if let atHomeGameId = meta.atHomeGameId, !atHomeGameId.isEmpty {
            try? await db.collection("at_home_games").document(atHomeGameId).setData([
                "state": "archived",
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        }
    }
}
