import Foundation

enum BracketEngine {
    // MARK: - Scoring

    /// Computes total points for a single bracket based on finalized results.
    /// - Parameters:
    ///   - picks: matchupId -> teamId the player selected
    ///   - matchups: all matchups (with winnerTeamId when finalized)
    ///   - rules: scoring rules (points per correct pick by round)
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

    // MARK: - Bracket graph (single elimination)

    struct Feeders {
        var home: String? = nil
        var away: String? = nil
    }

    /// Builds a map of `matchupId -> (homeFeederMatchupId, awayFeederMatchupId)` using the `nextMatchupId/nextSlot` wiring.
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

    /// Resolves which team should be displayed in a slot for a given matchup.
    /// Priority:
    /// 1) If slot is fed by a previous matchup:
    ///    - if feeder winner exists -> show winner (green if user picked correctly, else red)
    ///    - else if user picked feeder -> show their projection
    ///    - else -> TBD
    /// 2) Otherwise use round-1 home/away team ids.
    static func slotDisplay(
        matchup: BMCBracketMatchup,
        slot: String, // "home" or "away"
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

        // Round 1 fallback
        if slot == "home" {
            return SlotResult(teamId: matchup.homeTeamId, tint: .none)
        } else {
            return SlotResult(teamId: matchup.awayTeamId, tint: .none)
        }
    }
}
