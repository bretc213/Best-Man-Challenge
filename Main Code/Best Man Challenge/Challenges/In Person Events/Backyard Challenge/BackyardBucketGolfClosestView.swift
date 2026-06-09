import SwiftUI

struct BackyardBucketGolfClosestView: View {
    @EnvironmentObject private var store: BackyardChallengeStore
    @EnvironmentObject private var session: SessionStore

    @State private var selectedTab: ClosestTab = .leaderboard
    @State private var selectedHole = 1
    @State private var closestPlayerId = ""
    @State private var furthestPlayerId = ""
    @State private var pendingEliminationPlayerId: String?
    @State private var showEliminationConfirm = false

    enum ClosestTab: String, CaseIterable, Identifiable {
        case players = "Player Page"
        case holes = "Holes"
        case leaderboard = "Leaderboard"
        case points = "BY Points"

        var id: String { rawValue }
    }

    private var visibleTabs: [ClosestTab] {
        session.isAdmin ? ClosestTab.allCases : [.leaderboard, .points]
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
                case .players:
                    playerPage
                case .holes:
                    holesPage
                case .leaderboard:
                    leaderboardPage(title: "Closest to the Pin Leaderboard")
                case .points:
                    leaderboardPage(title: "Closest to the Pin BY Points")
                }
            }
            .navigationTitle("Closest to the Pin")
            .onAppear {
                // Default admin to Player Page; non-admin to Leaderboard
                selectedTab = session.isAdmin ? .players : .leaderboard
                if closestPlayerId.isEmpty {
                    closestPlayerId = store.players.first?.id ?? ""
                }
                if furthestPlayerId.isEmpty {
                    furthestPlayerId = store.players.first?.id ?? ""
                }
                loadHoleSelections()
            }
            .onChange(of: selectedHole) { _ in
                loadHoleSelections()
            }
            .alert("Confirm Elimination", isPresented: $showEliminationConfirm) {
                Button("Cancel", role: .cancel) {}

                Button("Eliminate", role: .destructive) {
                    saveHoleResult(eliminate: true)
                }
            } message: {
                Text(confirmMessage)
            }
        }
    }

    private var activePlayers: [BackyardPlayer] {
        store.players.filter { store.closestEliminatedPlaces[$0.id] == nil }
    }

    private var playerPage: some View {
        List {
            Section("Mulligans") {
                ForEach(store.players) { player in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(player.displayName)
                                .font(.headline)

                            if let place = store.closestEliminatedPlaces[player.id] {
                                Text("Eliminated: \(place) place")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text("\(store.closestMulligans[player.id] ?? 0)")
                            .font(.headline)

                        Button("Spend") {
                            Task {
                                await store.spendMulligan(playerId: player.id)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled((store.closestMulligans[player.id] ?? 0) <= 0)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var holesPage: some View {
        List {
            Section("Hole") {
                Picker("Hole", selection: $selectedHole) {
                    ForEach(1...11, id: \.self) { hole in
                        Text("Hole \(hole)").tag(hole)
                    }
                }
            }

            Section("Result") {
                Picker("Closest to the Pin", selection: $closestPlayerId) {
                    ForEach(activePlayers) { player in
                        Text(player.displayName).tag(player.id)
                    }
                }

                Picker("Furthest from the Pin", selection: $furthestPlayerId) {
                    ForEach(activePlayers) { player in
                        Text(player.displayName).tag(player.id)
                    }
                }

                Button("Save Hole Result") {
                    pendingEliminationPlayerId = furthestPlayerId
                    showEliminationConfirm = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(closestPlayerId.isEmpty || furthestPlayerId.isEmpty)
            }

            Section("Current Hole Saved") {
                Text("Closest: \(name(for: store.closestByHole[selectedHole]))")
                Text("Furthest: \(name(for: store.furthestByHole[selectedHole]))")
            }
        }
        .listStyle(.plain)
    }

    private func leaderboardPage(title: String) -> some View {
        List {
            Section(title) {
                BackyardLeaderboardList(
                    rows: store.closestToPinLeaderboard(),
                    showThru: false,
                    rawLabel: "Place"
                )
            }
        }
        .listStyle(.plain)
    }

    private var confirmMessage: String {
        guard let playerId = pendingEliminationPlayerId else {
            return "Are you sure this player should be eliminated?"
        }

        let mulligans = store.closestMulligans[playerId] ?? 0
        let playerName = name(for: playerId)

        return "\(playerName) has \(mulligans) mulligan(s) remaining. Are you sure they should be eliminated?"
    }

    private func loadHoleSelections() {
        closestPlayerId = store.closestByHole[selectedHole] ?? activePlayers.first?.id ?? store.players.first?.id ?? ""
        furthestPlayerId = store.furthestByHole[selectedHole] ?? activePlayers.first?.id ?? store.players.first?.id ?? ""
    }

    private func saveHoleResult(eliminate: Bool) {
        Task {
            await store.saveClosestHoleResult(
                hole: selectedHole,
                closestPlayerId: closestPlayerId,
                furthestPlayerId: furthestPlayerId,
                eliminate: eliminate
            )
        }
    }

    private func name(for playerId: String?) -> String {
        guard let playerId else { return "--" }
        return store.players.first(where: { $0.id == playerId })?.displayName ?? "--"
    }
}
