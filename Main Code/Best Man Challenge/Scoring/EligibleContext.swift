//
//  EligibleContext.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/25/26.
//


import Foundation
import FirebaseFirestore

extension ChallengePointsFinalizer {

    /// Finalizes a generic challenge using your baseline + PGA tie rules.
    /// Writes point_awards and recomputes players.total_points.
    ///
    /// - Important:
    ///   - This awards baseline payouts to "players" (linked accounts with role == "player")
    ///   - Owner bonus (+3) goes to anyone strictly above the owner's score (not multiplied)
    ///   - Uses a single idempotent doc per player: "{challengeId}_{playerId}"
    func finalizeChallenge(
        challengeId: String,
        scoresByPlayer: [String: Double],
        multiplier: Double = 1.0,
        higherIsBetter: Bool = true
    ) async throws {

        // 1) Determine eligible players + owner playerId from accounts
        let ctx = try await loadEligibleContextFromAccounts()

        // 2) Filter to eligible (role == "player" only)
        let eligibleScores = scoresByPlayer.filter { pid, _ in
            ctx.eligiblePlayerIds.contains(pid)
        }

        guard !eligibleScores.isEmpty else { return }

        // 3) Compute baseline payouts (PGA tie logic) with multiplier
        let finishGroups = Ranker.makeFinishGroups(scores: eligibleScores, higherIsBetter: higherIsBetter)
        let baseAwards = PayoutEngine.awardPoints(finishGroups: finishGroups, multiplier: multiplier)

        // 4) Owner bonus: +3 to anyone strictly above owner (NOT multiplied)
        var bonusAwards: [String: Double] = [:]
        if let ownerPid = ctx.ownerPlayerId,
           let ownerScore = scoresByPlayer[ownerPid] {

            for (pid, score) in eligibleScores {
                let strictlyBetter = higherIsBetter ? (score > ownerScore) : (score < ownerScore)
                if strictlyBetter {
                    bonusAwards[pid] = 3.0
                }
            }
        }

        // 5) Combine awards
        var combined: [String: (base: Double, bonus: Double, total: Double)] = [:]
        for (pid, _) in eligibleScores {
            let base = baseAwards[pid] ?? 0.0
            let bonus = bonusAwards[pid] ?? 0.0
            combined[pid] = (base: base, bonus: bonus, total: base + bonus)
        }

        // 6) Write point_awards + recompute totals
        try await writeAwardsAndRecomputeTotals(
            challengeId: challengeId,
            multiplier: multiplier,
            awards: combined
        )
    }

    // MARK: - Helpers used by finalizeChallenge

    /// Loaded from /accounts (your existing schema):
    /// - role == "player" → eligible baseline payout
    /// - role == "owner" → ownerPid used for +3 bonus comparison
    fileprivate struct EligibleContext {
        let eligiblePlayerIds: Set<String>
        let ownerPlayerId: String?
    }

    fileprivate func loadEligibleContextFromAccounts() async throws -> EligibleContext {
        let db = Firestore.firestore()
        let snap = try await db.collection("accounts").getDocuments()

        var eligible: Set<String> = []
        var ownerPid: String?

        for doc in snap.documents {
            let data = doc.data()
            let role = (data["role"] as? String) ?? "player"
            let linked = data["linked_player_id"] as? String

            if role == "owner" { ownerPid = linked }

            if role == "player",
               let pid = linked,
               !pid.isEmpty {
                eligible.insert(pid)
            }
        }

        return EligibleContext(eligiblePlayerIds: eligible, ownerPlayerId: ownerPid)
    }

    fileprivate func writeAwardsAndRecomputeTotals(
        challengeId: String,
        multiplier: Double,
        awards: [String: (base: Double, bonus: Double, total: Double)]
    ) async throws {

        let db = Firestore.firestore()
        let awardsRef = db.collection("point_awards")
        let now = FieldValue.serverTimestamp()

        var batch = db.batch()
        var writeCount = 0
        var impacted: [String] = []

        for (pid, a) in awards {
            let docId = "\(challengeId)_\(pid)"
            let ref = awardsRef.document(docId)

            batch.setData([
                "challengeId": challengeId,
                "playerId": pid,
                "multiplier": multiplier,
                "basePoints": a.base,
                "bonusPoints": a.bonus,
                "points": a.total,
                "createdAt": now
            ], forDocument: ref, merge: true)

            impacted.append(pid)
            writeCount += 1

            if writeCount >= 450 {
                try await batch.commit()
                batch = db.batch()
                writeCount = 0
            }
        }

        if writeCount > 0 {
            try await batch.commit()
        }

        try await recomputeTotals(for: impacted)
    }

    fileprivate func recomputeTotals(for playerIds: [String]) async throws {
        let db = Firestore.firestore()

        for pid in playerIds {
            let snap = try await db.collection("point_awards")
                .whereField("playerId", isEqualTo: pid)
                .getDocuments()

            let total = snap.documents.reduce(0.0) { partial, doc in
                partial + ((doc.data()["points"] as? NSNumber)?.doubleValue ?? 0.0)
            }

            try await db.collection("players").document(pid).setData([
                "total_points": total,
                "updated_at": FieldValue.serverTimestamp()
            ], merge: true)
        }
    }
}
