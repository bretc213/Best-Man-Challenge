//
//  NFLPickEmStore.swift
//  Best Man Challenge
//
//  Unified store for the NFL Pick 'Em (2026, Weeks 1–16).
//  Firestore layout:
//    nfl_pickem_2026/
//      games/{gameId}          – game metadata + winner
//      picks/{playerId}        – player's picks map { gameId: teamId }
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class NFLPickEmStore: ObservableObject {

    // MARK: - Published

    @Published var games: [NFLPickEmGame] = []
    @Published var allEntries: [NFLPickEmEntry] = []
    @Published var myPicks: [String: String] = [:]          // gameId → teamId
    @Published var scoreRows: [NFLPickEmScoreRow] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    // MARK: - Private

    private let db = Firestore.firestore()
    private let challengeId = "nfl_pickem_2026"

    private var gamesListener: ListenerRegistration?
    private var picksListener: ListenerRegistration?

    // Cached identity
    private var myLinkedPlayerId: String?
    private var myUid: String?
    private var myDisplayName: String?
    private var myRole: String?

    deinit {
        gamesListener?.remove()
        picksListener?.remove()
    }

    // MARK: - Start

    func start(linkedPlayerId: String?, uid: String?, displayName: String?, role: String?) {
        myLinkedPlayerId = linkedPlayerId
        myUid = uid
        myDisplayName = displayName
        myRole = role

        isLoading = true
        errorMessage = nil

        listenGames()
        listenPicks()
    }

    func stopListening() {
        gamesListener?.remove()
        gamesListener = nil
        picksListener?.remove()
        picksListener = nil
        isLoading = false
    }

    // MARK: - Games Listener

    private func listenGames() {
        gamesListener?.remove()
        gamesListener = db.collection(challengeId)
            .document("data")
            .collection("games")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    self.errorMessage = err.localizedDescription
                    self.isLoading = false
                    return
                }
                let docs = snap?.documents ?? []
                self.games = docs.compactMap { self.decodeGame($0) }
                    .sorted {
                        if $0.week != $1.week { return $0.week < $1.week }
                        return $0.kickoffTime < $1.kickoffTime
                    }
                self.recomputeScores()
                self.isLoading = false
            }
    }

    private func decodeGame(_ doc: QueryDocumentSnapshot) -> NFLPickEmGame? {
        let d = doc.data()
        guard
            let week = (d["week"] as? NSNumber)?.intValue,
            let awayId = d["awayTeamId"] as? String,
            let homeId = d["homeTeamId"] as? String,
            let awayTeam = NFLPickEmTeam.team(for: awayId),
            let homeTeam = NFLPickEmTeam.team(for: homeId),
            let ts = d["kickoffTime"] as? Timestamp
        else { return nil }

        let winnerId = d["winnerId"] as? String

        return NFLPickEmGame(
            id: doc.documentID,
            week: week,
            awayTeam: awayTeam,
            homeTeam: homeTeam,
            kickoffTime: ts.dateValue(),
            winnerId: winnerId?.isEmpty == true ? nil : winnerId
        )
    }

    // MARK: - Picks Listener (all players)

    private func listenPicks() {
        picksListener?.remove()
        picksListener = db.collection(challengeId)
            .document("data")
            .collection("picks")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    self.errorMessage = err.localizedDescription
                    return
                }
                let docs = snap?.documents ?? []
                self.allEntries = docs.compactMap { self.decodeEntry($0) }
                    .sorted { $0.displayName < $1.displayName }

                // Extract my picks
                let myId = self.myLinkedPlayerId ?? ""
                self.myPicks = self.allEntries
                    .first(where: { $0.linkedPlayerId == myId })?.picks ?? [:]

                self.recomputeScores()
            }
    }

    private func decodeEntry(_ doc: QueryDocumentSnapshot) -> NFLPickEmEntry? {
        let d = doc.data()
        guard let displayName = d["displayName"] as? String else { return nil }

        let linkedPlayerId = (d["linkedPlayerId"] as? String) ?? doc.documentID
        let updatedAt = (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        let picksAny = d["picks"] as? [String: Any] ?? [:]
        var picks: [String: String] = [:]
        for (k, v) in picksAny {
            if let s = v as? String { picks[k] = s }
        }

        return NFLPickEmEntry(
            id: linkedPlayerId,
            linkedPlayerId: linkedPlayerId,
            displayName: displayName,
            updatedAt: updatedAt,
            picks: picks
        )
    }

    // MARK: - Score Computation

    private func recomputeScores() {
        guard !games.isEmpty else { return }

        // Final games only (have a winner)
        let finalGames = games.filter { $0.isFinal }

        var rows: [NFLPickEmScoreRow] = []

        for entry in allEntries {
            var weeklyCorrect: [Int: Int] = [:]

            for game in finalGames {
                guard let winner = game.winnerId else { continue }
                guard let picked = entry.picks[game.id] else { continue }
                if picked == winner {
                    weeklyCorrect[game.week, default: 0] += 1
                }
            }

            rows.append(NFLPickEmScoreRow(
                id: entry.linkedPlayerId,
                linkedPlayerId: entry.linkedPlayerId,
                displayName: entry.displayName,
                weeklyCorrect: weeklyCorrect,
                weekWins: []        // computed separately below
            ))
        }

        // Compute week winners
        let allWeeks = Set(finalGames.map { $0.week })
        var weekWinnerSets: [Int: Set<String>] = [:]

        for week in allWeeks {
            let weekGames = finalGames.filter { $0.week == week }
            guard !weekGames.isEmpty else { continue }

            // Only count week as decided if ALL games in that week are final
            let allFinal = weekGames.allSatisfy { $0.isFinal }
            guard allFinal else { continue }

            let maxScore = rows.map { $0.weeklyCorrect[week] ?? 0 }.max() ?? 0
            guard maxScore > 0 else { continue }

            let winners = rows.filter { ($0.weeklyCorrect[week] ?? 0) == maxScore }
                .map { $0.linkedPlayerId }
            weekWinnerSets[week] = Set(winners)
        }

        // Rebuild rows with week wins
        rows = rows.map { row in
            let wins = weekWinnerSets
                .filter { $0.value.contains(row.linkedPlayerId) }
                .map { $0.key }
                .sorted()

            return NFLPickEmScoreRow(
                id: row.linkedPlayerId,
                linkedPlayerId: row.linkedPlayerId,
                displayName: row.displayName,
                weeklyCorrect: row.weeklyCorrect,
                weekWins: wins
            )
        }

        scoreRows = rows.sorted {
            if $0.totalCorrect != $1.totalCorrect { return $0.totalCorrect > $1.totalCorrect }
            return $0.displayName < $1.displayName
        }
    }

    // MARK: - Pick Submission

    func setPick(gameId: String, teamId: String) async throws {
        guard let linkedPlayerId = myLinkedPlayerId, !linkedPlayerId.isEmpty else {
            throw PickEmError.notLinked
        }

        guard let game = games.first(where: { $0.id == gameId }) else {
            throw PickEmError.gameNotFound
        }

        guard !game.isLocked else {
            throw PickEmError.gameLocked
        }

        let ref = db.collection(challengeId)
            .document("data")
            .collection("picks")
            .document(linkedPlayerId)

        try await ref.setData([
            "linkedPlayerId": linkedPlayerId,
            "displayName": myDisplayName ?? "Unknown",
            "updatedAt": FieldValue.serverTimestamp(),
            "picks": [gameId: teamId]
        ], merge: true)
    }

    // MARK: - Admin: Set Game Winner

    func setWinner(gameId: String, winnerId: String?) async throws {
        let ref = db.collection(challengeId)
            .document("data")
            .collection("games")
            .document(gameId)

        if let winnerId, !winnerId.isEmpty {
            try await ref.updateData([
                "winnerId": winnerId,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } else {
            try await ref.updateData([
                "winnerId": FieldValue.delete(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
        }
    }

    // MARK: - Admin: Add/Update Game

    func upsertGame(_ game: NFLPickEmGame) async throws {
        let ref = db.collection(challengeId)
            .document("data")
            .collection("games")
            .document(game.id)

        var data: [String: Any] = [
            "week": game.week,
            "awayTeamId": game.awayTeam.id,
            "homeTeamId": game.homeTeam.id,
            "kickoffTime": Timestamp(date: game.kickoffTime),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let w = game.winnerId { data["winnerId"] = w }

        try await ref.setData(data, merge: true)
    }

    // MARK: - Admin: Award Weekly BMC Bonus

    /// Awards +1 BMC point to weekly winner(s) using the standard ChallengePointsFinalizer pattern.
    func applyWeeklyBonus(week: Int) async throws {
        let weekGames = games.filter { $0.week == week && $0.isFinal }
        guard !weekGames.isEmpty else { throw PickEmError.weekNotFinalized }
        guard weekGames.allSatisfy({ $0.isFinal }) else { throw PickEmError.weekNotFinalized }

        // Find winner(s)
        let scores = scoreRows
        let maxScore = scores.map { $0.weeklyCorrect[week] ?? 0 }.max() ?? 0
        guard maxScore > 0 else { throw PickEmError.noWinners }

        let excluded: Set<String> = ["bretc"]
        let winners = scores
            .filter { ($0.weeklyCorrect[week] ?? 0) == maxScore && !excluded.contains($0.linkedPlayerId) }
            .map { $0.linkedPlayerId }

        guard !winners.isEmpty else { throw PickEmError.noWinners }

        let batch = db.batch()
        let now = FieldValue.serverTimestamp()
        let challengeTitle = "NFL Pick 'Em — Week \(week) Winner"
        let note = "NFL Pick 'Em Week \(week) Winner Bonus (+1)"

        for pid in winners {
            let awardId = "nfl_pickem_w\(week)_winner_\(pid)"
            let awardRef = db.collection("point_awards").document(awardId)
            batch.setData([
                "playerId": pid,
                "challengeId": "nfl_pickem_w\(week)_winner",
                "challengeTitle": challengeTitle,
                "note": note,
                "points": 1.0,
                "basePoints": 1.0,
                "bonusPoints": 0.0,
                "multiplier": NSNull(),
                "createdAt": now,
                "finalizedAt": now
            ], forDocument: awardRef, merge: true)

            let playerRef = db.collection("players").document(pid)
            batch.updateData(["total_points": FieldValue.increment(1.0)], forDocument: playerRef)
        }

        // Mark the week bonus as applied in the challenge doc
        let weekBonusRef = db.collection(challengeId)
            .document("data")
            .collection("week_bonuses")
            .document("week_\(week)")

        batch.setData([
            "week": week,
            "applied": true,
            "winners": winners,
            "appliedAt": now
        ], forDocument: weekBonusRef, merge: true)

        try await batch.commit()
    }

    // MARK: - Helpers

    func games(for week: Int) -> [NFLPickEmGame] {
        games.filter { $0.week == week }.sorted { $0.kickoffTime < $1.kickoffTime }
    }

    func weekRow(for week: Int, linkedPlayerId: String) -> NFLPickEmWeekRow? {
        guard let entry = allEntries.first(where: { $0.linkedPlayerId == linkedPlayerId }) else { return nil }
        let weekGames = games(for: week).filter { $0.isFinal }
        guard !weekGames.isEmpty else { return nil }

        let correct = weekGames.filter { game in
            guard let winner = game.winnerId else { return false }
            return entry.picks[game.id] == winner
        }.count

        let maxCorrect = allEntries.map { e in
            weekGames.filter { g in
                guard let w = g.winnerId else { return false }
                return e.picks[g.id] == w
            }.count
        }.max() ?? 0

        return NFLPickEmWeekRow(
            id: linkedPlayerId,
            linkedPlayerId: linkedPlayerId,
            displayName: entry.displayName,
            correctPicks: correct,
            totalGames: weekGames.count,
            isWinner: correct == maxCorrect && correct > 0
        )
    }

    /// Current active week (based on today's date vs game schedule)
    var currentWeek: Int {
        let now = Date()
        // Find the latest week that has already started or the earliest upcoming
        let startedWeeks = games.filter { $0.kickoffTime <= now }.map { $0.week }
        if let max = startedWeeks.max() { return max }
        let upcomingWeeks = games.filter { $0.kickoffTime > now }.map { $0.week }
        return upcomingWeeks.min() ?? 1
    }

    var availableWeeks: [Int] {
        Array(Set(games.map { $0.week })).sorted()
    }

    /// Whether the weekly bonus has been applied for a given week
    @Published var appliedWeekBonuses: Set<Int> = []

    func listenWeekBonuses() {
        db.collection(challengeId)
            .document("data")
            .collection("week_bonuses")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                let applied = snap?.documents.compactMap { doc -> Int? in
                    guard (doc.data()["applied"] as? Bool) == true else { return nil }
                    return doc.data()["week"] as? Int
                } ?? []
                self.appliedWeekBonuses = Set(applied)
            }
    }
}

// MARK: - Errors

enum PickEmError: LocalizedError {
    case notLinked, gameLocked, gameNotFound, weekNotFinalized, noWinners

    var errorDescription: String? {
        switch self {
        case .notLinked:        return "Your account isn't linked to a player yet."
        case .gameLocked:       return "This game has already kicked off — pick is locked."
        case .gameNotFound:     return "Game not found."
        case .weekNotFinalized: return "Not all games in this week have a final result yet."
        case .noWinners:        return "No eligible winners found for this week."
        }
    }
}
