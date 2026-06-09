//
//  WorldCup2026ResultsStore.swift
//  Best Man Challenge
//
//  Admin-set actual group results.  Also manages lock / open / finalize state.
//
//  Firestore layout:
//    brackets/world_cup_2026                    ← meta: status, isLocked
//    brackets/world_cup_2026/results/current    ← group results, status, finalized flags
//    brackets/world_cup_2026/results/final      ← immutable snapshot on finalize

import Foundation
import FirebaseFirestore

@MainActor
final class WorldCup2026ResultsStore: ObservableObject {

    let bracketId: String

    @Published var results: WCResults = WCResults()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init(bracketId: String = "world_cup_2026") {
        self.bracketId = bracketId
    }

    deinit { listener?.remove() }

    // MARK: - Listen

    func startListening() {
        guard listener == nil else { return }
        isLoading = true
        errorMessage = nil

        listener = db.collection("brackets")
            .document(bracketId)
            .collection("results")
            .document("current")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in
                        self.errorMessage = err.localizedDescription
                        self.isLoading = false
                    }
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
                    self.results = WCResults(
                        groupResults: groupResults,
                        status: status,
                        isFinalized: isFinalized,
                        finalizedAt: finalizedAt,
                        finalizedBy: finalizedBy
                    )
                    self.isLoading = false
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        isLoading = false
    }

    // MARK: - Admin: Set Group Result

    func setGroupResult(group: WCGroup, slot: WCGroupSlot, teamId: String) async throws {
        guard !results.isFinalized else { return }

        let ref = resultsRef()
        try await ref.setData([
            "updatedAt": Timestamp(date: Date()),
            "groupResults": [
                group.rawValue: [
                    slot.rawValue: teamId
                ]
            ]
        ], merge: true)
    }

    // MARK: - Admin: Tournament Status

    func setStatus(_ newStatus: WCTournamentStatus) async throws {
        guard !results.isFinalized || newStatus == .finalized else { return }

        let isLocked = (newStatus == .locked || newStatus == .finalized)

        // Update both the meta doc and results doc atomically
        let batch = db.batch()

        let metaRef = db.collection("brackets").document(bracketId)
        batch.setData([
            "status": newStatus.rawValue,
            "isLocked": isLocked,
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: metaRef, merge: true)

        let rRef = resultsRef()
        batch.setData([
            "status": newStatus.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: rRef, merge: true)

        try await batch.commit()
    }

    // MARK: - Admin: Finalize

    func finalizeResults(scoreRows: [WCScoreRow], finalizedBy: String) async throws {
        guard !results.isFinalized else {
            throw AppError("World Cup is already finalized.")
        }

        let name = finalizedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Admin" : finalizedBy.trimmingCharacters(in: .whitespacesAndNewlines)

        let currentRef = resultsRef()
        let finalRef = db.collection("brackets")
            .document(bracketId)
            .collection("results")
            .document("final")
        let metaRef = db.collection("brackets").document(bracketId)

        // Build final standings snapshot
        let snapshot: [[String: Any]] = scoreRows.enumerated().map { idx, row in
            [
                "rank": idx + 1,
                "linkedPlayerId": row.linkedPlayerId,
                "displayName": row.displayName,
                "total": row.total,
                "byGroup": row.byGroup
            ]
        }

        // Serialize current group results
        var groupResultsPayload: [String: [String: String]] = [:]
        for g in WCGroup.allCases {
            let r = results.result(for: g)
            groupResultsPayload[g.rawValue] = r.actualFinish
        }

        let finalPayload: [String: Any] = [
            "bracketId": bracketId,
            "groupResults": groupResultsPayload,
            "finalStandings": snapshot,
            "isFinalized": true,
            "finalizedBy": name,
            "finalizedAt": FieldValue.serverTimestamp()
        ]

        let batch = db.batch()
        batch.setData([
            "status": WCTournamentStatus.finalized.rawValue,
            "isLocked": true,
            "isFinalized": true,
            "finalizedBy": name,
            "finalizedAt": FieldValue.serverTimestamp()
        ], forDocument: metaRef, merge: true)
        batch.setData([
            "status": WCTournamentStatus.finalized.rawValue,
            "isLocked": true,
            "isFinalized": true,
            "finalizedBy": name,
            "finalizedAt": FieldValue.serverTimestamp()
        ], forDocument: currentRef, merge: true)
        batch.setData(finalPayload, forDocument: finalRef, merge: true)
        try await batch.commit()
    }

    // MARK: - Helpers

    private func resultsRef() -> DocumentReference {
        db.collection("brackets").document(bracketId).collection("results").document("current")
    }
}

// MARK: - Simple error helper

private struct AppError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
