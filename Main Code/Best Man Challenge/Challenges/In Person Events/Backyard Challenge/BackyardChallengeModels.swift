import Foundation

enum BackyardGameSection: String, CaseIterable, Identifiable {
    case bucketGolf = "Bucket Golf"
    case cornhole = "Cornhole"
    case qb54 = "QB54"
    case ladderBall = "Ladder Ball"
    case relayRace = "Relay Race"
    case overallLeaderboard = "Overall Backyard Game Leaderboard"
    case adminReset = "Admin Reset / Testing"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .bucketGolf: return "figure.golf"
        case .cornhole: return "circle.grid.cross"
        case .qb54: return "football"
        case .ladderBall: return "target"
        case .relayRace: return "figure.run"
        case .overallLeaderboard: return "trophy"
        case .adminReset: return "trash"
        }
    }
}

enum BackyardGameId: String, CaseIterable, Identifiable {
    case bucketGolfInd18 = "bucket_golf_ind_18"
    case bucketGolfAlt9 = "bucket_golf_alt_9"
    case bucketGolfClosest = "bucket_golf_closest_to_pin"

    case cornholeDeka = "cornhole_deka"
    case cornholeSingles = "cornhole_singles"
    case cornholeDoubles = "cornhole_doubles"

    case ladderBallIndividual = "ladder_ball_individual"
    case ladderBallDoubles = "ladder_ball_doubles"

    case qb54Individual = "qb54_individual"
    case qb54Doubles = "qb54_doubles"

    case relayRace = "relay_race"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bucketGolfInd18: return "18 Holes Individual"
        case .bucketGolfAlt9: return "9 Hole Alt Shot"
        case .bucketGolfClosest: return "Closest to the Pin"
        case .cornholeDeka: return "Cornhole Deka"
        case .cornholeSingles: return "Singles Tournament"
        case .cornholeDoubles: return "Doubles Tournament"
        case .ladderBallIndividual: return "Individual Tournament"
        case .ladderBallDoubles: return "Doubles Tournament"
        case .qb54Individual: return "Individual Tournament"
        case .qb54Doubles: return "Doubles Tournament"
        case .relayRace: return "Relay Race"
        }
    }

    var scoringLabel: String {
        switch self {
        case .bucketGolfInd18: return "Mario Kart x3"
        case .bucketGolfAlt9: return "Score Based Doubles: 10, 8, 6, 4, 2, 1"
        case .bucketGolfClosest: return "Mario Kart x1"
        case .cornholeDeka: return "Mario Kart x2"
        case .cornholeSingles: return "Gold / Silver / Bronze bracket bonus"
        case .cornholeDoubles: return "Double Elimination: 10, 8, 6, 4, 2, 1"
        case .ladderBallIndividual: return "Mario Kart x2"
        case .ladderBallDoubles: return "Double Elimination: 10, 8, 6, 4, 2, 1"
        case .qb54Individual: return "Mario Kart x2, first to 24"
        case .qb54Doubles: return "Double Elimination: 10, 8, 6, 4, 2, 1"
        case .relayRace: return "Team finish: 15, 7, 3 per player"
        }
    }

    var lowerIsBetter: Bool {
        switch self {
        case .bucketGolfInd18, .bucketGolfAlt9, .bucketGolfClosest, .relayRace,
             .qb54Individual, .qb54Doubles,
             .ladderBallIndividual, .ladderBallDoubles,
             .cornholeDoubles:
            // These games store placement (1 = best), so lower raw score = higher rank
            return true
        default:
            return false
        }
    }

    var usesFinalScoreInput: Bool {
        switch self {
        case .bucketGolfInd18, .cornholeDeka, .bucketGolfClosest, .cornholeSingles, .relayRace:
            return false
        default:
            return true
        }
    }
}

struct BackyardPlayer: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String

    static let defaults: [BackyardPlayer] = [
        .init(id: "bret", displayName: "Bret"),
        .init(id: "kyle", displayName: "Kyle"),
        .init(id: "anthony", displayName: "Anthony"),
        .init(id: "matt_p", displayName: "Matthew Page"),
        .init(id: "matt_c", displayName: "Matthew Carlos"),
        .init(id: "ronnie", displayName: "Ronnie"),
        .init(id: "joel", displayName: "Joel"),
        .init(id: "isaiah", displayName: "Isaiah"),
        .init(id: "mitch", displayName: "Mitch"),
        .init(id: "valentino", displayName: "Valentino"),
        .init(id: "jake", displayName: "Jake"),
        .init(id: "danny", displayName: "Danny")
    ]
}



struct BucketGolfGroup: Identifiable, Hashable {
    let id: String
    let playerIds: [String]
}

extension BackyardPlayer {
    static let bucketGolfGroups: [BucketGolfGroup] = [
        BucketGolfGroup(id: "tee_time_1", playerIds: ["joel", "mitch", "anthony", "danny"]),
        BucketGolfGroup(id: "tee_time_2", playerIds: ["kyle", "valentino", "matt_p", "isaiah"]),
        BucketGolfGroup(id: "tee_time_3", playerIds: ["bret", "jake", "matt_c", "ronnie"])
    ]

    static func bucketGolfGroupPlayerIds(for playerId: String) -> [String] {
        bucketGolfGroups.first { $0.playerIds.contains(playerId) }?.playerIds ?? [playerId]
    }
}

struct BackyardStandingRow: Identifiable, Hashable {
    var id: String { playerId }
    let playerId: String
    let displayName: String
    let rawScore: Double
    let points: Int
    let thru: Int?
}

struct BackyardTeam: Identifiable, Hashable {
    let id: String
    let name: String
    let players: [BackyardPlayer]
}

enum BackyardScoring {
    static let marioKartBase = [15, 12, 10, 8, 7, 6, 5, 4, 3, 2, 1, 0]
    static let doubles = [10, 8, 6, 4, 2, 1]
    static let relay = [15, 7, 3]

    static func marioKartPoints(rankIndex: Int, multiplier: Int) -> Int {
        guard marioKartBase.indices.contains(rankIndex) else { return 0 }
        return marioKartBase[rankIndex] * multiplier
    }

    static func doublesPoints(rankIndex: Int) -> Int {
        guard doubles.indices.contains(rankIndex) else { return 0 }
        return doubles[rankIndex]
    }

    static func relayPoints(rankIndex: Int) -> Int {
        guard relay.indices.contains(rankIndex) else { return 0 }
        return relay[rankIndex]
    }
}

enum CornholeSinglesBracket: String, CaseIterable, Identifiable {
    case gold
    case silver
    case bronze

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gold: return "Gold Bracket"
        case .silver: return "Silver Bracket"
        case .bronze: return "Bronze Bracket"
        }
    }

    var seedRange: ClosedRange<Int> {
        switch self {
        case .gold: return 1...4
        case .silver: return 5...8
        case .bronze: return 9...12
        }
    }
}
