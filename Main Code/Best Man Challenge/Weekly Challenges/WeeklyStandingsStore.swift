//
//  WeeklyChallengeStandingsStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/7/26.
//  Updated on 1/7/26: merge roster (players) + submissions so everyone shows.
//

import Foundation
import FirebaseFirestore

struct WeeklyStandingRow: Identifiable {
    let id: String              // linkedPlayerId
    let linkedPlayerId: String
    let displayName: String
    let score: Int
    let maxScore: Int
    let submittedAt: Date?      // nil if not submitted yet
    let hasSubmitted: Bool
}

@MainActor
final class WeeklyChallengeStandingsStore: ObservableObject {
    @Published var rows: [WeeklyStandingRow] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    private var playersListener: ListenerRegistration?
    private var submissionsListener: ListenerRegistration?

    // Internal caches
    private var rosterById: [String: String] = [:]                 // playerId -> display_name
    private var submissionById: [String: (score: Int, max: Int, submittedAt: Date?)] = [:]

    func startListening(weekId: String, defaultMaxScore: Int = 0) {
        stopListening()
        errorMessage = nil
        isLoading = true

        listenPlayers()
        listenSubmissions(weekId: weekId, defaultMaxScore: defaultMaxScore)
    }

    func stopListening() {
        playersListener?.remove()
        submissionsListener?.remove()
        playersListener = nil
        submissionsListener = nil

        rosterById = [:]
        submissionById = [:]

        isLoading = false
    }

    // MARK: - Listeners

    private func listenPlayers() {
        playersListener?.remove()

        playersListener = db.collection("players")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }

                if let err {
                    Task { @MainActor in
                        self.errorMessage = err.localizedDescription
                        self.isLoading = false
                    }
                    return
                }

                let docs = snap?.documents ?? []
                var roster: [String: String] = [:]

                for doc in docs {
                    let d = doc.data()
                    let id = doc.documentID
                    let name =
                        (d["display_name"] as? String)
                        ?? (d["displayName"] as? String)
                        ?? (d["name"] as? String)
                        ?? id
                    roster[id] = name
                }

                Task { @MainActor in
                    self.rosterById = roster
                    self.rebuildRows()
                }
            }
    }

    private func listenSubmissions(weekId: String, defaultMaxScore: Int) {
        submissionsListener?.remove()

        submissionsListener = db.collection("weekly_challenges")
            .document(weekId)
            .collection("submissions")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }

                if let err {
                    Task { @MainActor in
                        self.errorMessage = err.localizedDescription
                        self.isLoading = false
                    }
                    return
                }

                let docs = snap?.documents ?? []
                var subs: [String: (score: Int, max: Int, submittedAt: Date?)] = [:]

                for doc in docs {
                    let d = doc.data()

                    // Doc id SHOULD be linkedPlayerId once you apply the manager fix.
                    // If you still have old uid-based docs, we fallback to linked_player_id.
                    let linkedId =
                        (d["linked_player_id"] as? String)
                        ?? doc.documentID

                    let score = d["score"] as? Int ?? 0
                    let maxScore = (d["maxScore"] as? Int) ?? (d["max_score"] as? Int) ?? defaultMaxScore

                    let submittedAt =
                        (d["submittedAt"] as? Timestamp)?.dateValue()
                        ?? (d["submitted_at"] as? Timestamp)?.dateValue()

                    subs[linkedId] = (score: score, max: maxScore, submittedAt: submittedAt)
                }

                Task { @MainActor in
                    self.submissionById = subs
                    self.rebuildRows()
                }
            }
    }

    // MARK: - Merge + sort

    private func rebuildRows() {
        // If roster is empty, we can still show submissions-only rows
        // but in your case you want all players, so roster should exist.
        var merged: [WeeklyStandingRow] = []

        if !rosterById.isEmpty {
            for (playerId, name) in rosterById {
                let sub = submissionById[playerId]
                merged.append(
                    WeeklyStandingRow(
                        id: playerId,
                        linkedPlayerId: playerId,
                        displayName: name,
                        score: sub?.score ?? 0,
                        maxScore: sub?.max ?? 0,
                        submittedAt: sub?.submittedAt,
                        hasSubmitted: sub != nil
                    )
                )
            }
        } else {
            // Fallback: show submission docs if roster collection not available
            for (playerId, sub) in submissionById {
                merged.append(
                    WeeklyStandingRow(
                        id: playerId,
                        linkedPlayerId: playerId,
                        displayName: playerId,
                        score: sub.score,
                        maxScore: sub.max,
                        submittedAt: sub.submittedAt,
                        hasSubmitted: true
                    )
                )
            }
        }

        // Sort rules (feel free to tweak):
        // 1) higher score first
        // 2) submitted players above non-submitted when tied
        // 3) name alphabetical
        // 4) earlier submission breaks ties (optional)
        merged.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            if a.hasSubmitted != b.hasSubmitted { return a.hasSubmitted && !b.hasSubmitted }
            if a.displayName != b.displayName { return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending }

            let aDate = a.submittedAt ?? Date.distantFuture
            let bDate = b.submittedAt ?? Date.distantFuture
            return aDate < bDate
        }

        self.rows = merged
        self.isLoading = false
    }
}
