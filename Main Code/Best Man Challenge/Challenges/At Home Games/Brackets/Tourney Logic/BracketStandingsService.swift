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
        // Load scoring rules (optional)
        let metaSnap = try await db.collection("bracket_games").document(gameRefId).getDocument()
        let metaData = metaSnap.data() ?? [:]
        let rules = BMCBracketScoringRules(data: metaData["scoring"] as? [String: Any])

        // Load matchups (results live here)
        let matchSnap = try await db.collection("bracket_games")
            .document(gameRefId)
            .collection("matchups")
            .getDocuments()

        let matchups = matchSnap.documents.compactMap { BMCBracketMatchup(id: $0.documentID, data: $0.data()) }

        // Load all picks
        let picksSnap = try await db.collection("bracket_games")
            .document(gameRefId)
            .collection("picks")
            .getDocuments()

        let displayNames = await directory.fetchDisplayNames(playerIds: picksSnap.documents.map { $0.documentID })

        // Batch write standings
        let batch = db.batch()
        let standingsCol = db.collection("bracket_games").document(gameRefId).collection("standings")

        for doc in picksSnap.documents {
            let playerId = doc.documentID
            let data = doc.data()
            let selections = (data["selections"] as? [String: String]) ?? [:]

            let breakdown = BracketEngine.score(picks: selections, matchups: matchups, rules: rules)

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
}
