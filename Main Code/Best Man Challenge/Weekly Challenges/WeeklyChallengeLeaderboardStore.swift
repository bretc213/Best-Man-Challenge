//
//  WeeklyChallengeStanding.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/2/26.
//

import Foundation
import FirebaseFirestore

struct WeeklyChallengeStanding: Identifiable {
    let id: String              // playerId
    let displayName: String
    let points: Int
    let hasSubmitted: Bool
}

@MainActor
final class WeeklyChallengeLeaderboardStore: ObservableObject {
    @Published var standings: [WeeklyChallengeStanding] = []
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var playersListener: ListenerRegistration?
    private var submissionsListener: ListenerRegistration?

    private var playersById: [String: String] = [:]    // playerId -> displayName
    private var scoresByPlayerId: [String: Int] = [:]  // playerId -> score

    // ✅ Excluded from weekly standings (owner)
    private let excludedPlayerIds: Set<String> = ["bretc"]

    func startListening(weekId: String) {
        stopListening()
        errorMessage = nil

        // 1) Listen to all players
        playersListener = db.collection("players")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    self.errorMessage = err.localizedDescription
                    return
                }

                var map: [String: String] = [:]
                for doc in snap?.documents ?? [] {
                    let data = doc.data()
                    let name =
                        (data["display_name"] as? String)
                        ?? (data["name"] as? String)
                        ?? doc.documentID

                    map[doc.documentID] = name
                }

                self.playersById = map
                self.rebuildStandings()
            }

        // 2) Listen to submissions for the week
        submissionsListener = db.collection("weekly_challenges")
            .document(weekId)
            .collection("submissions")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    self.errorMessage = err.localizedDescription
                    return
                }

                var scores: [String: Int] = [:]
                for doc in snap?.documents ?? [] {
                    let data = doc.data()
                    guard let linked = data["linked_player_id"] as? String else { continue }
                    let score = (data["score"] as? Int) ?? 0
                    scores[linked] = score
                }

                self.scoresByPlayerId = scores
                self.rebuildStandings()
            }
    }

    func stopListening() {
        playersListener?.remove()
        playersListener = nil
        submissionsListener?.remove()
        submissionsListener = nil
    }

    private func rebuildStandings() {
        guard !playersById.isEmpty else {
            standings = []
            return
        }

        let all = playersById.compactMap { (playerId, displayName) -> WeeklyChallengeStanding? in
            // ✅ Remove Bret from weekly standings
            if excludedPlayerIds.contains(playerId) {
                return nil
            }

            let score = scoresByPlayerId[playerId] ?? 0
            let submitted = scoresByPlayerId[playerId] != nil

            return WeeklyChallengeStanding(
                id: playerId,
                displayName: displayName,
                points: score,
                hasSubmitted: submitted
            )
        }

        standings = all.sorted {
            if $0.points != $1.points { return $0.points > $1.points }
            return $0.displayName < $1.displayName
        }
    }
}
