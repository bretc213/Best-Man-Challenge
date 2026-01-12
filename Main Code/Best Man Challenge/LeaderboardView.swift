//
//  LeaderboardView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 7/31/25.
//

import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var store = LeaderboardStore()

    // MARK: - Toggle

    private enum BoardMode: String, CaseIterable, Identifiable {
        case bestMan = "Best Man"
        case groomsmen = "Groomsmen"
        var id: String { rawValue }
    }

    @State private var mode: BoardMode = .bestMan

    // MARK: - Constants

    private let excludedGroomsmenIds: Set<String> = ["anthonyc", "dannyo", "jakeo"]
    private let wildcardCutoffRank: Int = 5
    private let excludedOverallLeaderboardIds: Set<String> = ["bretc"] // ✅ Owner excluded from overall leaderboard

    // MARK: - Ranked Players

    private var rankedPlayers: [(player: LeaderboardPlayer, rank: Int, pointsBack: String?)] {
        // Build base list by mode
        let basePlayersByMode: [LeaderboardPlayer] = {
            switch mode {
            case .bestMan:
                return store.players
            case .groomsmen:
                return store.players.filter { !excludedGroomsmenIds.contains($0.id) }
            }
        }()

        // ✅ Always remove Bret from the overall leaderboard (both modes)
        let basePlayers = basePlayersByMode.filter { !excludedOverallLeaderboardIds.contains($0.id) }

        // Sort by points desc; tie-break by name
        let sorted = basePlayers.sorted {
            if $0.totalPoints != $1.totalPoints { return $0.totalPoints > $1.totalPoints }
            return $0.name < $1.name
        }

        guard !sorted.isEmpty else { return [] }

        switch mode {
        case .bestMan:
            // Back relative to 1st place
            let topScore = sorted.first?.totalPoints ?? 0
            return sorted.enumerated().map { index, player in
                (
                    player: player,
                    rank: index + 1,
                    pointsBack: index == 0 ? nil : "\(topScore - player.totalPoints)"
                )
            }

        case .groomsmen:
            // Wildcard back relative to 5th place
            let cutoffIndex = wildcardCutoffRank - 1
            guard sorted.count > cutoffIndex else {
                return sorted.enumerated().map { index, player in
                    (player: player, rank: index + 1, pointsBack: nil)
                }
            }

            let cutoffScore = sorted[cutoffIndex].totalPoints

            return sorted.enumerated().map { index, player in
                let delta = player.totalPoints - cutoffScore
                let backText: String?

                if index == cutoffIndex {
                    backText = nil
                } else if delta > 0 {
                    backText = "+\(delta)"
                } else {
                    backText = "\(abs(delta))"
                }

                return (player: player, rank: index + 1, pointsBack: backText)
            }
        }
    }

    var body: some View {
        ThemedScreen {
            NavigationView {
                List {
                    if let msg = store.errorMessage {
                        Text("Couldn’t load leaderboard: \(msg)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    }

                    // Mode toggle
                    Section {
                        Picker("Leaderboard Mode", selection: $mode) {
                            ForEach(BoardMode.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                    }

                    Section(header: leaderboardHeader()) {
                        ForEach(rankedPlayers, id: \.player.id) { entry in
                            let isMe = isLoggedInPlayer(entry.player)

                            leaderboardRow(
                                rank: entry.rank,
                                name: entry.player.name,
                                points: entry.player.totalPoints,
                                pointsBackText: entry.pointsBack,
                                isMe: isMe
                            )
                            .listRowBackground(Color.clear)

                            // 🔴 Red cutoff line under 5th place (Groomsmen only)
                            if mode == .groomsmen && entry.rank == wildcardCutoffRank {
                                Divider()
                                    .frame(height: 2)
                                    .background(Color.red)
                                    .listRowBackground(Color.clear)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .background(Color.background)
                .navigationTitle(mode == .bestMan ? "Leaderboard" : "Groomsmen Race")
            }
        }
        .onAppear { store.startListening() }
    }

    // MARK: - Helpers

    private func isLoggedInPlayer(_ player: LeaderboardPlayer) -> Bool {
        guard let linked = session.profile?.linkedPlayerId else { return false }
        return player.id == linked
    }

    // MARK: - Header

    @ViewBuilder
    func leaderboardHeader() -> some View {
        HStack {
            Text("#").frame(width: 30, alignment: .leading)
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Pts.").frame(width: 50, alignment: .trailing)
            Text(mode == .groomsmen ? "WC Back" : "Back")
                .frame(width: 70, alignment: .trailing)
        }
        .font(.caption.bold())
        .secondaryText()
    }

    // MARK: - Row

    @ViewBuilder
    func leaderboardRow(
        rank: Int,
        name: String,
        points: Int,
        pointsBackText: String?,
        isMe: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .frame(width: 30, alignment: .leading)

            HStack(spacing: 8) {
                Text(name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fontWeight(isMe ? .bold : .regular)

                if isMe {
                    Text("You")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accent.opacity(0.20))
                        .foregroundStyle(Color.accent)
                        .clipShape(Capsule())
                }
            }

            Text("\(points)")
                .frame(width: 50, alignment: .trailing)
                .fontWeight(isMe ? .bold : .regular)

            Text(pointsBackText ?? "—")
                .frame(width: 70, alignment: .trailing)
        }
        .cardStyle()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isMe ? Color.accent.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isMe ? Color.accent.opacity(0.65) : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    LeaderboardView()
        .environmentObject(SessionStore())
}
