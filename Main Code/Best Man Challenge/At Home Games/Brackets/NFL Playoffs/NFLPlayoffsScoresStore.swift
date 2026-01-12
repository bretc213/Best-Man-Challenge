//
//  NFLPlayoffsScoresStore.swift
//  Best Man Challenge
//
//  Aggregated totals across ALL rounds.
//  (No picks-store code should exist in this file.)
//

import Foundation
import FirebaseFirestore

@MainActor
final class NFLPlayoffsScoresStore: ObservableObject {

    // MARK: - Grouping (used by leaderboard picker)

    enum Group: String, CaseIterable, Identifiable {
        case groomsmen
        case admin

        var id: String { rawValue }
    }

    /// Determines which "lane" a score belongs to based on the scoped player id.
    /// You already scoped admin ids as "admin:<id>" in listenPicksForRound(), so we use that.
    func groupForPlayerId(_ linkedPlayerId: String?) -> Group {
        guard let linkedPlayerId else { return .groomsmen }
        return linkedPlayerId.hasPrefix("admin:") ? .admin : .groomsmen
    }

    // MARK: - Published state

    @Published var scores: [BracketScoreRow] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    let bracketId: String

    private var bracketListener: ListenerRegistration?
    private var matchupsListener: ListenerRegistration?
    private var picksListeners: [String: ListenerRegistration] = [:]

    // Cached state
    private var points: BracketPoints?
    private var winnerByMatchup: [String: (round: BracketRound, winnerTeamId: String)] = [:]
    private var picksByPlayer: [String: (displayName: String, picks: [String: String])] = [:]

    init(bracketId: String = "nfl_2026_playoffs") {
        self.bracketId = bracketId
    }

    deinit {
        bracketListener?.remove()
        matchupsListener?.remove()
        bracketListener = nil
        matchupsListener = nil

        for (_, l) in picksListeners { l.remove() }
        picksListeners.removeAll()
    }


    func startListening() {
        if bracketListener != nil || matchupsListener != nil { return } // already listening
        stopListening()
        errorMessage = nil
        isLoading = true

        listenBracketForPoints()
        listenAllMatchups()
        listenAllRoundsPlayerPicks()   // groomsmen lane
        listenAllRoundsAdminPicks()    // admin lane
    }

    func stopListening() {
        bracketListener?.remove()
        bracketListener = nil

        matchupsListener?.remove()
        matchupsListener = nil

        for (_, l) in picksListeners { l.remove() }
        picksListeners.removeAll()

        isLoading = false
    }

    // MARK: - Bracket points

    private func listenBracketForPoints() {
        bracketListener?.remove()

        bracketListener = db.collection("brackets")
            .document(bracketId)
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
                let pointsMap = d["points"] as? [String: Any] ?? [:]

                let p = BracketPoints(
                    wildcard: pointsMap["wildcard"] as? Int ?? 1,
                    divisional: pointsMap["divisional"] as? Int ?? 2,
                    conference: pointsMap["conference"] as? Int ?? 4,
                    superBowl: pointsMap["superBowl"] as? Int ?? 8
                )

                Task { @MainActor in
                    self.points = p
                    self.recomputeScores()
                }
            }
    }

    // MARK: - Matchups (all rounds)

    private func listenAllMatchups() {
        matchupsListener?.remove()

        matchupsListener = db.collection("brackets")
            .document(bracketId)
            .collection("matchups")
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
                var winners: [String: (round: BracketRound, winnerTeamId: String)] = [:]

                for doc in docs {
                    let d = doc.data()
                    guard
                        let roundRaw = d["round"] as? String,
                        let round = BracketRound(rawValue: roundRaw)
                    else { continue }

                    if let w = d["winnerTeamId"] as? String, !w.isEmpty {
                        winners[doc.documentID] = (round: round, winnerTeamId: w)
                    }
                }

                Task { @MainActor in
                    self.winnerByMatchup = winners
                    self.recomputeScores()
                }
            }
    }

    // MARK: - Picks across all rounds (PLAYERS lane)

    // MARK: - Picks across all rounds (PLAYERS lane)

    private func listenAllRoundsPlayerPicks() {
        let roundIds = BracketRound.allCases.map { $0.rawValue }

        for rid in roundIds {
            let key = "players:\(rid)"
            if picksListeners[key] == nil {
                listenPicksForRound(roundId: rid, lane: "players")
            }
        }

        Task { @MainActor in self.isLoading = false }
    }

    // MARK: - Picks across all rounds (ADMINS lane)

    private func listenAllRoundsAdminPicks() {
        let roundIds = BracketRound.allCases.map { $0.rawValue }

        for rid in roundIds {
            let key = "admins:\(rid)"
            if picksListeners[key] == nil {
                listenPicksForRound(roundId: rid, lane: "admins")
            }
        }

        Task { @MainActor in self.isLoading = false }
    }

    private func listenPicksForRound(roundId: String, lane: String) {
        let ref = db.collection("brackets")
            .document(bracketId)
            .collection("picks")
            .document(roundId)
            .collection(lane)

        let key = "\(lane):\(roundId)"

        let listener = ref.addSnapshotListener { [weak self] snap, err in
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

                    // Make admin ids not collide with player ids
                    let scopedId = (lane == "admins") ? "admin:\(pid)" : pid

                    let dn = d["displayName"] as? String ?? pid
                    let picks = d["picks"] as? [String: String] ?? [:]

                    var current = self.picksByPlayer[scopedId]?.picks ?? [:]
                    for (k, v) in picks { current[k] = v }

                    self.picksByPlayer[scopedId] = (displayName: dn, picks: current)
                }

                self.recomputeScores()
            }
        }

        picksListeners[key] = listener
    }

    // MARK: - Compute totals

    private func recomputeScores() {
        guard let points else { return }

        var rows: [BracketScoreRow] = []

        for (playerId, meta) in picksByPlayer {
            let displayName = meta.displayName
            let picks = meta.picks

            var total = 0
            var correct = 0
            var breakdown: [String: Int] = [
                "wildcard": 0,
                "divisional": 0,
                "conference": 0,
                "superBowl": 0
            ]

            for (matchupId, winMeta) in winnerByMatchup {
                if picks[matchupId] == winMeta.winnerTeamId {
                    correct += 1
                    let pts = points.points(for: winMeta.round)
                    total += pts
                    breakdown[winMeta.round.rawValue, default: 0] += pts
                }
            }

            rows.append(
                BracketScoreRow(
                    id: playerId,               // unique per lane (admins are "admin:<id>")
                    linkedPlayerId: playerId,   // keep scoped so Group detection works
                    displayName: displayName,
                    points: total,
                    correct: correct,
                    breakdown: breakdown
                )
            )
        }

        rows.sort {
            if $0.points != $1.points { return $0.points > $1.points }
            return $0.displayName < $1.displayName
        }

        self.scores = rows
    }
}
