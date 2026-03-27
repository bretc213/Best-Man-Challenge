
//  BracketEngine.swift
//

import Foundation

enum BracketEngine {
    static func score(
        picks: [String: String],
        matchups: [BMCBracketMatchup],
        rules: BMCBracketScoringRules
    ) -> BMCBracketScoreBreakdown {
        var total = 0
        var correctByRound: [Int: Int] = [:]
        var pointsByRound: [Int: Int] = [:]

        for m in matchups {
            guard let winner = m.winnerTeamId else { continue }
            guard let picked = picks[m.id] else { continue }
            if picked == winner {
                let pts = rules.pointsPerCorrect(forRound: m.round)
                total += pts
                correctByRound[m.round, default: 0] += 1
                pointsByRound[m.round, default: 0] += pts
            }
        }

        return BMCBracketScoreBreakdown(
            totalPoints: total,
            correctByRound: correctByRound,
            pointsByRound: pointsByRound
        )
    }

    static func score(
        picks: [String: String],
        matchups: [BMCBracketMatchup],
        rules: BMCBracketScoringRules,
        simulatedWinners: [String: String]
    ) -> BMCBracketScoreBreakdown {
        var total = 0
        var correctByRound: [Int: Int] = [:]
        var pointsByRound: [Int: Int] = [:]

        for m in matchups {
            guard let winner = m.winnerTeamId ?? simulatedWinners[m.id] else { continue }
            guard let picked = picks[m.id] else { continue }
            if picked == winner {
                let pts = rules.pointsPerCorrect(forRound: m.round)
                total += pts
                correctByRound[m.round, default: 0] += 1
                pointsByRound[m.round, default: 0] += pts
            }
        }

        return BMCBracketScoreBreakdown(
            totalPoints: total,
            correctByRound: correctByRound,
            pointsByRound: pointsByRound
        )
    }

    static func maxPotentialScore(
        picks: [String: String],
        matchups: [BMCBracketMatchup],
        rules: BMCBracketScoringRules
    ) -> Int {
        let matchupsById = Dictionary(uniqueKeysWithValues: matchups.map { ($0.id, $0) })
        let feedersById = buildFeeders(matchups: matchups)
        var memo: [String: Set<String>] = [:]

        func possibleWinners(for matchupId: String) -> Set<String> {
            if let cached = memo[matchupId] {
                return cached
            }
            guard let matchup = matchupsById[matchupId] else {
                return []
            }

            if let winner = matchup.winnerTeamId {
                let resolved: Set<String> = [winner]
                memo[matchupId] = resolved
                return resolved
            }

            var candidates = Set<String>()
            let feeders = feedersById[matchupId]

            if let homeFeederId = feeders?.home {
                candidates.formUnion(possibleWinners(for: homeFeederId))
            } else if let homeTeamId = matchup.homeTeamId {
                candidates.insert(homeTeamId)
            }

            if let awayFeederId = feeders?.away {
                candidates.formUnion(possibleWinners(for: awayFeederId))
            } else if let awayTeamId = matchup.awayTeamId {
                candidates.insert(awayTeamId)
            }

            memo[matchupId] = candidates
            return candidates
        }

        var total = 0

        for matchup in matchups {
            guard let pickedTeamId = picks[matchup.id] else { continue }
            let pts = rules.pointsPerCorrect(forRound: matchup.round)

            if let winner = matchup.winnerTeamId {
                if pickedTeamId == winner {
                    total += pts
                }
            } else if possibleWinners(for: matchup.id).contains(pickedTeamId) {
                total += pts
            }
        }

        return total
    }

    struct Feeders {
        var home: String? = nil
        var away: String? = nil
    }

    static func buildFeeders(matchups: [BMCBracketMatchup]) -> [String: Feeders] {
        var feeders: [String: Feeders] = [:]

        for m in matchups {
            guard let nextId = m.nextMatchupId,
                  let nextSlot = m.nextSlot else { continue }

            var f = feeders[nextId] ?? Feeders()
            if nextSlot == "home" { f.home = m.id }
            else if nextSlot == "away" { f.away = m.id }
            feeders[nextId] = f
        }

        return feeders
    }

    struct SlotResult {
        let teamId: String?
        let tint: BMCBracketMatchupCard.Tint
    }

    static func slotDisplay(
        matchup: BMCBracketMatchup,
        slot: String,
        picks: [String: String],
        matchupsById: [String: BMCBracketMatchup],
        feedersById: [String: Feeders]
    ) -> SlotResult {
        let feeders = feedersById[matchup.id]
        let feederId: String? = (slot == "home") ? feeders?.home : feeders?.away

        if let feederId,
           let feeder = matchupsById[feederId] {

            let userPicked = picks[feederId]
            let winner = feeder.winnerTeamId

            if let winner {
                if userPicked == winner {
                    return SlotResult(teamId: winner, tint: .green)
                } else {
                    return SlotResult(teamId: winner, tint: .red)
                }
            }

            if let userPicked {
                return SlotResult(teamId: userPicked, tint: .none)
            }

            return SlotResult(teamId: nil, tint: .none)
        }

        if slot == "home" {
            return SlotResult(teamId: matchup.homeTeamId, tint: .none)
        } else {
            return SlotResult(teamId: matchup.awayTeamId, tint: .none)
        }
    }
}
