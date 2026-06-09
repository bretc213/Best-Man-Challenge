import SwiftUI

struct BackyardRelayRaceView: View {
    @EnvironmentObject private var store: BackyardChallengeStore
    @EnvironmentObject private var session: SessionStore

    @State private var selectedTab: RelayTab = .teams
    @State private var totalInputs: [String: String] = [:]
    @State private var splitInputs: [String: [String: String]] = [:]

    enum RelayTab: String, CaseIterable, Identifiable {
        case teams = "Teams"
        case timing = "Timing"
        case leaderboard = "Leaderboard"

        var id: String { rawValue }
    }

    private var visibleTabs: [RelayTab] {
        session.isAdmin ? RelayTab.allCases : [.teams, .leaderboard]
    }

    var body: some View {
        ThemedScreen {
            VStack(spacing: 12) {
                Picker("View", selection: $selectedTab) {
                    ForEach(visibleTabs) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch selectedTab {
                case .teams:
                    teamsView

                case .timing:
                    timingView

                case .leaderboard:
                    leaderboardView
                }
            }
            .navigationTitle("Relay Race")
            .onAppear {
                // If non-admin somehow lands on timing tab, redirect
                if !session.isAdmin && selectedTab == .timing {
                    selectedTab = .teams
                }
                loadInputs()
            }
        }
    }

    private var teams: [BackyardTeam] {
        store.teamsFromCurrentOverallStandings()
    }

    private var teamsView: some View {
        List {
            Section("Team Logic") {
                Text("Teams are created from standings entering the final event.")
                Text("Team 1: 1, 6, 7, 12")
                Text("Team 2: 2, 5, 8, 11")
                Text("Team 3: 3, 4, 9, 10")
                Text("Players MUST rotate. One player must complete each event.")
            }

            Section("Teams") {
                ForEach(teams) { team in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(team.name)
                            .font(.headline)

                        Text(team.players.map(\.displayName).joined(separator: " • "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.plain)
    }

    private var timingView: some View {
        List {
            ForEach(teams) { team in
                Section(team.name) {
                    HStack {
                        Text("Total Time")

                        Spacer()

                        TextField(
                            "Seconds",
                            text: Binding(
                                get: {
                                    totalInputs[team.id] ?? ""
                                },
                                set: {
                                    totalInputs[team.id] = $0
                                }
                            )
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)

                        Button("Save") {
                            saveTotal(teamId: team.id)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    ForEach(team.players) { player in
                        HStack {
                            Text(player.displayName)

                            Spacer()

                            TextField(
                                "Split",
                                text: Binding(
                                    get: {
                                        splitInputs[team.id]?[player.id] ?? ""
                                    },
                                    set: {
                                        splitInputs[team.id, default: [:]][player.id] = $0
                                    }
                                )
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)

                            Button("Save") {
                                saveSplit(
                                    teamId: team.id,
                                    playerId: player.id
                                )
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var leaderboardView: some View {
        List {
            Section("Relay Results") {
                ForEach(Array(teams.sorted(by: teamSort).enumerated()), id: \.element.id) { index, team in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(index + 1). \(team.name)")
                                .font(.headline)

                            Spacer()

                            Text(timeText(store.relayTeamSeconds[team.id] ?? 0))
                                .font(.headline)
                        }

                        Text(team.players.map(\.displayName).joined(separator: " • "))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(BackyardScoring.relayPoints(rankIndex: index)) BY pts per player")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .listStyle(.plain)
    }

    private func teamSort(_ a: BackyardTeam, _ b: BackyardTeam) -> Bool {
        let aTime = store.relayTeamSeconds[a.id] ?? 0
        let bTime = store.relayTeamSeconds[b.id] ?? 0

        if aTime == 0 {
            return false
        }

        if bTime == 0 {
            return true
        }

        return aTime < bTime
    }

    private func loadInputs() {
        var totals: [String: String] = [:]
        var splits: [String: [String: String]] = [:]

        for (teamId, seconds) in store.relayTeamSeconds {
            totals[teamId] = formatInput(seconds)
        }

        for (teamId, payload) in store.relaySplits {
            splits[teamId] = [:]

            for (playerId, seconds) in payload {
                splits[teamId]?[playerId] = formatInput(seconds)
            }
        }

        totalInputs = totals
        splitInputs = splits
    }

    private func saveTotal(teamId: String) {
        guard let text = totalInputs[teamId],
              let seconds = Double(text)
        else {
            return
        }

        Task {
            await store.saveRelayTeamTime(
                teamId: teamId,
                totalSeconds: seconds
            )
        }
    }

    private func saveSplit(teamId: String, playerId: String) {
        guard let text = splitInputs[teamId]?[playerId],
              let seconds = Double(text)
        else {
            return
        }

        Task {
            await store.saveRelaySplit(
                teamId: teamId,
                playerId: playerId,
                seconds: seconds
            )
        }
    }

    private func timeText(_ seconds: Double) -> String {
        guard seconds > 0 else {
            return "--"
        }

        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60

        return "\(minutes):" + String(format: "%02d", secs)
    }

    private func formatInput(_ seconds: Double) -> String {
        if seconds.rounded() == seconds {
            return "\(Int(seconds))"
        } else {
            return String(format: "%.1f", seconds)
        }
    }
}
