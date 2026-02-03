import Foundation
import FirebaseFirestore

struct TourneyGameMeta: Identifiable {
    let id: String
    let title: String
    let status: String
    let lockAt: Date?
    let startsAt: Date?

    init?(id: String, data: [String: Any]) {
        self.id = id
        self.title = (data["title"] as? String) ?? id
        self.status = (data["status"] as? String) ?? "setup"

        if let ts = data["lockAt"] as? Timestamp { self.lockAt = ts.dateValue() } else { self.lockAt = nil }
        if let ts = data["startsAt"] as? Timestamp { self.startsAt = ts.dateValue() } else { self.startsAt = nil }
    }
}

struct TourneyTeam: Identifiable, Hashable {
    let id: String
    let name: String
    let seed: Int?
    let logoAsset: String?

    init?(id: String, data: [String: Any]) {
        self.id = id
        self.name = (data["name"] as? String) ?? id
        self.seed = (data["seed"] as? NSNumber)?.intValue
        self.logoAsset = data["logoAsset"] as? String
    }
}

struct TourneyMatchup: Identifiable, Hashable {
    let id: String
    let round: Int
    let gameNumber: Int
    let homeTeamId: String?
    let awayTeamId: String?
    let winnerTeamId: String?

    // ✅ NEW (bracket graph wiring)
    let nextMatchupId: String?
    let nextSlot: String? // "home" or "away"

    init?(id: String, data: [String: Any]) {
        self.id = id
        self.round = (data["round"] as? NSNumber)?.intValue ?? 0
        self.gameNumber = (data["gameNumber"] as? NSNumber)?.intValue ?? 0
        self.homeTeamId = data["homeTeamId"] as? String
        self.awayTeamId = data["awayTeamId"] as? String
        self.winnerTeamId = data["winnerTeamId"] as? String

        self.nextMatchupId = data["nextMatchupId"] as? String
        self.nextSlot = data["nextSlot"] as? String
    }
}

struct TourneyPicksDoc: Identifiable {
    let id: String // playerId
    let isLocked: Bool
    let selections: [String: String] // matchupId -> teamId

    init?(id: String, data: [String: Any]) {
        self.id = id
        self.isLocked = (data["isLocked"] as? Bool) ?? false
        self.selections = (data["selections"] as? [String: String]) ?? [:]
    }
}
