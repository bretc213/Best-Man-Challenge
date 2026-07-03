//
//  GolfEventStore.swift
//  Best Man Challenge
//

import Foundation
import FirebaseFirestore

@MainActor
final class GolfEventStore: ObservableObject {

    private static let docPath = "in_person_events/golf_2026"
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // MARK: - Published state

    @Published var allPlayers: [FirestorePlayer] = []
    @Published var eventState: GolfEventState = .empty
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Lifecycle

    func start() {
        isLoading = true
        fetchPlayers()
        listenToEvent()
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Load

    private func fetchPlayers() {
        db.collection("players")
            .order(by: "display_name")
            .getDocuments { [weak self] snap, err in
                guard let self else { return }
                if let err { self.errorMessage = err.localizedDescription; return }
                self.allPlayers = (snap?.documents ?? []).compactMap {
                    FirestorePlayer(id: $0.documentID, data: $0.data())
                }
            }
    }

    private func listenToEvent() {
        let ref = db.document(GolfEventStore.docPath)
        listener = ref.addSnapshotListener { [weak self] snap, err in
            guard let self else { return }
            self.isLoading = false
            if let err { self.errorMessage = err.localizedDescription; return }
            if let data = snap?.data() {
                self.eventState = GolfEventState(from: data)
            }
        }
    }

    // MARK: - Sim score entry

    func saveSimScores(_ scores: [String: Int]) async throws {
        let ref = db.document(GolfEventStore.docPath)
        try await ref.setData([
            "sim_scores": scores,
            "teams_generated": false,
            "teams": [],
            "updated_at": FieldValue.serverTimestamp()
        ], merge: true)
    }

    // MARK: - Team generation

    /// Ranks sim entries (lowest score = best). Ties are broken randomly (coin flip).
    /// Returns a ranked list; caller can re-call to re-flip.
    func rankSimEntries() -> [GolfSimEntry] {
        let scored = allPlayers.compactMap { p -> (player: FirestorePlayer, score: Int)? in
            guard let s = eventState.simScores[p.id] else { return nil }
            return (p, s)
        }

        // Group by score
        let groups: [[FirestorePlayer]] = Dictionary(grouping: scored, by: { $0.score })
            .sorted { $0.key < $1.key }
            .map { $0.value.map { $0.player }.shuffled() }  // shuffle within ties

        var entries: [GolfSimEntry] = []
        var rankIndex = 0
        for group in groups {
            let indices = Array(rankIndex ..< rankIndex + group.count)
            let pts = GolfScoring.sharedPoints(rankIndices: indices, scale: GolfScoring.simInGamePoints)
            for player in group {
                entries.append(GolfSimEntry(
                    playerId: player.id,
                    displayName: player.displayName,
                    score: eventState.simScores[player.id],
                    rankIndex: rankIndex,
                    inGamePoints: pts
                ))
                rankIndex += 1
            }
        }

        // Players with no score go at end with 0 pts
        let scoredIds = Set(scored.map { $0.player.id })
        for player in allPlayers where !scoredIds.contains(player.id) {
            entries.append(GolfSimEntry(
                playerId: player.id,
                displayName: player.displayName,
                score: nil,
                rankIndex: nil,
                inGamePoints: 0
            ))
        }

        return entries
    }

    func buildTeams(from ranked: [GolfSimEntry]) -> [GolfTeamAssignment] {
        let withScores = ranked.filter { $0.score != nil }
        let n = withScores.count
        guard n >= 2 else { return [] }

        var teams: [GolfTeamAssignment] = []
        let pairs = n / 2
        for i in 0 ..< pairs {
            let pA = withScores[i]
            let pB = withScores[n - 1 - i]
            teams.append(GolfTeamAssignment(
                id: "t\(i + 1)",
                playerAId: pA.playerId,
                playerBId: pB.playerId,
                playerAName: pA.displayName,
                playerBName: pB.displayName
            ))
        }
        return teams
    }

    func saveTeams(_ teams: [GolfTeamAssignment]) async throws {
        let teamsData: [[String: Any]] = teams.map { t in
            [
                "team_id": t.id,
                "player_a": t.playerAId,
                "player_b": t.playerBId,
                "player_a_name": t.playerAName,
                "player_b_name": t.playerBName
            ]
        }
        let ref = db.document(GolfEventStore.docPath)
        try await ref.setData([
            "teams": teamsData,
            "teams_generated": true,
            "updated_at": FieldValue.serverTimestamp()
        ], merge: true)
    }

    // MARK: - Scramble score entry

    func saveScrambleScores(_ scores: [String: Int]) async throws {
        let ref = db.document(GolfEventStore.docPath)
        try await ref.setData([
            "scramble_scores": scores,
            "updated_at": FieldValue.serverTimestamp()
        ], merge: true)
    }

    // MARK: - Computed leaderboards

    var simLeaderboard: [GolfSimEntry] {
        let scored = allPlayers.compactMap { p -> (FirestorePlayer, Int)? in
            guard let s = eventState.simScores[p.id] else { return nil }
            return (p, s)
        }.sorted { $0.1 < $1.1 }

        var entries: [GolfSimEntry] = []
        var idx = 0
        var i = 0
        while i < scored.count {
            let score = scored[i].1
            var group: [FirestorePlayer] = []
            var j = i
            while j < scored.count && scored[j].1 == score { group.append(scored[j].0); j += 1 }
            let indices = Array(idx ..< idx + group.count)
            let pts = GolfScoring.sharedPoints(rankIndices: indices, scale: GolfScoring.simInGamePoints)
            for p in group {
                entries.append(GolfSimEntry(playerId: p.id, displayName: p.displayName,
                                            score: score, rankIndex: idx, inGamePoints: pts))
            }
            idx += group.count
            i = j
        }
        return entries
    }

    var duosLeaderboard: [GolfTeamResult] {
        let teams = eventState.teams
        let scored = teams.compactMap { t -> (GolfTeamAssignment, Int)? in
            guard let s = eventState.scrambleScores[t.id] else { return nil }
            return (t, s)
        }.sorted { $0.1 < $1.1 }

        var results: [GolfTeamResult] = []
        var idx = 0
        var i = 0
        while i < scored.count {
            let score = scored[i].1
            var group: [GolfTeamAssignment] = []
            var j = i
            while j < scored.count && scored[j].1 == score { group.append(scored[j].0); j += 1 }
            let indices = Array(idx ..< idx + group.count)
            let pts = GolfScoring.sharedPoints(rankIndices: indices, scale: GolfScoring.scramblePointsPerPlayer)
            for t in group {
                results.append(GolfTeamResult(assignment: t, scrambleScore: score, rankIndex: idx, pointsPerPlayer: pts))
            }
            idx += group.count
            i = j
        }

        // Append un-scored teams
        let scoredIds = Set(scored.map { $0.0.id })
        for t in teams where !scoredIds.contains(t.id) {
            results.append(GolfTeamResult(assignment: t, scrambleScore: nil, rankIndex: nil, pointsPerPlayer: 0))
        }
        return results
    }

    var overallLeaderboard: [GolfOverallEntry] {
        // Build sim points map
        let simMap: [String: Double] = simLeaderboard.reduce(into: [:]) { $0[$1.playerId] = $1.inGamePoints }

        // Build scramble points map
        let scrMap: [String: Double] = duosLeaderboard.reduce(into: [:]) { result, team in
            result[team.assignment.playerAId] = team.pointsPerPlayer
            result[team.assignment.playerBId] = team.pointsPerPlayer
        }

        // Build entries for all players
        var entries: [GolfOverallEntry] = allPlayers.map { p in
            let sim = simMap[p.id] ?? 0
            let scr = scrMap[p.id] ?? 0
            return GolfOverallEntry(
                playerId: p.id,
                displayName: p.displayName,
                simPoints: sim,
                scramblePoints: scr,
                totalPoints: sim + scr,
                overallRankIndex: nil,
                bmcRankIndex: nil,
                bmcBase: 0,
                bretBonus: 0
            )
        }.sorted { $0.totalPoints > $1.totalPoints }

        // Assign overall rank indices (with ties)
        var rankIdx = 0
        var i = 0
        while i < entries.count {
            let pts = entries[i].totalPoints
            var j = i
            while j < entries.count && entries[j].totalPoints == pts { j += 1 }
            for k in i ..< j { entries[k].overallRankIndex = rankIdx }
            rankIdx += (j - i)
            i = j
        }

        // Find Bret's overall rank
        let bretOverallRank = entries.first(where: { $0.isBret })?.overallRankIndex ?? Int.max

        // Assign BMC points to non-Bret players
        let nonBret = entries.filter { !$0.isBret }.sorted { ($0.overallRankIndex ?? 99) < ($1.overallRankIndex ?? 99) }
        var bmcIdx = 0
        var ni = 0
        while ni < nonBret.count {
            let oRank = nonBret[ni].overallRankIndex ?? 99
            var nj = ni
            while nj < nonBret.count && (nonBret[nj].overallRankIndex ?? 99) == oRank { nj += 1 }
            let bmcIndices = Array(bmcIdx ..< bmcIdx + (nj - ni))
            let bmcPts = GolfScoring.sharedPoints(rankIndices: bmcIndices, scale: GolfScoring.bmcPoints)
            for k in ni ..< nj {
                if let idx = entries.firstIndex(where: { $0.playerId == nonBret[k].playerId }) {
                    entries[idx].bmcRankIndex = bmcIdx
                    entries[idx].bmcBase = bmcPts
                    let aboveBret = (entries[idx].overallRankIndex ?? 99) < bretOverallRank
                    entries[idx].bretBonus = aboveBret ? 3 : 0
                }
            }
            bmcIdx += (nj - ni)
            ni = nj
        }

        return entries
    }

    // MARK: - Reset (testing only)

    /// Wipes all golf event data and reverses any awarded BMC points.
    func resetEvent() async throws {
        let ref = db.document(GolfEventStore.docPath)

        // 1. Find and reverse any point_awards for this event
        let awardsSnap = try await db.collection("point_awards")
            .whereField("challengeId", isEqualTo: "golf_2026")
            .getDocuments()

        if !awardsSnap.documents.isEmpty {
            let batch = db.batch()
            for doc in awardsSnap.documents {
                let data = doc.data()
                let points = (data["points"] as? NSNumber)?.doubleValue ?? 0
                let playerId = data["playerId"] as? String ?? ""
                if points > 0 && !playerId.isEmpty {
                    let playerRef = db.collection("players").document(playerId)
                    batch.updateData(
                        ["total_points": FieldValue.increment(-points)],
                        forDocument: playerRef
                    )
                }
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
        }

        // 2. Reset the event document to a blank state
        try await ref.setData([
            "sim_scores": [String: Int](),
            "teams": [[String: Any]](),
            "teams_generated": false,
            "scramble_scores": [String: Int](),
            "is_finalized": false,
            "updated_at": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - Finalize

    func finalizeEvent() async throws {
        let leaderboard = overallLeaderboard
        let ref = db.document(GolfEventStore.docPath)
        let now = FieldValue.serverTimestamp()
        let batch = db.batch()

        for entry in leaderboard where !entry.isBret {
            let totalBMC = entry.totalBMC
            guard totalBMC > 0 else { continue }

            // Base award
            let baseId = "golf_2026_\(entry.playerId)"
            let baseRef = db.collection("point_awards").document(baseId)
            batch.setData([
                "playerId": entry.playerId,
                "challengeId": "golf_2026",
                "challengeTitle": "Golf Event 2026 — Overall",
                "basePoints": entry.bmcBase,
                "bonusPoints": entry.bretBonus,
                "multiplier": NSNull(),
                "points": totalBMC,
                "createdAt": now,
                "updatedAt": now
            ], forDocument: baseRef, merge: false)

            let playerRef = db.collection("players").document(entry.playerId)
            batch.updateData(["total_points": FieldValue.increment(totalBMC)], forDocument: playerRef)
        }

        batch.setData([
            "is_finalized": true,
            "finalized_at": now,
            "updated_at": now
        ], forDocument: ref, merge: true)

        try await batch.commit()
    }
}
