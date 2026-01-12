//
//  NFLAllPicksView.swift
//  Best Man Challenge
//

import SwiftUI

struct NFLAllPicksView: View {
    @ObservedObject var store: NFLPlayoffsPicksStore
    let session: SessionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("All Picks")
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
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(store.matchups) { matchup in
                            AllPicksMatchupCard(
                                matchup: matchup,
                                myPickTeamId: store.myPicks[matchup.id],
                                allPlayers: store.allPlayersPicks
                            )
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }
            }
        }
        .padding(.top, 8)
        .padding(.horizontal)
        
    }
}

private struct AllPicksMatchupCard: View {
    let matchup: BracketMatchup
    let myPickTeamId: String?
    let allPlayers: [RoundPicksDoc]

    private var isLocked: Bool { Date() >= matchup.lockAt }
    private var winnerId: String? { matchup.winnerTeamId }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text(matchupTimeString(matchup.startsAt))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if isLocked {
                    Text("LOCKED")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.20))
                        .foregroundStyle(Color.red)
                        .clipShape(Capsule())
                } else {
                    Text("Reveals at kickoff")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                teamBadge(team: matchup.away, isWinner: winnerId == matchup.away.id)
                Text("@").foregroundStyle(.secondary)
                teamBadge(team: matchup.home, isWinner: winnerId == matchup.home.id)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Your pick")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(myPickLabel())
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.top, 4)

            Divider().opacity(0.25)

            if !isLocked {
                Text("Everyone’s picks are hidden until kickoff.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("All picks")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(allPlayers) { doc in
                        let pickTeamId = doc.picks[matchup.id] ?? ""

                        HStack {
                            Text(doc.displayName)
                                .font(.subheadline)

                            Spacer()

                            Text(pickLabel(teamId: pickTeamId))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(pickColor(teamId: pickTeamId))
                        }
                        .opacity(pickTeamId.isEmpty ? 0.65 : 1.0)
                    }
                }
            }
        }
        .cardStyle()
    }

    private func teamBadge(team: MatchupTeam, isWinner: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(isWinner ? 0.55 : 0.18), lineWidth: isWinner ? 2 : 1)
                    )

                if let asset = team.logoAsset, !asset.isEmpty {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .padding(14)
                } else {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.accent)
                }

                if isWinner {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "crown.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.yellow)
                                .padding(10)
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: 120, height: 92)

            Text(team.name)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func matchupTimeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func myPickLabel() -> String {
        guard let my = myPickTeamId, !my.isEmpty else { return "No pick yet" }
        return pickLabel(teamId: my)
    }

    private func pickLabel(teamId: String) -> String {
        if teamId.isEmpty { return "—" }
        if teamId == matchup.away.id { return matchup.away.name }
        if teamId == matchup.home.id { return matchup.home.name }
        return teamId
    }

    private func pickColor(teamId: String) -> Color {
        guard let winnerId else { return .primary }
        guard !teamId.isEmpty else { return .secondary }
        return (teamId == winnerId) ? Color.green : Color.red
    }
}
