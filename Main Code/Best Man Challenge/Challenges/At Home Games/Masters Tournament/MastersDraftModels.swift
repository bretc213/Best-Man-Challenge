import Foundation
import FirebaseFirestore

struct MastersDraftMeta: Identifiable {
    let id: String
    let title: String
    let state: String
    let startsAt: Date?
    let draftStartsAt: Date?
    let isFinalized: Bool
    let finalizedAt: Date?
    let finalizedBy: String?
    let lastUpdated: Date?
    let roundCount: Int
    let draftOrder: [String]
    let currentRound: Int
    let currentOverallPick: Int
    let currentDrafterPlayerId: String?
    let pointsMultiplier: Double
    let atHomeGameId: String?

    init(id: String, data: [String: Any]) {
        self.id = id
        self.title = (data["title"] as? String) ?? "The Masters Draft"
        self.state = (data["state"] as? String) ?? "coming_up"
        self.isFinalized = (data["isFinalized"] as? Bool) ?? false
        self.finalizedBy = data["finalizedBy"] as? String
        self.roundCount = (data["roundCount"] as? NSNumber)?.intValue ?? 4
        self.draftOrder = (data["draftOrder"] as? [String]) ?? []
        self.currentRound = (data["currentRound"] as? NSNumber)?.intValue ?? 1
        self.currentOverallPick = (data["currentOverallPick"] as? NSNumber)?.intValue ?? 1
        self.currentDrafterPlayerId = data["currentDrafterPlayerId"] as? String
        self.pointsMultiplier = (data["pointsMultiplier"] as? NSNumber)?.doubleValue ?? 1.0
        self.atHomeGameId = data["atHomeGameId"] as? String

        func parseDate(_ key: String) -> Date? {
            if let ts = data[key] as? Timestamp { return ts.dateValue() }
            if let d = data[key] as? Date { return d }
            return nil
        }

        self.startsAt = parseDate("startsAt")
        self.draftStartsAt = parseDate("draftStartsAt")
        self.finalizedAt = parseDate("finalizedAt")
        self.lastUpdated = parseDate("lastUpdated")
    }

    var totalPicks: Int {
        draftOrder.count * roundCount
    }

    var isDraftComplete: Bool {
        state == "live_scoring" || state == "finalized"
    }
}

struct MastersGolfer: Identifiable, Hashable {
    let id: String
    let name: String
    let oddsText: String
    let oddsSort: Int
    let isDrafted: Bool
    let draftedByPlayerId: String?
    let draftRound: Int?
    let overallPick: Int?
    let position: Int?
    let scoreToPar: Int?
    let status: String
    let leaderboardPoints: Int
    let updatedAt: Date?

    init(id: String, data: [String: Any]) {
        self.id = id
        self.name = (data["name"] as? String) ?? id
        self.oddsText = (data["oddsText"] as? String) ?? ""
        self.oddsSort = (data["oddsSort"] as? NSNumber)?.intValue ?? 999999
        self.isDrafted = (data["isDrafted"] as? Bool) ?? false
        self.draftedByPlayerId = data["draftedByPlayerId"] as? String
        self.draftRound = (data["draftRound"] as? NSNumber)?.intValue
        self.overallPick = (data["overallPick"] as? NSNumber)?.intValue
        self.position = (data["position"] as? NSNumber)?.intValue
        self.scoreToPar = (data["scoreToPar"] as? NSNumber)?.intValue
        self.status = (data["status"] as? String) ?? "available"
        self.leaderboardPoints = (data["leaderboardPoints"] as? NSNumber)?.intValue ?? 0

        if let ts = data["updatedAt"] as? Timestamp {
            self.updatedAt = ts.dateValue()
        } else if let d = data["updatedAt"] as? Date {
            self.updatedAt = d
        } else {
            self.updatedAt = nil
        }
    }
}

struct MastersDraftPick: Hashable {
    let golferId: String
    let golferName: String
    let round: Int
    let overallPick: Int
    let draftedAt: Date?

    init(data: [String: Any]) {
        self.golferId = (data["golferId"] as? String) ?? ""
        self.golferName = (data["golferName"] as? String) ?? ""
        self.round = (data["round"] as? NSNumber)?.intValue ?? 0
        self.overallPick = (data["overallPick"] as? NSNumber)?.intValue ?? 0

        if let ts = data["draftedAt"] as? Timestamp {
            self.draftedAt = ts.dateValue()
        } else if let d = data["draftedAt"] as? Date {
            self.draftedAt = d
        } else {
            self.draftedAt = nil
        }
    }

    var firestoreMap: [String: Any] {
        var map: [String: Any] = [
            "golferId": golferId,
            "golferName": golferName,
            "round": round,
            "overallPick": overallPick
        ]
        if let draftedAt {
            map["draftedAt"] = Timestamp(date: draftedAt)
        }
        return map
    }
}

struct MastersRoster: Identifiable {
    let id: String
    let playerId: String
    let displayName: String?
    let golferIds: [String]
    let picks: [MastersDraftPick]
    let totalPoints: Int
    let updatedAt: Date?

    init(id: String, data: [String: Any]) {
        self.id = id
        self.playerId = (data["playerId"] as? String) ?? id
        self.displayName = data["displayName"] as? String
        self.golferIds = (data["golferIds"] as? [String]) ?? []

        let rawPicks = (data["picks"] as? [[String: Any]]) ?? []
        self.picks = rawPicks
            .map(MastersDraftPick.init(data:))
            .sorted {
                if $0.round != $1.round { return $0.round < $1.round }
                return $0.overallPick < $1.overallPick
            }

        self.totalPoints = (data["totalPoints"] as? NSNumber)?.intValue ?? 0

        if let ts = data["updatedAt"] as? Timestamp {
            self.updatedAt = ts.dateValue()
        } else if let d = data["updatedAt"] as? Date {
            self.updatedAt = d
        } else {
            self.updatedAt = nil
        }
    }
}

struct MastersStanding: Identifiable, Hashable {
    let id: String
    let playerId: String
    let displayName: String?
    let points: Int
    let golferPoints: [String: Int]
    let updatedAt: Date?

    init(id: String, data: [String: Any]) {
        self.id = id
        self.playerId = (data["playerId"] as? String) ?? id
        self.displayName = data["displayName"] as? String
        self.points = (data["points"] as? NSNumber)?.intValue ?? 0
        self.golferPoints = (data["golferPoints"] as? [String: Int]) ?? [:]

        if let ts = data["updatedAt"] as? Timestamp {
            self.updatedAt = ts.dateValue()
        } else if let d = data["updatedAt"] as? Date {
            self.updatedAt = d
        } else {
            self.updatedAt = nil
        }
    }
}

enum MastersDraftScoring {
    static func points(for position: Int?, status: String) -> Int {
        let normalized = status.lowercased()
        if ["cut", "missed_cut", "wd", "dq"].contains(normalized) {
            return 0
        }

        guard let position else {
            return 0
        }

        switch position {
        case 1: return 30
        case 2: return 22
        case 3: return 18
        case 4: return 15
        case 5: return 13
        case 6...10: return 10
        case 11...15: return 7
        case 16...20: return 5
        default: return 2
        }
    }

    static func snakePlayerId(order: [String], overallPick: Int, roundCount: Int) -> (round: Int, playerId: String?) {
        guard !order.isEmpty, overallPick >= 1 else { return (1, nil) }

        let roundSize = order.count
        let zeroBased = overallPick - 1
        let round = (zeroBased / roundSize) + 1
        guard round <= roundCount else { return (round, nil) }

        let indexInRound = zeroBased % roundSize
        if round % 2 == 1 {
            return (round, order[indexInRound])
        } else {
            return (round, order[roundSize - 1 - indexInRound])
        }
    }
}
