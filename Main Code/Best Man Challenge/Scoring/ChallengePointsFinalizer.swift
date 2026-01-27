//
//  ChallengePointsFinalizer.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/24/26.
//

import Foundation
import FirebaseFirestore

enum ChallengeFinalizerError: LocalizedError {
    case missingWinners
    case weeklyNotFinalized
    case noSubmissionsFound

    var errorDescription: String? {
        switch self {
        case .missingWinners:
            return "No winners found for this weekly challenge."
        case .weeklyNotFinalized:
            return "Weekly challenge is not finalized yet."
        case .noSubmissionsFound:
            return "No submissions found for this weekly challenge."
        }
    }
}

final class ChallengePointsFinalizer {

    private let db = Firestore.firestore()

    // MARK: - Weekly Winner Bonus (+1)

    /// Applies +winner_bonus points to EVERY tied winner for a weekly challenge.
    ///
    /// Idempotent:
    /// - writes point_awards docs using deterministic ids so re-running is safe
    /// - sets weekly_challenges/<id>.winner_bonuses_applied = true
    ///
    /// Winner discovery:
    /// - If weekly_challenges/<id>.winners exists + non-empty, uses it
    /// - Else computes winners from weekly_challenges/<id>/submissions by max score
    ///
    /// Expected weekly fields (from your docs):
    /// - title (String)
    /// - week (Int)
    /// - winner_bonus (Int) default 1
    /// - is_finalized (Bool)
    /// - winner_bonuses_applied (Bool)
    /// - winners ([String]) optional
    func applyWeeklyWinnerBonus(weeklyId: String) async throws {
        let weeklyRef = db.collection("weekly_challenges").document(weeklyId)
        let weeklySnap = try await weeklyRef.getDocument()
        let weekly = weeklySnap.data() ?? [:]

        let title = (weekly["title"] as? String) ?? weeklyId
        let weekNum = (weekly["week"] as? NSNumber)?.intValue ?? 0
        let isFinalized = (weekly["is_finalized"] as? Bool) ?? false
        let bonus = (weekly["winner_bonus"] as? NSNumber)?.doubleValue ?? 1.0

        // Require finalized (matches your intent)
        guard isFinalized else { throw ChallengeFinalizerError.weeklyNotFinalized }

        // Who is NOT eligible to win weekly bonus
        let excluded: Set<String> = ["bretc"]

        // Previously applied winners (for idempotent re-apply / cleanup)
        let previouslyApplied: [String] = (weekly["applied_winner_bonus_players"] as? [String]) ?? []
        let prevSet = Set(previouslyApplied)

        // 1) Prefer explicit winners list if present
        var winners: [String] = (weekly["winners"] as? [String]) ?? []
        winners = winners
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { !excluded.contains($0) } // exclude bretc even if explicitly listed

        // 2) Otherwise compute from submissions with Option A behavior
        if winners.isEmpty {
            let subsSnap = try await weeklyRef.collection("submissions").getDocuments()
            let docs = subsSnap.documents
            guard !docs.isEmpty else { throw ChallengeFinalizerError.noSubmissionsFound }

            func extractScore(_ data: [String: Any]) -> Double? {
                (data["score"] as? NSNumber)?.doubleValue
            }

            // Build scores by playerId
            var scoresByPlayer: [String: Double] = [:]

            for doc in docs {
                let d = doc.data()
                let pid =
                    (d["playerId"] as? String) ??
                    (d["player_id"] as? String) ??
                    (d["linked_player_id"] as? String) ??
                    doc.documentID

                guard !excluded.contains(pid) else { continue }
                guard let s = extractScore(d) else { continue }

                // If multiple subs per player ever exist, keep the max
                if let existing = scoresByPlayer[pid] {
                    scoresByPlayer[pid] = max(existing, s)
                } else {
                    scoresByPlayer[pid] = s
                }
            }

            guard !scoresByPlayer.isEmpty else {
                // Everyone was excluded or had no score
                throw ChallengeFinalizerError.missingWinners
            }

            // Option A: If top scorer excluded, we already filtered them out,
            // so this becomes "next-highest eligible"
            let maxScore = scoresByPlayer.values.max()!
            winners = scoresByPlayer
                .filter { $0.value == maxScore }
                .map { $0.key }
                .sorted()
        }

        guard !winners.isEmpty else { throw ChallengeFinalizerError.missingWinners }

        let newSet = Set(winners)

        let toRemove = prevSet.subtracting(newSet)   // previously awarded but no longer winners
        let toAdd = newSet.subtracting(prevSet)      // new winners not previously awarded
        let toKeep = prevSet.intersection(newSet)    // unchanged winners

        // Write deterministic point_awards docs per player per week.
        let challengeId = "weekly_winner_bonus_\(weeklyId)"
        let note = "Week \(weekNum) — \(title) Winner Bonus (+\(formatPoints(bonus)))"
        let now = FieldValue.serverTimestamp()

        let batch = db.batch()

        // Remove old winners: delete award doc + decrement totals
        for pid in toRemove {
            let awardId = "\(challengeId)_\(pid)"
            let awardRef = db.collection("point_awards").document(awardId)
            batch.deleteDocument(awardRef)

            let playerRef = db.collection("players").document(pid)
            batch.updateData([
                "total_points": FieldValue.increment(-bonus)
            ], forDocument: playerRef)
        }

        // Add new winners: upsert award doc + increment totals
        for pid in toAdd {
            let awardId = "\(challengeId)_\(pid)"
            let awardRef = db.collection("point_awards").document(awardId)

            batch.setData([
                "playerId": pid,
                "challengeId": challengeId,
                "challengeTitle": title,
                "note": note,

                "points": bonus,
                "basePoints": bonus,
                "bonusPoints": 0.0,
                "multiplier": NSNull(),

                "createdAt": now,
                "finalizedAt": now
            ], forDocument: awardRef, merge: true)

            let playerRef = db.collection("players").document(pid)
            batch.updateData([
                "total_points": FieldValue.increment(bonus)
            ], forDocument: playerRef)
        }

        // Keep winners: ensure award doc exists/updated (NO points change)
        for pid in toKeep {
            let awardId = "\(challengeId)_\(pid)"
            let awardRef = db.collection("point_awards").document(awardId)

            batch.setData([
                "playerId": pid,
                "challengeId": challengeId,
                "challengeTitle": title,
                "note": note,
                "points": bonus,
                "basePoints": bonus,
                "bonusPoints": 0.0,
                "multiplier": NSNull(),
                "finalizedAt": now
            ], forDocument: awardRef, merge: true)
        }

        // Mark weekly doc as applied + store exactly who was applied
        batch.setData([
            "winner_bonuses_applied": true,
            "winner_bonus_applied_at": now,
            "applied_winner_bonus_players": winners,
            "updated_at": now
        ], forDocument: weeklyRef, merge: true)

        try await batch.commit()
    }

    private func formatPoints(_ pts: Double) -> String {
        pts == floor(pts) ? String(Int(pts)) : String(format: "%.1f", pts)
    }
}
