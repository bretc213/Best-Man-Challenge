//
//  WorldCup2026KnockoutStore.swift
//  Best Man Challenge
//
//  Manages Phase 2 knockout bracket — match definitions, results, and lock state.
//
//  Firestore layout:
//    brackets/world_cup_2026/knockoutMatches/{matchId}     ← bracket seeded by admin
//    brackets/world_cup_2026/knockoutResults/current       ← admin-set results + lock

import Foundation
import FirebaseFirestore

@MainActor
final class WorldCup2026KnockoutStore: ObservableObject {

    let bracketId: String

    @Published private(set) var matches: [WCKOMatch] = []
    @Published private(set) var results: WCKnockoutResults = WCKnockoutResults()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()
    private var matchesListener: ListenerRegistration?
    private var resultsListener: ListenerRegistration?

    init(bracketId: String = "world_cup_2026") {
        self.bracketId = bracketId
    }

    deinit {
        matchesListener?.remove()
        resultsListener?.remove()
    }

    // MARK: - Listen

    func startListening() {
        guard matchesListener == nil else { return }
        isLoading = true
        listenMatches()
        listenResults()
    }

    func stopListening() {
        matchesListener?.remove(); matchesListener = nil
        resultsListener?.remove(); resultsListener = nil
        isLoading = false
    }

    private func listenMatches() {
        matchesListener = db.collection("brackets")
            .document(bracketId)
            .collection("knockoutMatches")
            .order(by: "sortOrder")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in self.errorMessage = err.localizedDescription }
                    return
                }
                let docs = snap?.documents ?? []
                let decoded: [WCKOMatch] = docs.compactMap { doc in
                    let d = doc.data()
                    guard
                        let roundRaw    = d["round"]           as? String,
                        let round       = WCKORound(rawValue: roundRaw),
                        let matchNum    = d["fifaMatchNumber"] as? Int,
                        let sortOrder   = d["sortOrder"]       as? Int,
                        let team1Slot   = d["team1Slot"]       as? String,
                        let team2Slot   = d["team2Slot"]       as? String
                    else { return nil }
                    return WCKOMatch(
                        id: doc.documentID,
                        round: round,
                        fifaMatchNumber: matchNum,
                        sortOrder: sortOrder,
                        team1Slot: team1Slot,
                        team2Slot: team2Slot
                    )
                }
                Task { @MainActor in
                    self.matches = decoded
                    self.isLoading = false
                }
            }
    }

    private func listenResults() {
        resultsListener = db.collection("brackets")
            .document(bracketId)
            .collection("knockoutResults")
            .document("current")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in self.errorMessage = err.localizedDescription }
                    return
                }
                let d = snap?.data() ?? [:]
                let matchResults    = d["matchResults"]     as? [String: String] ?? [:]
                let statusRaw       = d["knockoutStatus"]   as? String ?? "open"
                let status          = WCKnockoutStatus(rawValue: statusRaw) ?? .open
                let isLocked        = d["knockoutIsLocked"] as? Bool ?? false
                let finalizedAt     = (d["finalizedAt"]     as? Timestamp)?.dateValue()
                let finalizedBy     = d["finalizedBy"]      as? String

                Task { @MainActor in
                    self.results = WCKnockoutResults(
                        matchResults: matchResults,
                        knockoutStatus: status,
                        knockoutIsLocked: isLocked,
                        finalizedAt: finalizedAt,
                        finalizedBy: finalizedBy
                    )
                }
            }
    }

    // MARK: - Slot Resolution

    /// Resolves "1A" → Group A winner, "2B" → Group B runner-up, "W73" → winner of match 73.
    /// After group stage, 3rd-place slot strings are replaced with direct team IDs in Firestore
    /// (e.g. "PAR") via the "Set 3rd Place Teams" admin button — those pass through as-is.
    func resolveSlot(_ slot: String, phase1Results: WCResults) -> String? {
        // "1X" → group X winner
        if slot.count == 2, let first = slot.first, first == "1",
           let group = WCGroup(rawValue: String(slot.dropFirst())) {
            return phase1Results.result(for: group).teamId(forSlot: .first)
        }
        // "2X" → group X runner-up
        if slot.count == 2, let first = slot.first, first == "2",
           let group = WCGroup(rawValue: String(slot.dropFirst())) {
            return phase1Results.result(for: group).teamId(forSlot: .second)
        }
        // "W73" → winner of FIFA match 73 (stored as "m73")
        if slot.hasPrefix("W"), let num = Int(slot.dropFirst()) {
            return results.winnerId(for: "m\(num)")
        }
        // "3rd-XXXX" → still TBD (waiting for admin to seed actual team ID)
        if slot.hasPrefix("3rd-") { return nil }
        // Anything else is a direct team ID override set by the admin after group stage
        return slot.isEmpty ? nil : slot
    }

    /// Resolves team1 for a match (admin view — uses official results only).
    func resolvedTeam1Id(for match: WCKOMatch, phase1Results: WCResults) -> String? {
        resolveSlot(match.team1Slot, phase1Results: phase1Results)
    }

    /// Resolves team2 for a match (admin view — uses official results only).
    func resolvedTeam2Id(for match: WCKOMatch, phase1Results: WCResults) -> String? {
        resolveSlot(match.team2Slot, phase1Results: phase1Results)
    }

    /// Resolves a slot from the **player's perspective**: for "W73"-style slots,
    /// the player's own pick for that match is used first (so your bracket propagates
    /// forward as you pick), falling back to the admin's official result.
    func resolveSlotForPlayer(_ slot: String, phase1Results: WCResults, playerPicks: [String: String]) -> String? {
        // Group winner / runner-up resolve the same way as admin
        if slot.count == 2, let first = slot.first, first == "1",
           let group = WCGroup(rawValue: String(slot.dropFirst())) {
            return phase1Results.result(for: group).teamId(forSlot: .first)
        }
        if slot.count == 2, let first = slot.first, first == "2",
           let group = WCGroup(rawValue: String(slot.dropFirst())) {
            return phase1Results.result(for: group).teamId(forSlot: .second)
        }
        // "W73" → check player's own pick for m73 first, then official result
        if slot.hasPrefix("W"), let num = Int(slot.dropFirst()) {
            let matchId = "m\(num)"
            if let pick = playerPicks[matchId], !pick.isEmpty { return pick }
            return results.winnerId(for: matchId)
        }
        // "3rd-XXXX" → still TBD (waiting for admin to seed actual team ID)
        if slot.hasPrefix("3rd-") { return nil }
        // Anything else is a direct team ID override set by the admin after group stage
        return slot.isEmpty ? nil : slot
    }

    func resolvedTeam1IdForPlayer(for match: WCKOMatch, phase1Results: WCResults, playerPicks: [String: String]) -> String? {
        resolveSlotForPlayer(match.team1Slot, phase1Results: phase1Results, playerPicks: playerPicks)
    }

    func resolvedTeam2IdForPlayer(for match: WCKOMatch, phase1Results: WCResults, playerPicks: [String: String]) -> String? {
        resolveSlotForPlayer(match.team2Slot, phase1Results: phase1Results, playerPicks: playerPicks)
    }

    // MARK: - Grouped by Round

    func matchesByRound() -> [WCKORoundGroup] {
        let grouped = Dictionary(grouping: matches, by: { $0.round })
        return WCKORound.allCases.compactMap { round in
            guard let ms = grouped[round], !ms.isEmpty else { return nil }
            return WCKORoundGroup(round: round, matches: ms.sorted { $0.sortOrder < $1.sortOrder })
        }
    }

    // MARK: - Scoring Helper

    /// Points earned by a player for knockout picks given the current results.
    func knockoutPoints(knockoutPicks: [String: String], phase1Results: WCResults) -> (total: Int, byRound: [String: Int]) {
        var total = 0
        var byRound: [String: Int] = [:]

        for match in matches {
            guard let actualWinnerId = results.winnerId(for: match.id),
                  !actualWinnerId.isEmpty else { continue }
            let playerPick = knockoutPicks[match.id] ?? ""
            let pts = (playerPick == actualWinnerId) ? match.round.points : 0
            total += pts
            byRound[match.round.rawValue, default: 0] += pts
        }
        return (total, byRound)
    }

    // MARK: - Admin: Set Match Result

    func setMatchResult(matchId: String, winnerId: String) async throws {
        guard results.knockoutStatus != .finalized else { return }
        // Use mergeFields with dot-notation so only this one entry inside
        // matchResults is written — plain merge:true replaces the entire map.
        try await knockoutResultsRef().setData([
            "matchResults": [matchId: winnerId],
            "updatedAt": FieldValue.serverTimestamp()
        ], mergeFields: ["matchResults.\(matchId)", "updatedAt"])
    }

    func clearMatchResult(matchId: String) async throws {
        try await knockoutResultsRef().setData([
            "matchResults": [matchId: ""],
            "updatedAt": FieldValue.serverTimestamp()
        ], mergeFields: ["matchResults.\(matchId)", "updatedAt"])
    }

    // MARK: - Admin: Lock / Unlock

    func setKnockoutStatus(_ status: WCKnockoutStatus) async throws {
        let isLocked = (status == .locked || status == .finalized)
        try await knockoutResultsRef().setData([
            "knockoutStatus": status.rawValue,
            "knockoutIsLocked": isLocked,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    // MARK: - Private

    private func knockoutResultsRef() -> DocumentReference {
        db.collection("brackets").document(bracketId)
            .collection("knockoutResults").document("current")
    }
}
