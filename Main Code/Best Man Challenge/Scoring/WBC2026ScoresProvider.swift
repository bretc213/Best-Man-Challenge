//
//  WBC2026ScoresProvider.swift
//  Best Man Challenge
//
//  One-shot fetch wrapper for AdminScoringHub finalizer.
//

import Foundation

struct WBC2026ScoresProvider {
    let store: WBC2026ScoresStore

    /// Returns linkedPlayerId -> totalScore (Double)
    /// - Admin lane entries are ignored (scoped id starts with "admin:")
    func fetchScoresByPlayer(timeoutSeconds: TimeInterval = 6.0) async throws -> [String: Double] {

        await MainActor.run {
            store.startListening()
        }

        let start = Date()
        while Date().timeIntervalSince(start) < timeoutSeconds {
            let rows: [WBCScoreRow] = await MainActor.run { store.scores }
            if !rows.isEmpty {
                return collapseToLinkedPlayers(rows: rows)
            }
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        }

        // Return whatever we have (could be empty if nobody submitted yet)
        let rows: [WBCScoreRow] = await MainActor.run { store.scores }
        return collapseToLinkedPlayers(rows: rows)
    }

    private func collapseToLinkedPlayers(rows: [WBCScoreRow]) -> [String: Double] {
        // We only want REAL player lane entries.
        // Admin lane ids are "admin:<something>" and should not get ledger points.
        let playerRows = rows.filter { !$0.id.hasPrefix("admin:") }

        // Sometimes there could be duplicates for the same linkedPlayerId;
        // keep the highest score just in case.
        var out: [String: Double] = [:]
        for r in playerRows {
            let key = r.linkedPlayerId
            let val = Double(r.score)
            if let existing = out[key] {
                out[key] = max(existing, val)
            } else {
                out[key] = val
            }
        }
        return out
    }
}
