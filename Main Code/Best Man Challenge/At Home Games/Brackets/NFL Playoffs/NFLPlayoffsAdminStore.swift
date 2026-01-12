//
//  NFLPlayoffsAdminStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/5/26.
//

import Foundation
import FirebaseFirestore

@MainActor
final class NFLPlayoffsAdminStore: ObservableObject {

    private let db = Firestore.firestore()
    let bracketId: String

    init(bracketId: String = "nfl_2026_playoffs") {
        self.bracketId = bracketId
    }

    // MARK: - Winners

    func setWinner(matchupId: String, winnerTeamId: String) async throws {
        let ref = db.collection("brackets")
            .document(bracketId)
            .collection("matchups")
            .document(matchupId)

        try await ref.setData([
            "winnerTeamId": winnerTeamId,
            "decidedAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ], merge: true)
    }

    /// Reset a game's winner back to "undecided" (nil).
    /// Uses FieldValue.delete() so the fields are truly removed (not set to "").
    func resetWinner(matchupId: String) async throws {
        let ref = db.collection("brackets")
            .document(bracketId)
            .collection("matchups")
            .document(matchupId)

        try await ref.updateData([
            "winnerTeamId": FieldValue.delete(),
            "decidedAt": FieldValue.delete(),
            "updatedAt": Timestamp(date: Date())
        ])
    }

    // MARK: - Scores

    /// Recompute total scores across ALL rounds for all players.
    /// Reads:
    /// - matchups (all rounds)
    /// - picks (all rounds, all players)
    /// Writes:
    /// - scores/{playerId}
    func recomputeScores(points: BracketPoints) async throws {

        // 1) Load all matchups
        let matchupsSnap = try await db.collection("brackets")
            .document(bracketId)
            .collection("matchups")
            .getDocuments()

        let matchups: [BracketMatchup] = matchupsSnap.documents.compactMap { doc in
            let d = doc.data()
            guard
                let roundRaw = d["round"] as? String,
                let round = BracketRound(rawValue: roundRaw),
                let index = d["index"] as? Int,
                let awayMap = d["away"] as? [String: Any],
                let homeMap = d["home"] as? [String: Any],
                let startsAt = (d["startsAt"] as? Timestamp)?.dateValue(),
                let lockAt = (d["lockAt"] as? Timestamp)?.dateValue(),
                let revealAt = (d["revealAt"] as? Timestamp)?.dateValue(),
                let awayId = awayMap["id"] as? String,
                let awayName = awayMap["name"] as? String,
                let homeId = homeMap["id"] as? String,
                let homeName = homeMap["name"] as? String
            else { return nil }

            let away = MatchupTeam(id: awayId, name: awayName, logoAsset: awayMap["logoAsset"] as? String)
            let home = MatchupTeam(id: homeId, name: homeName, logoAsset: homeMap["logoAsset"] as? String)

            // NOTE: If you applied your Step B parsing change elsewhere, you can mirror it here if desired.
            // For scoring, "nil/empty" should not count as decided.
            let winnerRaw = d["winnerTeamId"] as? String
            let winner = (winnerRaw?.isEmpty == false) ? winnerRaw : nil

            return BracketMatchup(
                id: doc.documentID,
                round: round,
                index: index,
                away: away,
                home: home,
                tv: d["tv"] as? String,
                startsAt: startsAt,
                lockAt: lockAt,
                revealAt: revealAt,
                winnerTeamId: winner,
                decidedAt: (d["decidedAt"] as? Timestamp)?.dateValue()
            )
        }

        // Only score decided games
        let decided = matchups.filter { $0.winnerTeamId != nil }
        let winnerByMatchup: [String: (round: BracketRound, winner: String)] = Dictionary(
            uniqueKeysWithValues: decided.compactMap { m in
                guard let w = m.winnerTeamId else { return nil }
                return (m.id, (m.round, w))
            }
        )

        // 2) Load picks for all rounds, all players
        // Round docs are: brackets/{id}/picks/{roundId}/players/*
        let roundsSnap = try await db.collection("brackets")
            .document(bracketId)
            .collection("picks")
            .getDocuments()

        let roundIds = roundsSnap.documents.map { $0.documentID }

        // Aggregate: playerId -> (displayName, picks map)
        var playerDisplay: [String: String] = [:]
        var playerPicks: [String: [String: String]] = [:] // matchupId -> teamId

        for r in roundIds {
            let playersSnap = try await db.collection("brackets")
                .document(bracketId)
                .collection("picks")
                .document(r)
                .collection("players")
                .getDocuments()

            for doc in playersSnap.documents {
                let d = doc.data()
                let pid = doc.documentID
                let dn = d["displayName"] as? String ?? pid
                playerDisplay[pid] = dn

                let picks = d["picks"] as? [String: String] ?? [:]
                var current = playerPicks[pid] ?? [:]
                for (k, v) in picks { current[k] = v }
                playerPicks[pid] = current
            }
        }

        // 3) Compute + write scores
        let scoresRef = db.collection("brackets").document(bracketId).collection("scores")

        let batch = db.batch()
        let now = Timestamp(date: Date())

        for (pid, picks) in playerPicks {
            var total = 0
            var correct = 0

            var breakdown: [String: Int] = [
                "wildcard": 0,
                "divisional": 0,
                "conference": 0,
                "superBowl": 0
            ]

            for (matchupId, meta) in winnerByMatchup {
                let round = meta.round
                let winner = meta.winner

                if picks[matchupId] == winner {
                    correct += 1
                    let pts = points.points(for: round)
                    total += pts
                    breakdown[round.rawValue, default: 0] += pts
                }
            }

            let docRef = scoresRef.document(pid)
            batch.setData([
                "linkedPlayerId": pid,
                "displayName": playerDisplay[pid] ?? pid,
                "points": total,
                "correct": correct,
                "breakdown": breakdown,
                "updatedAt": now
            ], forDocument: docRef, merge: true)
        }

        try await batch.commit()
    }
}
