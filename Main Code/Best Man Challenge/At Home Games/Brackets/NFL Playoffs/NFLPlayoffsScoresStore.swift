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
                    
                    // read picks dictionary and then merge champs (futures) into it
                    var picks = d["picks"] as? [String: String] ?? [:]
                    
                    // Normalize existing picks' keys to lowercase and values trimmed
                    var normalized: [String: String] = [:]
                    for (k, v) in picks {
                        let nk = k.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let nv = v.trimmingCharacters(in: .whitespacesAndNewlines)
                        normalized[nk] = nv
                    }
                    picks = normalized
                    
                    if let champsAny = d["champs"] as? [String: Any] {
                        // normalize champs values to strings and add multiple candidate keys (lowercased)
                        for (ck, cvAny) in champsAny {
                            if let cv = cvAny as? String {
                                let keyLower = ck.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                let valueTrimmed = cv.trimmingCharacters(in: .whitespacesAndNewlines)
                                
                                // direct champ key (e.g., "afc","nfc","superbowl")
                                picks[keyLower] = valueTrimmed
                                // alternative keys to increase matching resiliency (all lowercased)
                                picks["champs_\(keyLower)"] = valueTrimmed
                                picks["champ:\(keyLower)"] = valueTrimmed
                            }
                        }
                    }
                    
                    var current = self.picksByPlayer[scopedId]?.picks ?? [:]
                    // merge normalized picks into current (also normalize current keys)
                    var merged: [String: String] = [:]
                    for (k, v) in current {
                        merged[k.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] = v.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    for (k, v) in picks {
                        merged[k.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] = v.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    self.picksByPlayer[scopedId] = (displayName: dn, picks: merged)
                }
                
                self.recomputeScores()
            }
        }
        
        picksListeners[key] = listener
    }
    
    
    // MARK: - Compute totals
    
    private func recomputeScores() {
        let regularPickPoints = 2
        let conferenceFuturePoints = 4
        let superBowlFuturePoints = 8

        func norm(_ s: String) -> String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return String(trimmed.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
        }

        func equalsTeam(_ a: String?, _ b: String?) -> Bool {
            guard let a, let b else { return false }
            let na = norm(a)
            let nb = norm(b)
            return !na.isEmpty && na == nb
        }

        func futuresKeyForMatchupId(_ matchupId: String) -> String? {
            let id = matchupId.lowercased()

            // Your current conference matchup ids look like:
            // conf_2026_01_ne_den  (AFC)
            // conf_2026_02_lar_sea (NFC)
            // So we map _01_ => afc, _02_ => nfc
            if id.hasPrefix("conf_") {
                if id.contains("_01_") { return "afc" }
                if id.contains("_02_") { return "nfc" }
                // If you ever rename ids, this is the only mapping you’ll need to update.
                return nil
            }

            // Super Bowl (adjust if your doc id format differs)
            if id.hasPrefix("sb_") || id.contains("superbowl") || id.contains("super_bowl") {
                return "superbowl"
            }

            return nil
        }

        guard points != nil else { return } // points exists but regular scoring is fixed at 2 in your rules

        var rows: [BracketScoreRow] = []

        for (playerId, meta) in picksByPlayer {
            let displayName = meta.displayName

            // Picks are already merged across rounds; ensure stable casing on keys
            let picks: [String: String] = Dictionary(uniqueKeysWithValues:
                meta.picks.map { (k, v) in
                    (k.trimmingCharacters(in: .whitespacesAndNewlines), v.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            )

            var total = 0
            var correct = 0

            var breakdown: [String: Int] = [
                "wildcard": 0,
                "divisional": 0,
                "conference": 0,
                "superBowl": 0
            ]

            for (matchupId, winMeta) in winnerByMatchup {
                let winner = winMeta.winnerTeamId

                // 1) Regular weekly matchup scoring (+2) — if they made that matchup pick
                if equalsTeam(picks[matchupId], winner) {
                    total += regularPickPoints
                    correct += 1
                    breakdown[winMeta.round.rawValue, default: 0] += regularPickPoints
                }

                // 2) Futures bonus scoring (+4 / +8) — independent of weekly pick
                if let futuresKey = futuresKeyForMatchupId(matchupId) {
                    // champs are merged into picks as keys like "afc", "nfc", "superBowl"/etc
                    // We support a few common variants for safety.
                    let candidateKeys: [String]
                    switch futuresKey {
                    case "afc":
                        candidateKeys = ["afc", "champs_afc", "champ:afc"]
                        if candidateKeys.contains(where: { equalsTeam(picks[$0], winner) }) {
                            total += conferenceFuturePoints
                            breakdown["conference", default: 0] += conferenceFuturePoints
                        }
                    case "nfc":
                        candidateKeys = ["nfc", "champs_nfc", "champ:nfc"]
                        if candidateKeys.contains(where: { equalsTeam(picks[$0], winner) }) {
                            total += conferenceFuturePoints
                            breakdown["conference", default: 0] += conferenceFuturePoints
                        }
                    case "superbowl":
                        candidateKeys = ["superbowl", "superBowl", "champs_superbowl", "champs_superBowl", "champ:superbowl", "champ:superBowl"]
                        if candidateKeys.contains(where: { equalsTeam(picks[$0], winner) }) {
                            total += superBowlFuturePoints
                            breakdown["superBowl", default: 0] += superBowlFuturePoints
                        }
                    default:
                        break
                    }
                }
            }

            rows.append(
                BracketScoreRow(
                    id: playerId,
                    linkedPlayerId: playerId,
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
