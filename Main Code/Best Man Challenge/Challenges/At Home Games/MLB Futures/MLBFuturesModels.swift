import Foundation
import FirebaseFirestore

enum MLBFuturesConstants {
    static let challengeId = "mlb_futures"
    static let route = "mlb_futures"
    static let title = "MLB Futures Picks"
    static let subtitle = "Predict division finishes, playoff seeds, and the full postseason path."
    static let assetImage = "MLBFuturesLogo"

    static let worldSeriesWinnerPoints = 20

    static let allDivisions: [MLBDivisionKey] = MLBDivisionKey.allCases

    static func teams(in division: MLBDivisionKey) -> [MLBTeam] {
        switch division {
        case .alEast:
            return [
                .init(id: "BAL", name: "Baltimore Orioles", league: .al, division: .alEast),
                .init(id: "BOS", name: "Boston Red Sox", league: .al, division: .alEast),
                .init(id: "NYY", name: "New York Yankees", league: .al, division: .alEast),
                .init(id: "TB", name: "Tampa Bay Rays", league: .al, division: .alEast),
                .init(id: "TOR", name: "Toronto Blue Jays", league: .al, division: .alEast)
            ]
        case .alCentral:
            return [
                .init(id: "CWS", name: "Chicago White Sox", league: .al, division: .alCentral),
                .init(id: "CLE", name: "Cleveland Guardians", league: .al, division: .alCentral),
                .init(id: "DET", name: "Detroit Tigers", league: .al, division: .alCentral),
                .init(id: "KC", name: "Kansas City Royals", league: .al, division: .alCentral),
                .init(id: "MIN", name: "Minnesota Twins", league: .al, division: .alCentral)
            ]
        case .alWest:
            return [
                .init(id: "ATH", name: "Athletics", league: .al, division: .alWest),
                .init(id: "HOU", name: "Houston Astros", league: .al, division: .alWest),
                .init(id: "LAA", name: "Los Angeles Angels", league: .al, division: .alWest),
                .init(id: "SEA", name: "Seattle Mariners", league: .al, division: .alWest),
                .init(id: "TEX", name: "Texas Rangers", league: .al, division: .alWest)
            ]
        case .nlEast:
            return [
                .init(id: "ATL", name: "Atlanta Braves", league: .nl, division: .nlEast),
                .init(id: "MIA", name: "Miami Marlins", league: .nl, division: .nlEast),
                .init(id: "NYM", name: "New York Mets", league: .nl, division: .nlEast),
                .init(id: "PHI", name: "Philadelphia Phillies", league: .nl, division: .nlEast),
                .init(id: "WSH", name: "Washington Nationals", league: .nl, division: .nlEast)
            ]
        case .nlCentral:
            return [
                .init(id: "CHC", name: "Chicago Cubs", league: .nl, division: .nlCentral),
                .init(id: "CIN", name: "Cincinnati Reds", league: .nl, division: .nlCentral),
                .init(id: "MIL", name: "Milwaukee Brewers", league: .nl, division: .nlCentral),
                .init(id: "PIT", name: "Pittsburgh Pirates", league: .nl, division: .nlCentral),
                .init(id: "STL", name: "St. Louis Cardinals", league: .nl, division: .nlCentral)
            ]
        case .nlWest:
            return [
                .init(id: "ARI", name: "Arizona Diamondbacks", league: .nl, division: .nlWest),
                .init(id: "COL", name: "Colorado Rockies", league: .nl, division: .nlWest),
                .init(id: "LAD", name: "Los Angeles Dodgers", league: .nl, division: .nlWest),
                .init(id: "SD", name: "San Diego Padres", league: .nl, division: .nlWest),
                .init(id: "SF", name: "San Francisco Giants", league: .nl, division: .nlWest)
            ]
        }
    }

    static let allTeams: [MLBTeam] = allDivisions.flatMap { teams(in: $0) }

    static let teamsById: [String: MLBTeam] = Dictionary(uniqueKeysWithValues: allTeams.map { ($0.id, $0) })

    static func teamName(_ id: String) -> String {
        teamsById[id]?.name ?? id
    }

    static func teams(in league: MLBLeague) -> [MLBTeam] {
        allTeams.filter { $0.league == league }
    }
}

enum MLBLeague: String, Codable, CaseIterable, Identifiable {
    case al = "AL"
    case nl = "NL"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

enum MLBDivisionKey: String, Codable, CaseIterable, Identifiable {
    case alEast = "AL_EAST"
    case alCentral = "AL_CENTRAL"
    case alWest = "AL_WEST"
    case nlEast = "NL_EAST"
    case nlCentral = "NL_CENTRAL"
    case nlWest = "NL_WEST"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alEast: return "AL East"
        case .alCentral: return "AL Central"
        case .alWest: return "AL West"
        case .nlEast: return "NL East"
        case .nlCentral: return "NL Central"
        case .nlWest: return "NL West"
        }
    }

    var league: MLBLeague {
        switch self {
        case .alEast, .alCentral, .alWest: return .al
        case .nlEast, .nlCentral, .nlWest: return .nl
        }
    }
}

struct MLBTeam: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let league: MLBLeague
    let division: MLBDivisionKey
}

struct MLBFuturesMeta: Codable {
    let assetImage: String?
    let challengeId: String?
    let route: String?
    let sortOrder: Int?
    let startsAt: Timestamp?
    let state: String?
    let title: String
    let subtitle: String?
    let season: Int?
    let sport: String?
    let opensAt: Timestamp?
    let locksAt: Timestamp?
    let isLocked: Bool?
    let isVisible: Bool?
    let status: String?
}

struct MLBFuturesPicksDoc: Codable, Identifiable {
    @DocumentID var id: String?

    let challengeId: String
    let userId: String
    let displayName: String
    let submittedAt: Timestamp

    let alEast: [String]
    let alCentral: [String]
    let alWest: [String]
    let nlEast: [String]
    let nlCentral: [String]
    let nlWest: [String]

    let alSeeds: [String]
    let nlSeeds: [String]

    let aldsTeams: [String]
    let nldsTeams: [String]

    let alcsTeams: [String]
    let nlcsTeams: [String]

    let worldSeriesTeams: [String]
    let worldSeriesWinner: String

    func divisionArray(for division: MLBDivisionKey) -> [String] {
        switch division {
        case .alEast: return alEast
        case .alCentral: return alCentral
        case .alWest: return alWest
        case .nlEast: return nlEast
        case .nlCentral: return nlCentral
        case .nlWest: return nlWest
        }
    }

    func seeds(for league: MLBLeague) -> [String] {
        league == .al ? alSeeds : nlSeeds
    }

    func dsTeams(for league: MLBLeague) -> [String] {
        league == .al ? aldsTeams : nldsTeams
    }

    func csTeams(for league: MLBLeague) -> [String] {
        league == .al ? alcsTeams : nlcsTeams
    }

    func divisionWinners(for league: MLBLeague) -> [String] {
        MLBDivisionKey.allCases
            .filter { $0.league == league }
            .compactMap { divisionArray(for: $0).first }
    }
}

struct MLBFuturesAdminState: Codable {
    let challengeId: String
    let updatedAt: Timestamp
    let updatedBy: String?
    let isFinal: Bool

    let currentDivisionStandings: [String: [String]]
    let currentALSeeds: [String]
    let currentNLSeeds: [String]

    let currentALDSTeams: [String]
    let currentNLDSTeams: [String]

    let currentALCSTeams: [String]
    let currentNLCSTeams: [String]

    let currentWorldSeriesTeams: [String]
    let currentWorldSeriesWinner: String?

    func divisionArray(for division: MLBDivisionKey) -> [String] {
        currentDivisionStandings[division.rawValue] ?? []
    }

    func seeds(for league: MLBLeague) -> [String] {
        league == .al ? currentALSeeds : currentNLSeeds
    }

    func dsTeams(for league: MLBLeague) -> [String] {
        league == .al ? currentALDSTeams : currentNLDSTeams
    }

    func csTeams(for league: MLBLeague) -> [String] {
        league == .al ? currentALCSTeams : currentNLCSTeams
    }
}

struct MLBFuturesLeaderboardRow: Identifiable {
    let id: String
    let userId: String
    let displayName: String
    let totalPoints: Int
    let divisionPoints: Int
    let seedingPoints: Int
    let dsPoints: Int
    let csPoints: Int
    let wsPoints: Int
    let championPoints: Int
}

struct MLBFuturesTeamSummary: Identifiable {
    var id: String { teamId }

    let teamId: String
    let divisionLabel: String
    let averageDivisionFinish: Double
    let dsPickCount: Int
    let csPickCount: Int
    let worldSeriesPickCount: Int
    let championPickCount: Int
}

struct MLBFuturesSubmissionDraft {
    var alEast = MLBFuturesConstants.teams(in: .alEast).map(\ .id)
    var alCentral = MLBFuturesConstants.teams(in: .alCentral).map(\ .id)
    var alWest = MLBFuturesConstants.teams(in: .alWest).map(\ .id)
    var nlEast = MLBFuturesConstants.teams(in: .nlEast).map(\ .id)
    var nlCentral = MLBFuturesConstants.teams(in: .nlCentral).map(\ .id)
    var nlWest = MLBFuturesConstants.teams(in: .nlWest).map(\ .id)

    var alSeeds: [String] = []
    var nlSeeds: [String] = []
    var aldsTeams: [String] = []
    var nldsTeams: [String] = []
    var alcsTeams: [String] = []
    var nlcsTeams: [String] = []
    var worldSeriesTeams: [String] = []
    var worldSeriesWinner: String = ""

    mutating func seedDefaults() {
        let alWinners = [alEast.first, alCentral.first, alWest.first].compactMap { $0 }
        let nlWinners = [nlEast.first, nlCentral.first, nlWest.first].compactMap { $0 }

        let alWildCards = Array((alEast + alCentral + alWest).filter { !alWinners.contains($0) }.prefix(3))
        let nlWildCards = Array((nlEast + nlCentral + nlWest).filter { !nlWinners.contains($0) }.prefix(3))

        if alSeeds.count != 6 { alSeeds = alWinners + alWildCards }
        if nlSeeds.count != 6 { nlSeeds = nlWinners + nlWildCards }
        if aldsTeams.count != 4 { aldsTeams = Array(alSeeds.prefix(4)) }
        if nldsTeams.count != 4 { nldsTeams = Array(nlSeeds.prefix(4)) }
        if alcsTeams.count != 2 { alcsTeams = Array(aldsTeams.prefix(2)) }
        if nlcsTeams.count != 2 { nlcsTeams = Array(nldsTeams.prefix(2)) }
        if worldSeriesTeams.count != 2 {
            worldSeriesTeams = [alcsTeams.first, nlcsTeams.first].compactMap { $0 }
        }
        if worldSeriesWinner.isEmpty {
            worldSeriesWinner = worldSeriesTeams.first ?? ""
        }
    }

    func asPicksDoc(userId: String, displayName: String) -> MLBFuturesPicksDoc {
        .init(
            challengeId: MLBFuturesConstants.challengeId,
            userId: userId,
            displayName: displayName,
            submittedAt: Timestamp(date: Date()),
            alEast: alEast,
            alCentral: alCentral,
            alWest: alWest,
            nlEast: nlEast,
            nlCentral: nlCentral,
            nlWest: nlWest,
            alSeeds: alSeeds,
            nlSeeds: nlSeeds,
            aldsTeams: aldsTeams,
            nldsTeams: nldsTeams,
            alcsTeams: alcsTeams,
            nlcsTeams: nlcsTeams,
            worldSeriesTeams: worldSeriesTeams,
            worldSeriesWinner: worldSeriesWinner
        )
    }
}
