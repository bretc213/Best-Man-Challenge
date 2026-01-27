//
//  NFLPlayoffsScoresProvider.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/24/26.
//


import Foundation

/// Pulls the same standings your NFL leaderboard UI shows.
/// Uses the groomsmen lane only (no "admin:" ids).
@MainActor
final class NFLPlayoffsScoresProvider {
    private let store: NFLPlayoffsScoresStore

    init(store: NFLPlayoffsScoresStore) {
        self.store = store
    }

    func fetchScoresByPlayer() async throws -> [String: Double] {
        store.startListening()

        // Wait until either rows exist or loading finished.
        try await AsyncWait.until(timeoutSeconds: 10) {
            !self.store.scores.isEmpty || self.store.isLoading == false
        }

        // Only pay out the groomsmen lane
        let groomsmenRows = store.scores.filter {
            store.groupForPlayerId($0.linkedPlayerId) == .groomsmen
        }

        var map: [String: Double] = [:]
        for r in groomsmenRows {
            // linkedPlayerId is the real playerId for groomsmen lane
            map[r.linkedPlayerId] = Double(r.points)
        }

        return map
    }
}
