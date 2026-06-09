import SwiftUI

struct BackyardDoublesScoreInputView: View {
    let gameId: BackyardGameId

    @EnvironmentObject private var store: BackyardChallengeStore
    @EnvironmentObject private var session: SessionStore

    @State private var selectedTab: DoublesTab = .input

    enum DoublesTab: String, CaseIterable, Identifiable {
        case input = "Placement"
        case leaderboard = "Leaderboard"

        var id: String { rawValue }
    }

    var body: some View {
        ThemedScreen {
            VStack(spacing: 12) {
                Picker("View", selection: $selectedTab) {
                    ForEach(DoublesTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch selectedTab {
                case .input:
                    inputView
                case .leaderboard:
                    leaderboardView
                }
            }
            .navigationTitle(gameId.title)
        }
    }

    // MARK: - Teams

    private var baseRowsForTeams: [BackyardStandingRow] {
        switch gameId {
        case .cornholeDoubles:
            return store.cornholeOverallRows()
        case .ladderBallDoubles:
            return store.finalScoreLeaderboard(gameId: .ladderBallIndividual, multiplier: 2)
        case .qb54Doubles:
            return store.finalScoreLeaderboard(gameId: .qb54Individual, multiplier: 2)
        default:
            return store.golf18Leaderboard()
        }
    }

    private var teams: [BackyardTeam] {
        store.doublesTeamsFromStandings(rows: baseRowsForTeams)
    }

    // MARK: - Current placement for a team (1-6, or nil if unset)

    private func currentPlace(for team: BackyardTeam) -> Int? {
        let scores = store.finalScoresByGame[gameId] ?? [:]
        for player in team.players {
            if let score = scores[player.id], score > 0 {
                return Int(score)
            }
        }
        return nil
    }

    // MARK: - Placement Input

    private var inputView: some View {
        List {
            Section("Place each team (1st – 6th)") {
                ForEach(teams) { team in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(team.name)
                                .font(.headline)
                            Text(team.players.map(\.displayName).joined(separator: " + "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if session.isAdmin {
                            placementMenu(for: team)
                        } else {
                            Text(placeLabel(for: team))
                                .font(.headline)
                                .foregroundStyle(currentPlace(for: team) != nil ? Color.primary : Color.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.plain)
    }

    private func placementMenu(for team: BackyardTeam) -> some View {
        let place = currentPlace(for: team)
        let label = place.map { ordinal($0) } ?? "—"

        return Menu {
            Button("—") { savePlacement(team: team, place: 0) }
            ForEach(1...6, id: \.self) { p in
                Button(ordinal(p)) { savePlacement(team: team, place: p) }
            }
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.headline)
                    .foregroundStyle(place != nil ? Color.primary : Color.secondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func placeLabel(for team: BackyardTeam) -> String {
        guard let place = currentPlace(for: team) else { return "—" }
        return ordinal(place)
    }

    private func savePlacement(team: BackyardTeam, place: Int) {
        Task {
            for player in team.players {
                await store.saveFinalScore(
                    gameId: gameId,
                    playerId: player.id,
                    score: Double(place)
                )
            }
        }
    }

    // MARK: - Leaderboard

    private var leaderboardView: some View {
        List {
            Section("Team Standings") {
                ForEach(Array(sortedTeams.enumerated()), id: \.element.team.id) { index, item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(index + 1). \(item.team.name)")
                                .font(.headline)
                            Spacer()
                            Text("\(BackyardScoring.doublesPoints(rankIndex: index)) BY pts each")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(item.team.players.map(\.displayName).joined(separator: " + "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let place = item.place {
                            Text("Placed: \(ordinal(place))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .listStyle(.plain)
    }

    private var sortedTeams: [(team: BackyardTeam, place: Int?)] {
        var items: [(team: BackyardTeam, place: Int?)] = teams.map { ($0, currentPlace(for: $0)) }
        items.sort { a, b in
            switch (a.place, b.place) {
            case (.none, .none): return a.team.name < b.team.name
            case (.none, .some): return false
            case (.some, .none): return true
            case (.some(let pa), .some(let pb)): return pa < pb
            }
        }
        return items
    }

    // MARK: - Helpers

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        case 4: return "4th"
        case 5: return "5th"
        case 6: return "6th"
        default: return "—"
        }
    }
}
