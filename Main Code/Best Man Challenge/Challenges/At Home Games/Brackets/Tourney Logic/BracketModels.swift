
import Foundation
import FirebaseFirestore

struct BMCBracketGameMeta: Identifiable {
    let id: String
    let title: String
    let state: String
    let locksAt: Date?
    let startsAt: Date?
    let isFinalized: Bool
    let finalizedAt: Date?
    let finalizedBy: String?
    let scoring: BMCBracketScoringRules

    var lockAt: Date? { locksAt }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.title = (data["title"] as? String) ?? "Bracket"
        self.state = (data["state"] as? String) ?? "coming_up"
        self.isFinalized = (data["isFinalized"] as? Bool) ?? false
        self.finalizedBy = data["finalizedBy"] as? String

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

        if let ts = data["finalizedAt"] as? Timestamp {
            self.finalizedAt = ts.dateValue()
        } else if let d = data["finalizedAt"] as? Date {
            self.finalizedAt = d
        } else {
            self.finalizedAt = nil
        }

        self.scoring = BMCBracketScoringRules(data: data["scoring"] as? [String: Any])
    }
}

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

struct BMCBracketMatchup: Identifiable, Hashable {
    let id: String
    let round: Int
    let gameNumber: Int
    let homeTeamId: String?
    let awayTeamId: String?
    let nextMatchupId: String?
    let nextSlot: String?
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

struct BMCBracketPicksDoc: Identifiable {
    let id: String
    let playerId: String
    let isLocked: Bool
    let selections: [String: String]
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

struct BMCBracketScoringRules: Hashable {
    let byRound: [Int: Int]

    init(data: [String: Any]?) {
        var parsed: [Int: Int] = [:]

        if let data,
           let by = data["byRound"] as? [String: Any] {
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

struct BMCBracketStanding: Identifiable, Hashable {
    let id: String
    let playerId: String
    let displayName: String?
    let points: Int
    let maxPotentialPoints: Int
    let correctByRound: [String: Int]
    let pointsByRound: [String: Int]

    var remainingPossiblePoints: Int {
        max(0, maxPotentialPoints - points)
    }

    init(id: String, data: [String: Any]) {
        self.id = id
        self.playerId = (data["playerId"] as? String) ?? id
        self.displayName = data["displayName"] as? String
        self.points = (data["points"] as? Int) ?? ((data["points"] as? NSNumber)?.intValue ?? 0)
        self.maxPotentialPoints = (data["maxPotentialPoints"] as? Int) ?? ((data["maxPotentialPoints"] as? NSNumber)?.intValue ?? self.points)
        self.correctByRound = (data["correctByRound"] as? [String: Int]) ?? [:]
        self.pointsByRound = (data["pointsByRound"] as? [String: Int]) ?? [:]
    }
}
