//
//  VegasOddsFinalizer.swift
//  Best Man Challenge
//

import Foundation
import FirebaseFirestore

/// Finalizes a Vegas Odds event:
/// - Requires results standings to be present.
/// - Settles each bet doc (vegas_odds_bets/{eventId}_{bettorId}).
/// - Recomputes players.vegas_winnings based on the settled bet ledger.
final class VegasOddsFinalizer {

    private let db = Firestore.firestore()

    func finalizeEvent(eventId: String) async throws {
        // 1) Load event config
        let eventSnap = try await db.collection("vegas_odds_events").document(eventId).getDocument()
        guard let eventData = eventSnap.data() else {
            throw NSError(domain: "VegasOdds", code: 404, userInfo: [NSLocalizedDescriptionKey: "Event not found: \(eventId)"])
        }
        let event = VegasOddsEvent(id: eventId, data: eventData)

        // 2) Load standings
        let resultsSnap = try await db.collection("vegas_odds_events").document(eventId)
            .collection("results").document("final")
            .getDocument()
        guard let resultsData = resultsSnap.data() else {
            throw NSError(domain: "VegasOdds", code: 400, userInfo: [NSLocalizedDescriptionKey: "No results found for event \(event.name). Seed results at vegas_odds_events/\(eventId)/results/final"])
        }
        let results = VegasOddsResult(id: eventId, data: resultsData)
        guard results.standings.count >= 3 else {
            throw NSError(domain: "VegasOdds", code: 400, userInfo: [NSLocalizedDescriptionKey: "Standings must include at least 3 players."])
        }

        // 3) Load odds lines (probability-driven)
let oddsSnap = try await db.collection("vegas_odds_events").document(eventId).collection("odds").getDocuments()
var probByPlayer: [String: Double] = [:]
for doc in oddsSnap.documents {
    let line = VegasOddsLine(id: doc.documentID, data: doc.data())
    probByPlayer[line.playerId] = line.top3Probability
}

// 4) Load bets for this event

        let betsSnap = try await db.collection("vegas_odds_bets")
            .whereField("eventId", isEqualTo: eventId)
            .getDocuments()

        // 5) Settle each bet
        let now = FieldValue.serverTimestamp()
        var batch = db.batch()
        var writes = 0

        for doc in betsSnap.documents {
            let bet = VegasOddsBet(id: doc.documentID, data: doc.data())

            // Skip already settled slips (prevents accidental double-finalize)
            if bet.isSettled {
                continue
            }

            // compute effective top 3 by excluding the bettor's own finish (use playerId)
            let effectiveTop3 = computeEffectiveTop3(standings: results.standings, excluding: bet.bettorPlayerId)

            // determine winners
            let winners = bet.picks.filter { effectiveTop3.contains($0) }
            let parlayHit = winners.count == event.maxPicks

            // payout
            let totalWager = Double(event.totalWager)

            var payoutSingles: Double = 0

            for pid in winners {
                let pRaw = probByPlayer[pid] ?? 0.25
                let p = clampProbability(pRaw)
                let dec = OddsMath.decimalOdds(fromProbability: p)
                payoutSingles += Double(event.betPerPick) * dec
            }

            var payoutTotal = payoutSingles

            // If all 3 hit, add a $betPerPick parlay bonus on top of straight payouts.
            // Stake for the parlay is always betPerPick ($100), not totalWager ($300).
            // Payout is ADDITIVE: you keep straight winnings AND collect the parlay.
            if parlayHit {
                let legs: [Double] = bet.picks.map { pid in
                    let pRaw = probByPlayer[pid] ?? 0.25
                    let p = clampProbability(pRaw)
                    return OddsMath.decimalOdds(fromProbability: p)
                }
                let parlayDecimal = legs.reduce(1.0, *)
                let parlayCollect = Double(event.betPerPick) * parlayDecimal
                payoutTotal = payoutSingles + parlayCollect
            }

            let netProfit = payoutTotal - totalWager


            batch.setData([
                "isSettled": true,
                "effectiveTop3": effectiveTop3,
                "winningPicks": winners,
                "parlayHit": parlayHit,
                "payoutTotal": payoutTotal,
                "netProfit": netProfit,
                "settledAt": now,
                "updatedAt": now
            ], forDocument: doc.reference, merge: true)

            writes += 1
            if writes >= 400 {
                try await batch.commit()
                batch = db.batch()
                writes = 0
            }
        }

        if writes > 0 {
            try await batch.commit()
        }

        // 6) Mark event finalized
        try await db.collection("vegas_odds_events").document(eventId).setData([
            "status": "finalized",
            "updatedAt": now
        ], merge: true)

        // 7) Recompute totals (Option B style): players.vegas_winnings from ledger
        try await recomputeAllTotalsFromLedger()
    }

    /// Recompute players.vegas_winnings across ALL settled bets.
    /// This makes the leaderboard always match the bet ledger.
    func recomputeAllTotalsFromLedger() async throws {
        let playersSnap = try await db.collection("players").getDocuments()
        let playerIds = playersSnap.documents.map { $0.documentID }

        for pid in playerIds {
            let betsSnap = try await db.collection("vegas_odds_bets")
                .whereField("bettorPlayerId", isEqualTo: pid)
                .whereField("isSettled", isEqualTo: true)
                .getDocuments()

            let total = betsSnap.documents.reduce(0.0) { partial, d in
                partial + ((d.data()["netProfit"] as? NSNumber)?.doubleValue ?? 0.0)
            }

            try await db.collection("players").document(pid).setData([
                "vegas_winnings": total,
                "updated_at": FieldValue.serverTimestamp()
            ], merge: true)
        }
    }

    // MARK: - Helpers

    
    private func clampProbability(_ p: Double) -> Double {
        // Keep values in a sane range to avoid infinities in odds math.
        return min(max(p, 0.0001), 0.9999)
    }

private func computeEffectiveTop3(standings: [String], excluding playerId: String) -> [String] {
        standings.filter { $0 != playerId }.prefix(3).map { $0 }
    }

    /// Returns total return (stake + profit) for a single pick
    private func payoutForSinglePick(wager: Double, americanOdds: Int) -> Double {
        // American odds:
        // +X: profit = wager * (X/100)
        // -X: profit = wager * (100/abs(X))
        let profit: Double
        if americanOdds >= 0 {
            profit = wager * (Double(americanOdds) / 100.0)
        } else {
            profit = wager * (100.0 / Double(abs(americanOdds)))
        }
        return wager + profit
    }
}