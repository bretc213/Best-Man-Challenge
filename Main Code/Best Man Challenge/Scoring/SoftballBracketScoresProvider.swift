//
//  SoftballBracketScoresProvider.swift
//  Best Man Challenge
//
//  One-shot fetch wrapper for AdminScoringHub finalizer.
//  Mirrors WBC2026ScoresProvider / NFLPlayoffsScoresProvider pattern.
//

import Foundation
import FirebaseFirestore

struct SoftballBracketScoresProvider {

    let challengeId: String
    private let db = Firestore.firestore()

    init(challengeId: String = SoftballBracketConfig.challengeId) {
        self.challengeId = challengeId
    }

    /// Returns submitterId -> totalScore (Double)
    /// Admin-lane entries (submitterId starts with "admin_") are excluded.
    func fetchScoresByPlayer() async throws -> [String: Double] {
        let bracketRef = db.collection("softball_brackets").document(challengeId)

        // 1) Fetch bracket doc (config + results)
        let bracketSnap = try await bracketRef.getDocument()
        guard bracketSnap.exists, let bracketData = bracketSnap.data() else {
            throw NSError(
                domain: "SoftballBracketScoresProvider",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "softball_brackets/\(challengeId) not found. Run the seeder first."]
            )
        }

        // Decode config
        let config: SoftballBracketConfig
        do {
            config = try bracketSnap.data(as: SoftballBracketConfig.self)
        } catch {
            throw NSError(
                domain: "SoftballBracketScoresProvider",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not decode softball config: \(error.localizedDescription)"]
            )
        }

        // Decode results (inlined to avoid @MainActor isolation on SoftballBracketStore)
        let results: SoftballBracketResults
        if let resultsData = bracketData["results"] as? [String: Any] {
            results = SoftballBracketResults(
                regionalWinners: resultsData["regionalWinners"] as? [String: String] ?? [:],
                superRegionalWinners: resultsData["superRegionalWinners"] as? [String: String] ?? [:],
                finalists: resultsData["finalists"] as? [String] ?? [],
                champion: resultsData["champion"] as? String,
                finalizedAt: resultsData["finalizedAt"] as? Timestamp
            )
        } else {
            results = .empty
        }

        guard results.champion != nil else {
            throw NSError(
                domain: "SoftballBracketScoresProvider",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "WCWS bracket is not finalized yet — no champion set."]
            )
        }

        // 2) Fetch all picks
        let picksSnap = try await bracketRef.collection("picks").getDocuments()
        let allPicks: [SoftballBracketPicks] = picksSnap.documents.compactMap {
            try? $0.data(as: SoftballBracketPicks.self)
        }

        guard !allPicks.isEmpty else {
            throw NSError(
                domain: "SoftballBracketScoresProvider",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "No picks found under softball_brackets/\(challengeId)/picks."]
            )
        }

        // 3) Load all eligible player IDs from accounts
        //    (role == "player" with a linked_player_id)
        let accountsSnap = try await db.collection("accounts").getDocuments()
        var eligiblePlayerIds: Set<String> = []
        for doc in accountsSnap.documents {
            let data = doc.data()
            let role = (data["role"] as? String) ?? "player"
            guard role == "player",
                  let pid = data["linked_player_id"] as? String,
                  !pid.isEmpty else { continue }
            eligiblePlayerIds.insert(pid)
        }

        // 4) Build a temporary scorer (no listeners needed)
        let scorer = SoftballBracketInlineScorer(config: config, results: results)

        // 5) Map picks -> scores, skip admin lanes
        var out: [String: Double] = [:]
        for picks in allPicks {
            let pid = picks.submitterId
            guard !pid.hasPrefix("admin_") else { continue }

            let row = scorer.scoreRow(for: picks)
            let score = Double(row.total)

            if let existing = out[pid] {
                out[pid] = max(existing, score)
            } else {
                out[pid] = score
            }
        }

        // 6) Any eligible player who never submitted gets -1 so the Ranker
        //    places them tied for last. PGA tie averaging then gives them
        //    their fair share of the bottom baseline slots (e.g. 2.5 pts each
        //    when 4 players share slots 8–11).
        for pid in eligiblePlayerIds where out[pid] == nil {
            out[pid] = -1
        }

        return out
    }
}

// MARK: - Inline scorer (no @MainActor / ObservableObject needed)

/// Pure value-type scorer so we don't need to spin up the full ObservableObject store.
private struct SoftballBracketInlineScorer {
    let config: SoftballBracketConfig
    let results: SoftballBracketResults

    func scoreRow(for picks: SoftballBracketPicks) -> SoftballLeaderboardRow {
        var regionalPoints = 0
        var superPoints = 0
        var finalistPoints = 0
        var championPoints = 0

        for regional in config.regionals {
            if let official = results.regionalWinners[regional.id],
               picks.regionalWinners[regional.id] == official {
                regionalPoints += config.regionalPoints
            }
        }

        for pair in SoftballBracketConfig.superRegionalPairings {
            let id = SoftballBracketHelpers.superRegionalId(seedA: pair.0, seedB: pair.1)
            if let official = results.superRegionalWinners[id],
               picks.superRegionalWinners[id] == official {
                superPoints += config.superRegionalPoints
            }
        }

        if results.finalists.count == 2 {
            for pickedFinalist in picks.finalists {
                if results.finalists.contains(pickedFinalist) {
                    finalistPoints += config.finalistPoints
                }
            }
        }

        if let officialChampion = results.champion,
           picks.champion == officialChampion {
            championPoints += config.championPoints
        }

        let total = regionalPoints + superPoints + finalistPoints + championPoints

        return SoftballLeaderboardRow(
            submitterId: picks.submitterId,
            displayName: picks.displayName,
            regionalPoints: regionalPoints,
            superRegionalPoints: superPoints,
            finalistPoints: finalistPoints,
            championPoints: championPoints,
            total: total,
            maxRemaining: total
        )
    }
}
