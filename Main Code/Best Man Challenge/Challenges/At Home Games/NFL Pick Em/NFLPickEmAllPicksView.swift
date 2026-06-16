//
//  NFLPickEmAllPicksView.swift
//  Best Man Challenge
//
//  Shows every player's picks for the selected week.
//  Defaults to the current active week.
//

import SwiftUI

struct NFLPickEmAllPicksView: View {
    @ObservedObject var store: NFLPickEmStore
    let session: SessionStore

    @State private var selectedWeek: Int = 1

    private var weekGames: [NFLPickEmGame] {
        store.games(for: selectedWeek)
    }

    private var sortedPlayers: [NFLPickEmEntry] {
        store.allEntries.sorted { $0.displayName < $1.displayName }
    }

    private var availableWeeks: [Int] {
        store.availableWeeks.isEmpty ? Array(1...16) : store.availableWeeks
    }

    private var myLinkedId: String {
        session.profile?.linkedPlayerId ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            weekSelectorBar

            if store.isLoading {
                Spacer()
                ProgressView("Loading picks…")
                Spacer()
            } else if weekGames.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Games Yet",
                    systemImage: "football",
                    description: Text("Week \(selectedWeek) games haven't been posted yet.")
                )
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        weekHeader

                        ForEach(weekGames) { game in
                            GameAllPicksCard(
                                game: game,
                                players: sortedPlayers,
                                myLinkedId: myLinkedId
                            )
                        }

                        weekScoreSummary
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }
        }
        .onAppear { selectedWeek = store.currentWeek }
    }

    // MARK: - Week Selector

    private var weekSelectorBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(availableWeeks, id: \.self) { week in
                        Button {
                            withAnimation { selectedWeek = week }
                        } label: {
                            Text("Wk \(week)")
                                .font(.caption.weight(selectedWeek == week ? .bold : .regular))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    selectedWeek == week
                                    ? Color.accentColor
                                    : Color(UIColor.secondarySystemBackground)
                                )
                                .foregroundStyle(selectedWeek == week ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .id(week)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(UIColor.systemBackground))
            .onChange(of: selectedWeek) { _, week in
                withAnimation { proxy.scrollTo(week, anchor: .center) }
            }
            .onAppear { proxy.scrollTo(selectedWeek, anchor: .center) }
        }
    }

    // MARK: - Header

    private var weekHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Week \(selectedWeek) — All Picks")
                    .font(.title3.bold())
                Text("\(weekGames.count) games · \(sortedPlayers.count) players")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Week Score Summary

    private var weekScoreSummary: some View {
        let finalGames = weekGames.filter { $0.isFinal }
        guard !finalGames.isEmpty else { return AnyView(EmptyView()) }

        let rows: [(name: String, correct: Int, isMe: Bool)] = sortedPlayers.map { player in
            let correct = finalGames.filter { game in
                guard let winner = game.winnerId else { return false }
                return player.picks[game.id] == winner
            }.count
            return (player.displayName, correct, player.linkedPlayerId == myLinkedId)
        }.sorted {
            if $0.correct != $1.correct { return $0.correct > $1.correct }
            return $0.name < $1.name
        }

        let maxCorrect = rows.map { $0.correct }.max() ?? 0

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("Week \(selectedWeek) Results")
                    .font(.headline)

                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    HStack {
                        Text("\(idx + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .leading)

                        Text(row.name)
                            .fontWeight(row.isMe ? .bold : .regular)

                        if row.correct == maxCorrect && row.correct > 0 {
                            Image(systemName: "trophy.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }

                        Spacer()

                        Text("\(row.correct)/\(finalGames.count)")
                            .font(.subheadline.monospacedDigit())
                            .fontWeight(row.isMe ? .bold : .regular)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        )
    }
}

// MARK: - Game All Picks Card

struct GameAllPicksCard: View {
    let game: NFLPickEmGame
    let players: [NFLPickEmEntry]
    let myLinkedId: String

    private var isLocked: Bool { game.isLocked }
    private var winnerId: String? { game.winnerId }

    /// Only show other players' picks once the game has locked.
    /// Before kickoff, you can only see your own pick.
    private var visiblePlayers: [NFLPickEmEntry] {
        guard isLocked else {
            return players.filter { $0.linkedPlayerId == myLinkedId }
        }
        return players
    }

    private var awayPickers: [NFLPickEmEntry] {
        visiblePlayers.filter { $0.picks[game.id] == game.awayTeam.id }
    }

    private var homePickers: [NFLPickEmEntry] {
        visiblePlayers.filter { $0.picks[game.id] == game.homeTeam.id }
    }

    private var noPickers: [NFLPickEmEntry] {
        // Only show "no pick" players after lock (and only other players, not self)
        guard isLocked else { return [] }
        return players.filter { $0.picks[game.id] == nil }
    }

    var body: some View {
        VStack(spacing: 10) {
            // Title row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(game.awayTeam.nickname) @ \(game.homeTeam.nickname)")
                        .font(.subheadline.weight(.semibold))
                    Text(kickoffString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let winner = winnerId {
                    let name = winner == game.awayTeam.id ? game.awayTeam.nickname : game.homeTeam.nickname
                    Label(name + " Win", systemImage: "checkmark.seal.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                } else if isLocked {
                    Text("IN PROGRESS")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                } else {
                    Label("Picks hidden until kickoff", systemImage: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Two-column picks (away | home)
            HStack(alignment: .top, spacing: 12) {
                pickerColumn(
                    team: game.awayTeam,
                    pickers: awayPickers,
                    isWinner: winnerId == game.awayTeam.id
                )

                Divider()

                pickerColumn(
                    team: game.homeTeam,
                    pickers: homePickers,
                    isWinner: winnerId == game.homeTeam.id
                )
            }

            // No pick players
            if !noPickers.isEmpty && isLocked {
                HStack {
                    Text("No pick: \(noPickers.map { $0.displayName }.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.7))
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func pickerColumn(team: NFLPickEmTeam, pickers: [NFLPickEmEntry], isWinner: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if UIImage(named: team.logoAsset) != nil {
                    Image(team.logoAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                }
                Text(team.nickname)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                if isWinner {
                    Image(systemName: "trophy.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }

                Spacer()

                Text("\(pickers.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ForEach(pickers, id: \.id) { player in
                let isMe = player.linkedPlayerId == myLinkedId
                let isCorrect = winnerId == team.id
                let isWrong = winnerId != nil && winnerId != team.id

                HStack(spacing: 4) {
                    Circle()
                        .fill(isCorrect ? Color.green.opacity(0.8) : isWrong ? Color.red.opacity(0.7) : Color.secondary.opacity(0.4))
                        .frame(width: 6, height: 6)

                    Text(player.displayName)
                        .font(.caption)
                        .fontWeight(isMe ? .bold : .regular)
                        .foregroundStyle(isMe ? .primary : .secondary)
                        .lineLimit(1)
                }
            }

            if pickers.isEmpty {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var kickoffString: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d · h:mm a"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f.string(from: game.kickoffTime) + " ET"
    }
}
