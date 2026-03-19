import Foundation
import FirebaseFirestore

/// Computes and writes standings for a bracket game based on:
/// - matchups.winnerTeamId (admin-set results)
/// - picks.selections (each player's bracket)
///
/// Writes to: bracket_games/{gameId}/standings/{playerId}
/// Schema:
///   - playerId: String
///   - points: Int
///   - correctByRound: [String:Int]
///   - pointsByRound: [String:Int]
///   - updatedAt: serverTimestamp
final class BMCBracketStandingsService {
    private let db = Firestore.firestore()
    private let directory = PlayerDirectory()

    func recomputeStandings(gameRefId: String) async throws {
        let meta = try await loadMeta(gameRefId: gameRefId)
        let matchups = try await loadMatchups(gameRefId: gameRefId)
        let picksSnap = try await db.collection("bracket_games")
            .document(gameRefId)
            .collection("picks")
            .getDocuments()

        let displayNames = await directory.fetchDisplayNames(playerIds: picksSnap.documents.map { $0.documentID })

        let batch = db.batch()
        let standingsCol = db.collection("bracket_games").document(gameRefId).collection("standings")

        for doc in picksSnap.documents {
            let playerId = doc.documentID
            let data = doc.data()
            let selections = (data["selections"] as? [String: String]) ?? [:]

            let breakdown = BracketEngine.score(picks: selections, matchups: matchups, rules: meta.scoring)

            let correctByRoundStr = Dictionary(uniqueKeysWithValues: breakdown.correctByRound.map { ("\($0.key)", $0.value) })
            let pointsByRoundStr = Dictionary(uniqueKeysWithValues: breakdown.pointsByRound.map { ("\($0.key)", $0.value) })

            let standingRef = standingsCol.document(playerId)

            var payload: [String: Any] = [
                "playerId": playerId,
                "points": breakdown.totalPoints,
                "correctByRound": correctByRoundStr,
                "pointsByRound": pointsByRoundStr,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            if let name = displayNames[playerId] {
                payload["displayName"] = name
            }

            batch.setData(payload, forDocument: standingRef, merge: true)
        }

        try await batch.commit()
    }

    func finalizeGame(gameRefId: String, finalizedBy: String, multiplier: Double = 1.0) async throws {
        try await recomputeStandings(gameRefId: gameRefId)

        let meta = try await loadMeta(gameRefId: gameRefId)
        let standings = try await loadStandings(gameRefId: gameRefId)
        let matchups = try await loadMatchups(gameRefId: gameRefId)

        let scoresByPlayer: [String: Double] = Dictionary(
            uniqueKeysWithValues: standings.map { ($0.playerId, Double($0.points)) }
        )

        let finalizer = ChallengePointsFinalizer()
        try await finalizer.finalizeChallenge(
            challengeId: gameRefId,
            scoresByPlayer: scoresByPlayer,
            multiplier: multiplier,
            higherIsBetter: true
        )

        let gameRef = db.collection("bracket_games").document(gameRefId)
        let finalRef = gameRef.collection("results").document("final")

        let standingsPayload: [[String: Any]] = standings.enumerated().map { idx, row in
            [
                "rank": idx + 1,
                "playerId": row.playerId,
                "displayName": row.displayName ?? "",
                "points": row.points,
                "correctByRound": row.correctByRound,
                "pointsByRound": row.pointsByRound
            ]
        }

        let matchupsPayload: [[String: Any]] = matchups.map { m in
            [
                "id": m.id,
                "round": m.round,
                "gameNumber": m.gameNumber,
                "homeTeamId": m.homeTeamId as Any,
                "awayTeamId": m.awayTeamId as Any,
                "winnerTeamId": m.winnerTeamId as Any
            ]
        }

        try await finalRef.setData([
            "gameRefId": gameRefId,
            "title": meta.title,
            "challengeId": gameRefId,
            "multiplier": multiplier,
            "finalizedBy": finalizedBy,
            "finalizedAt": FieldValue.serverTimestamp(),
            "standings": standingsPayload,
            "matchups": matchupsPayload,
            "scoringByRound": Dictionary(uniqueKeysWithValues: meta.scoring.byRound.map { ("\($0.key)", $0.value) })
        ], merge: true)

        try await gameRef.setData([
            "isFinalized": true,
            "finalizedBy": finalizedBy,
            "finalizedAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    private func loadMeta(gameRefId: String) async throws -> BMCBracketGameMeta {
        let metaSnap = try await db.collection("bracket_games").document(gameRefId).getDocument()
        return BMCBracketGameMeta(id: metaSnap.documentID, data: metaSnap.data() ?? [:])
    }

    private func loadMatchups(gameRefId: String) async throws -> [BMCBracketMatchup] {
        let matchSnap = try await db.collection("bracket_games")
            .document(gameRefId)
            .collection("matchups")
            .getDocuments()

        return matchSnap.documents
            .compactMap { BMCBracketMatchup(id: $0.documentID, data: $0.data()) }
            .sorted {
                if $0.round != $1.round { return $0.round < $1.round }
                return $0.gameNumber < $1.gameNumber
            }
    }

    private func loadStandings(gameRefId: String) async throws -> [BMCBracketStanding] {
        let snap = try await db.collection("bracket_games")
            .document(gameRefId)
            .collection("standings")
            .getDocuments()

        return snap.documents
            .compactMap { BMCBracketStanding(id: $0.documentID, data: $0.data()) }
            .sorted {
                if $0.points != $1.points { return $0.points > $1.points }
                return ($0.displayName ?? $0.playerId) < ($1.displayName ?? $1.playerId)
            }
    }
}
