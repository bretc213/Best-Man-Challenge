import Foundation

enum MLBFuturesScoring {
    static func validate(picks: MLBFuturesPicksDoc) -> [String] {
        var errors: [String] = []

        for division in MLBDivisionKey.allCases {
            let picked = picks.divisionArray(for: division)
            let validIds = Set(MLBFuturesConstants.teams(in: division).map(\ .id))
            if picked.count != 5 { errors.append("\(division.displayName): must rank exactly 5 teams.") }
            if Set(picked).count != 5 { errors.append("\(division.displayName): duplicate teams found.") }
            if Set(picked) != validIds { errors.append("\(division.displayName): must contain the correct 5 division teams.") }
        }

        for league in MLBLeague.allCases {
            let seeds = picks.seeds(for: league)
            let winners = Set(picks.divisionWinners(for: league))
            let topThree = Array(seeds.prefix(3))
            let bottomThree = Array(seeds.suffix(max(0, seeds.count - 3)))
            let leagueIds = Set(MLBFuturesConstants.teams(in: league).map(\ .id))

            if seeds.count != 6 { errors.append("\(league.displayName) seeds: must contain exactly 6 teams.") }
            if Set(seeds).count != 6 { errors.append("\(league.displayName) seeds: duplicate teams found.") }
            if !Set(seeds).isSubset(of: leagueIds) { errors.append("\(league.displayName) seeds: contains invalid league team.") }
            if Set(topThree) != winners { errors.append("\(league.displayName) seeds 1-3 must be your division winners.") }
            if Set(topThree).intersection(bottomThree).isEmpty == false { errors.append("\(league.displayName) seeds: team cannot appear twice.") }

            let ds = picks.dsTeams(for: league)
            let cs = picks.csTeams(for: league)

            if ds.count != 4 { errors.append("\(league.displayName) DS picks must contain exactly 4 teams.") }
            if Set(ds).count != ds.count { errors.append("\(league.displayName) DS picks contain duplicates.") }
            if !Set(ds).isSubset(of: Set(seeds)) { errors.append("\(league.displayName) DS picks must come from your 6 seeded teams.") }

            if cs.count != 2 { errors.append("\(league.displayName) CS picks must contain exactly 2 teams.") }
            if Set(cs).count != cs.count { errors.append("\(league.displayName) CS picks contain duplicates.") }
            if !Set(cs).isSubset(of: Set(ds)) { errors.append("\(league.displayName) CS picks must come from your DS picks.") }
        }

        if picks.worldSeriesTeams.count != 2 { errors.append("World Series picks must contain exactly 2 teams.") }
        if Set(picks.worldSeriesTeams).count != 2 { errors.append("World Series picks contain duplicates.") }
        if let alTeam = picks.worldSeriesTeams.first {
            if !(picks.alcsTeams.contains(alTeam) || picks.nlcsTeams.contains(alTeam)) {
                errors.append("World Series picks must come from your CS picks.")
            }
        }
        if !picks.worldSeriesTeams.contains(picks.worldSeriesWinner) {
            errors.append("World Series winner must be one of your World Series teams.")
        }

        let leagues = picks.worldSeriesTeams.compactMap { MLBFuturesConstants.teamsById[$0]?.league }
        if leagues.count == 2, Set(leagues).count != 2 {
            errors.append("World Series picks must contain one AL team and one NL team.")
        }

        return errors
    }

    static func score(picks: MLBFuturesPicksDoc, against state: MLBFuturesAdminState) -> MLBFuturesLeaderboardRow {
        let divisionPoints = scoreDivisions(picks: picks, state: state)
        let seedingPoints = scoreSeeds(picks: picks, state: state)
        let dsPoints = scoreRound(pickedAL: picks.aldsTeams, actualAL: state.currentALDSTeams, pickedNL: picks.nldsTeams, actualNL: state.currentNLDSTeams, pointsPerHit: 5)
        let csPoints = scoreRound(pickedAL: picks.alcsTeams, actualAL: state.currentALCSTeams, pickedNL: picks.nlcsTeams, actualNL: state.currentNLCSTeams, pointsPerHit: 10)
        let wsPoints = scoreWorldSeriesTeams(picks.worldSeriesTeams, actual: state.currentWorldSeriesTeams)
        let championPoints = scoreChampion(picks.worldSeriesWinner, actual: state.currentWorldSeriesWinner)
        let total = divisionPoints + seedingPoints + dsPoints + csPoints + wsPoints + championPoints

        return .init(
            id: picks.userId,
            userId: picks.userId,
            displayName: picks.displayName,
            totalPoints: total,
            divisionPoints: divisionPoints,
            seedingPoints: seedingPoints,
            dsPoints: dsPoints,
            csPoints: csPoints,
            wsPoints: wsPoints,
            championPoints: championPoints
        )
    }

    static func buildLeaderboard(picks: [MLBFuturesPicksDoc], state: MLBFuturesAdminState) -> [MLBFuturesLeaderboardRow] {
        picks.map { score(picks: $0, against: state) }
            .sorted {
                if $0.totalPoints == $1.totalPoints {
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                return $0.totalPoints > $1.totalPoints
            }
    }

    static func buildSummary(from picks: [MLBFuturesPicksDoc]) -> [MLBFuturesTeamSummary] {
        let allTeams = MLBFuturesConstants.allTeams
        var divisionTotals: [String: Int] = [:]
        var divisionCounts: [String: Int] = [:]
        var dsCounts: [String: Int] = [:]
        var csCounts: [String: Int] = [:]
        var wsCounts: [String: Int] = [:]
        var champCounts: [String: Int] = [:]

        for pick in picks {
            let divisionGroups: [[String]] = [
                pick.alEast,
                pick.alCentral,
                pick.alWest,
                pick.nlEast,
                pick.nlCentral,
                pick.nlWest
            ]

            for group in divisionGroups {
                for (index, teamId) in group.enumerated() {
                    divisionTotals[teamId, default: 0] += (index + 1)
                    divisionCounts[teamId, default: 0] += 1
                }
            }

            for teamId in pick.aldsTeams + pick.nldsTeams {
                dsCounts[teamId, default: 0] += 1
            }

            for teamId in pick.alcsTeams + pick.nlcsTeams {
                csCounts[teamId, default: 0] += 1
            }

            for teamId in pick.worldSeriesTeams {
                wsCounts[teamId, default: 0] += 1
            }

            champCounts[pick.worldSeriesWinner, default: 0] += 1
        }

        return allTeams.map { team in
            let totalFinish = divisionTotals[team.id, default: 0]
            let finishCount = divisionCounts[team.id, default: 0]
            let avgFinish = finishCount > 0 ? Double(totalFinish) / Double(finishCount) : 0

            return MLBFuturesTeamSummary(
                teamId: team.id,
                divisionLabel: team.division.displayName,
                averageDivisionFinish: avgFinish,
                dsPickCount: dsCounts[team.id, default: 0],
                csPickCount: csCounts[team.id, default: 0],
                worldSeriesPickCount: wsCounts[team.id, default: 0],
                championPickCount: champCounts[team.id, default: 0]
            )
        }
    }

    private static func scoreDivisions(picks: MLBFuturesPicksDoc, state: MLBFuturesAdminState) -> Int {
        var total = 0
        for division in MLBDivisionKey.allCases {
            let picked = picks.divisionArray(for: division)
            let actual = state.divisionArray(for: division)
            for team in picked {
                guard let predictedIndex = picked.firstIndex(of: team), let actualIndex = actual.firstIndex(of: team) else { continue }
                let distance = abs(predictedIndex - actualIndex)
                switch distance {
                case 0: total += 3
                case 1: total += 1
                case 2: total += 0
                case 3: total -= 1
                case 4: total -= 3
                default: break
                }
            }
        }
        return total
    }

    private static func scoreSeeds(picks: MLBFuturesPicksDoc, state: MLBFuturesAdminState) -> Int {
        var total = 0
        for league in MLBLeague.allCases {
            let picked = picks.seeds(for: league)
            let actual = state.seeds(for: league)
            let actualSet = Set(actual)
            for (index, team) in picked.enumerated() {
                if actual.indices.contains(index), actual[index] == team {
                    total += 5
                } else if actualSet.contains(team) {
                    total += 3
                }
            }
        }
        return total
    }

    private static func scoreRound(pickedAL: [String], actualAL: [String], pickedNL: [String], actualNL: [String], pointsPerHit: Int) -> Int {
        let alHits = Set(pickedAL).intersection(actualAL).count
        let nlHits = Set(pickedNL).intersection(actualNL).count
        return (alHits + nlHits) * pointsPerHit
    }

    private static func scoreWorldSeriesTeams(_ picked: [String], actual: [String]) -> Int {
        Set(picked).intersection(actual).count * 15
    }

    private static func scoreChampion(_ picked: String, actual: String?) -> Int {
        picked == actual ? MLBFuturesConstants.worldSeriesWinnerPoints : 0
    }
}
