//
//  NFLPlayerPicksDetailView.swift
//  Best Man Challenge
//
//  Shows a single player's picks for the selected round.
//

import SwiftUI

struct NFLPlayerPicksDetailView: View {
    @ObservedObject var store: NFLPlayoffsPicksStore

    /// The player whose picks we’re viewing
    let player: RoundPicksDoc

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text(player.displayName)
                .font(.title2.bold())

            if store.isLoading {
                ProgressView("Loading...")
                    .padding(.top, 8)

            } else if let err = store.errorMessage {
                Text("Couldn’t load: \(err)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

            } else if store.matchups.isEmpty {
                Text("No games found for this round.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

            } else {
                List {
                    ForEach(store.matchups) { matchup in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(matchup.away.name) @ \(matchup.home.name)")
                                    .font(.subheadline.weight(.semibold))

                                Text(matchupTimeString(matchup.startsAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(pickLabel(for: matchup))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(pickColor(for: matchup))
                                .multilineTextAlignment(.trailing)
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding(.top, 8)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func pickLabel(for matchup: BracketMatchup) -> String {
        let pick = player.picks[matchup.id] ?? ""
        if pick.isEmpty { return "—" }

        // Your pick values are team IDs like "LAR", "CAR"
        if pick == matchup.away.id { return matchup.away.name }
        if pick == matchup.home.id { return matchup.home.name }
        return pick
    }

    private func pickColor(for matchup: BracketMatchup) -> Color {
        guard let winner = matchup.winnerTeamId, !winner.isEmpty else { return .primary }

        let pick = player.picks[matchup.id] ?? ""
        guard !pick.isEmpty else { return .secondary }

        return (pick == winner) ? Color.green : Color.red
    }

    private func matchupTimeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
