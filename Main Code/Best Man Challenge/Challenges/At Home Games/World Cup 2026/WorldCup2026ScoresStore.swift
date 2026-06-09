//
//  WorldCup2026ScoresStore.swift
//  Best Man Challenge
//
//  Live scoring for the World Cup 2026 group-stage challenge.
//
//  Scoring per team slot:
//    Predicted rank exactly correct  → +2
//    Off by 1 spot                   → +1
//    Off by 2 spots                  → 0
//    Off by 3 spots                  → -1
//
//  Max possible score: 12 groups × 4 teams × 2 pts = 96 pts.

import Foundation
import FirebaseFirestore

@MainActor
final class WorldCup2026ScoresStore: ObservableObject {

    let bracketId: String

    @Published private(set) var scores: [WCScoreRow] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()
    private var resultsListener: ListenerRegistration?
    private var picksListeners: [String: ListenerRegistration] = [:]

    private var latestResults: WCResults = WCResults()
    private var picksByPlayer: [String: (displayName: String, entry: WCEntry)] = [:]

    init(bracketId: String = "world_cup_2026") {
        self.bracketId = bracketId
    }

    deinit {
        resultsListener?.remove()
        for (_, l) in picksListeners { l.remove() }
    }

    // MARK: - Start / Stop

    func startListening() {
        guard resultsListener == nil else { return }
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

    // MARK: - Listeners

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
                let groupResultsRaw = d["groupResults"] as? [String: [String: String]] ?? [:]
                var groupResults: [String: WCGroupResult] = [:]
                for (key, val) in groupResultsRaw {
                    groupResults[key] = WCGroupResult(actualFinish: val)
                }
                let statusRaw = d["status"] as? String ?? "open"
                let status = WCTournamentStatus(rawValue: statusRaw) ?? .open
                let isFinalized = d["isFinalized"] as? Bool ?? false
                let finalizedAt = (d["finalizedAt"] as? Timestamp)?.dateValue()
                let finalizedBy = d["finalizedBy"] as? String

                Task { @MainActor in
                    self.latestResults = WCResults(
                        groupResults: groupResults,
                        status: status,
                        isFinalized: isFinalized,
                        finalizedAt: finalizedAt,
                        finalizedBy: finalizedBy
                    )
                    self.recompute()
                }
            }
    }

    private func listenLane(_ lane: String) {
        guard picksListeners[lane] == nil else { return }

        let ref = db.collection("brackets")
            .document(bracketId)
            .collection("picks")
            .document("all")
            .collection(lane)

        picksListeners[lane] = ref.addSnapshotListener { [weak self] snap, err in
            guard let self else { return }
            if let err {
                Task { @MainActor in self.errorMessage = err.localizedDescription }
                return
            }
            let docs = snap?.documents ?? []
            Task { @MainActor in
                for doc in docs {
                    let scopedId = (lane == "admins") ? "admin:\(doc.documentID)" : doc.documentID
                    let entry = WorldCup2026PicksStore.decodeEntry(docId: doc.documentID, data: doc.data())
                    self.picksByPlayer[scopedId] = (displayName: entry.displayName, entry: entry)
                }
                self.isLoading = false
                self.recompute()
            }
        }
    }

    // MARK: - Scoring

    private func recompute() {
        var rows: [WCScoreRow] = []
        rows.reserveCapacity(picksByPlayer.count)

        for (scopedId, v) in picksByPlayer {
            let entry = v.entry
            var total = 0
            var byGroup: [String: Int] = [:]

            for g in WCGroup.allCases {
                let groupResult = latestResults.result(for: g)
                let picks = entry.groupPicks[g.rawValue] ?? [:]
                var groupPoints = 0

                // For each team in the group that has an actual finish set,
                // find what rank the user predicted and score accordingly.
                for slot in WCGroupSlot.allCases {
                    guard let actualTeamId = groupResult.teamId(forSlot: slot),
                          !actualTeamId.isEmpty else { continue }

                    let actualRank = slot.rank

                    // Find what rank the user picked for this team
                    if let predictedRank = entry.predictedRank(teamId: actualTeamId, group: g) {
                        let pts = WCScoreRow.positionPoints(predictedRank: predictedRank, actualRank: actualRank)
                        groupPoints += pts
                    }
                    // If user didn't pick this team at all → 0 points for this slot
                }

                byGroup[g.rawValue] = groupPoints
                total += groupPoints
            }

            rows.append(WCScoreRow(
                id: scopedId,
                linkedPlayerId: entry.linkedPlayerId,
                displayName: entry.displayName,
                total: total,
                byGroup: byGroup
            ))
        }

        rows.sort {
            if $0.total != $1.total { return $0.total > $1.total }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        self.scores = rows
    }

    // MARK: - Helpers

    var playerRows: [WCScoreRow] {
        scores.filter { !$0.id.hasPrefix("admin:") }
    }

    func scoreForPlayer(_ linkedPlayerId: String) -> Int? {
        scores.first(where: { $0.linkedPlayerId == linkedPlayerId })?.total
    }
}
