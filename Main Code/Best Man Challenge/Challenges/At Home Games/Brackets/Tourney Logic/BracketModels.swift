import Foundation
import FirebaseFirestore

// MARK: - Game Meta

struct BMCBracketGameMeta: Identifiable {
    let id: String
    let title: String
    let state: String
    /// Canonical lock timestamp ("locksAt" in Firestore). Some older docs may use "lockAt".
    let locksAt: Date?
    /// Optional start timestamp ("startsAt" in Firestore)
    let startsAt: Date?
    let scoring: BMCBracketScoringRules

    /// Back-compat alias used by some views.
    var lockAt: Date? { locksAt }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.title = (data["title"] as? String) ?? "Bracket"
        self.state = (data["state"] as? String) ?? "coming_up"

        // locksAt (preferred) or lockAt (legacy)
        if let ts = (data["locksAt"] as? Timestamp) ?? (data["lockAt"] as? Timestamp) {
            self.locksAt = ts.dateValue()
        } else if let d = (data["locksAt"] as? Date) ?? (data["lockAt"] as? Date) {
            self.locksAt = d
        } else {
            self.locksAt = nil
        }

        if let ts = data["startsAt"] as? Timestamp {
            self.startsAt = ts.dateValue()
        } else if let d = data["startsAt"] as? Date {
            self.startsAt = d
        } else {
            self.startsAt = nil
        }

        self.scoring = BMCBracketScoringRules(data: data["scoring"] as? [String: Any])
    }
}

// MARK: - Teams

struct BMCBracketTeam {
    let id: String
    let name: String
    let seed: Int
    let logoAsset: String?

    init(id: String, data: [String: Any]) {
        self.id = id
        self.name = data["name"] as? String ?? "Unknown"
        self.seed = data["seed"] as? Int ?? 0
        self.logoAsset = data["logoAsset"] as? String
    }
}

// MARK: - Matchups

struct BMCBracketMatchup: Identifiable, Hashable {
    let id: String
    let round: Int
    let gameNumber: Int
    let homeTeamId: String?
    let awayTeamId: String?

    // For bracket graph / advancement
    let nextMatchupId: String?
    let nextSlot: String? // "home" or "away"

    // Final result
    let winnerTeamId: String?

    init(id: String, data: [String: Any]) {
        self.id = id
        self.round = (data["round"] as? Int) ?? 1
        self.gameNumber = (data["gameNumber"] as? Int) ?? 0
        self.homeTeamId = data["homeTeamId"] as? String
        self.awayTeamId = data["awayTeamId"] as? String
        self.nextMatchupId = data["nextMatchupId"] as? String
        self.nextSlot = data["nextSlot"] as? String
        self.winnerTeamId = data["winnerTeamId"] as? String
    }
}

// MARK: - Picks Doc (one per player)

struct BMCBracketPicksDoc: Identifiable {
    let id: String // playerId
    let playerId: String
    let isLocked: Bool
    let selections: [String: String] // matchupId -> teamId
    let updatedAt: Date?

    init(id: String, data: [String: Any]) {
        self.id = id
        self.playerId = (data["playerId"] as? String) ?? id
        self.isLocked = (data["isLocked"] as? Bool) ?? false
        self.selections = (data["selections"] as? [String: String]) ?? [:]

        if let ts = data["updatedAt"] as? Timestamp {
            self.updatedAt = ts.dateValue()
        } else if let d = data["updatedAt"] as? Date {
            self.updatedAt = d
        } else {
            self.updatedAt = nil
        }
    }
}

// MARK: - Scoring

struct BMCBracketScoringRules: Hashable {
    /// Stored in Firestore as scoring.byRound = { "1": 1, "2": 2, ... }
    let byRound: [Int: Int]

    init(data: [String: Any]?) {
        // defaults = March Madness style
        var parsed: [Int: Int] = [:]

        if
            let data = data,
            let by = data["byRound"] as? [String: Any]
        {
            for (k, v) in by {
                let r = Int(k) ?? 0
                if let i = v as? Int {
                    parsed[r] = i
                } else if let n = v as? NSNumber {
                    parsed[r] = n.intValue
                }
            }
        }

        if parsed.isEmpty {
            // 1,2,4,8,16,32... up to 20 rounds if needed
            var pts = 1
            for r in 1...20 {
                parsed[r] = pts
                pts *= 2
            }
        }

        self.byRound = parsed
    }

    func pointsPerCorrect(forRound round: Int) -> Int {
        byRound[round] ?? 0
    }
}

struct BMCBracketScoreBreakdown: Hashable {
    let totalPoints: Int
    let correctByRound: [Int: Int]
    let pointsByRound: [Int: Int]
}

// MARK: - Standings

struct BMCBracketStanding: Identifiable, Hashable {
    let id: String // playerId
    let playerId: String
    let displayName: String?
    let points: Int
    let correctByRound: [String: Int]
    let pointsByRound: [String: Int]

    init(id: String, data: [String: Any]) {
        self.id = id
        self.playerId = (data["playerId"] as? String) ?? id
        self.displayName = data["displayName"] as? String
        self.points = (data["points"] as? Int) ?? 0
        self.correctByRound = (data["correctByRound"] as? [String: Int]) ?? [:]
        self.pointsByRound = (data["pointsByRound"] as? [String: Int]) ?? [:]
    }
}
