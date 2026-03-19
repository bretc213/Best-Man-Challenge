//
//  WBC2026ScoresStore.swift
//  Best Man Challenge
//
//  Live leaderboard scoring for WBC 2026 bracket.
//

import Foundation
import FirebaseFirestore

struct WBCScoreRow: Identifiable {
    let id: String            // scoped: "admin:<id>" for admin lane
    let linkedPlayerId: String
    let displayName: String
    let score: Int
    let breakdown: [String: Int]
}

@MainActor
final class WBC2026ScoresStore: ObservableObject {

    enum Group: String, CaseIterable, Identifiable {
        case players
        case admin
        var id: String { rawValue }
    }

    func groupForPlayerId(_ scopedId: String) -> Group {
        return scopedId.hasPrefix("admin:") ? .admin : .players
    }

    @Published var scores: [WBCScoreRow] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()
    let bracketId: String

    private var resultsListener: ListenerRegistration?
    private var picksListeners: [String: ListenerRegistration] = [:]

    private var results: WBCResults = WBCResults()
    private var picksByPlayer: [String: (displayName: String, entry: WBCEntry)] = [:]

    init(bracketId: String = "wbc_2026") {
        self.bracketId = bracketId
    }

    deinit {
        resultsListener?.remove()
        for (_, l) in picksListeners { l.remove() }
    }

    var playerRows: [WBCScoreRow] {
        scores.filter { groupForPlayerId($0.id) == .players }
    }

    func buildFinalizerScores() throws -> [String: Int] {
        let rows = playerRows
        guard !rows.isEmpty else {
            throw NSError(
                domain: "WBC2026",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No player standings available to finalize."]
            )
        }

        var output: [String: Int] = [:]
        for row in rows {
            let playerId = row.linkedPlayerId.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = playerId.isEmpty ? row.id : playerId
            output[key] = row.score
        }
        return output
    }

    func startListening() {
        if resultsListener != nil { return }
        stopListening()
        isLoading = true
        errorMessage = nil

        listenResults()
        listenLane("players")
        listenLane("admins")
    }

    func stopListening() {
        resultsListener?.remove(); resultsListener = nil
        for (_, l) in picksListeners { l.remove() }
        picksListeners.removeAll()
        isLoading = false
    }

    private func listenResults() {
        resultsListener?.remove()
        resultsListener = db.collection("brackets")
            .document(bracketId)
            .collection("results")
            .document("current")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in self.errorMessage = err.localizedDescription }
                    return
                }
                let d = snap?.data() ?? [:]
                let pool = d["poolResults"] as? [String: [String: String]] ?? [:]
                let ff = d["finalFour"] as? [String] ?? []
                let ft = d["finalTwo"] as? [String] ?? []
                let champ = d["champion"] as? String
                let isFinalized = d["isFinalized"] as? Bool ?? false
                let finalizedAt = (d["finalizedAt"] as? Timestamp)?.dateValue()
                let finalizedBy = d["finalizedBy"] as? String

                Task { @MainActor in
                    self.results = WBCResults(
                        poolResults: pool,
                        finalFour: ff,
                        finalTwo: ft,
                        champion: champ,
                        isFinalized: isFinalized,
                        finalizedAt: finalizedAt,
                        finalizedBy: finalizedBy
                    )
                    self.recomputeScores()
                }
            }
    }

    private func listenLane(_ lane: String) {
        let key = lane
        guard picksListeners[key] == nil else { return }

        let ref = db.collection("brackets")
            .document(bracketId)
            .collection("picks")
            .document("all")
            .collection(lane)

        picksListeners[key] = ref.addSnapshotListener { [weak self] snap, err in
            guard let self else { return }
            if let err {
                Task { @MainActor in self.errorMessage = err.localizedDescription }
                return
            }

            let docs = snap?.documents ?? []
            Task { @MainActor in
                for doc in docs {
                    let d = doc.data()
                    let pid = doc.documentID
                    let scopedId = (lane == "admins") ? "admin:\(pid)" : pid

                    let displayName = d["displayName"] as? String ?? pid
                    let linkedPlayerId = d["linkedPlayerId"] as? String ?? pid
                    let updatedAt = (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date.distantPast

                    let poolPicks = d["poolPicks"] as? [String: [String: String]] ?? [:]
                    let qf = d["qfPicks"] as? [String: String] ?? [:]
                    let sf = d["sfPicks"] as? [String: String] ?? [:]
                    let champ = d["champPick"] as? String

                    let entry = WBCEntry(
                        id: pid,
                        linkedPlayerId: linkedPlayerId,
                        displayName: displayName,
                        updatedAt: updatedAt,
                        poolPicks: poolPicks,
                        qfPicks: qf,
                        sfPicks: sf,
                        champPick: champ
                    )

                    self.picksByPlayer[scopedId] = (displayName: displayName, entry: entry)
                }
                self.isLoading = false
                self.recomputeScores()
            }
        }
    }

    private func recomputeScores() {
        var rows: [WBCScoreRow] = []
        rows.reserveCapacity(picksByPlayer.count)

        let finalFourSet = Set(results.finalFour.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        let finalTwoSet  = Set(results.finalTwo.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })

        for (scopedId, v) in picksByPlayer {
            let entry = v.entry
            var total = 0
            var breakdown: [String: Int] = [:]

            var poolTotal = 0
            for pool in WBCPool.allCases {
                let poolKey = pool.rawValue
                let actual1 = results.poolResults[poolKey]?["seed1"]
                let actual2 = results.poolResults[poolKey]?["seed2"]

                let pick1 = entry.poolPicks[poolKey]?["winner"]
                let pick2 = entry.poolPicks[poolKey]?["runnerUp"]

                if let a1 = actual1, !a1.isEmpty {
                    if pick1 == a1 { poolTotal += 4 }
                    else if pick2 == a1 { poolTotal += 2 }
                }
                if let a2 = actual2, !a2.isEmpty {
                    if pick2 == a2 { poolTotal += 4 }
                    else if pick1 == a2 { poolTotal += 2 }
                }
            }
            breakdown["Pools"] = poolTotal
            total += poolTotal

            var qfTotal = 0
            var countedQF: Set<String> = []
            for k in ["qf1", "qf2", "qf3", "qf4"] {
                guard let pick = entry.qfPicks[k], !pick.isEmpty else { continue }
                guard !countedQF.contains(pick) else { continue }
                if finalFourSet.contains(pick) {
                    qfTotal += 8
                    countedQF.insert(pick)
                }
            }
            breakdown["Quarters"] = qfTotal
            total += qfTotal

            var sfTotal = 0
            var countedSF: Set<String> = []
            for k in ["sf1", "sf2"] {
                guard let pick = entry.sfPicks[k], !pick.isEmpty else { continue }
                guard !countedSF.contains(pick) else { continue }
                if finalTwoSet.contains(pick) {
                    sfTotal += 16
                    countedSF.insert(pick)
                }
            }
            breakdown["Semis"] = sfTotal
            total += sfTotal

            var champTotal = 0
            if let champ = results.champion, !champ.isEmpty, entry.champPick == champ { champTotal = 32 }
            breakdown["Champion"] = champTotal
            total += champTotal

            rows.append(
                WBCScoreRow(
                    id: scopedId,
                    linkedPlayerId: entry.linkedPlayerId,
                    displayName: entry.displayName,
                    score: total,
                    breakdown: breakdown
                )
            )
        }

        rows.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        self.scores = rows
    }
}
