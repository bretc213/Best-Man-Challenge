import SwiftUI

struct BackyardFinalScoreInputView: View {
    let gameId: BackyardGameId

    @EnvironmentObject private var store: BackyardChallengeStore
    @EnvironmentObject private var session: SessionStore

    @State private var localInputs: [String: String] = [:]
    @State private var selectedTab: ScoreTab = .leaderboard

    enum ScoreTab: String, CaseIterable, Identifiable {
        case input = "Input"
        case leaderboard = "Leaderboard"
        case points = "BY Points"

        var id: String { rawValue }
    }

    /// Golf alt9 is the only non-admin game where players self-enter
    private var isPlayerSelfEntry: Bool { gameId == .bucketGolfAlt9 }

    /// These games use a 1-12 placement dropdown instead of a raw score text field
    private var isPlacementGame: Bool {
        gameId == .qb54Individual || gameId == .ladderBallIndividual
    }

    private var visibleTabs: [ScoreTab] {
        if session.isAdmin {
            return ScoreTab.allCases
        } else if isPlayerSelfEntry {
            return [.input, .leaderboard, .points]
        } else {
            return [.leaderboard, .points]
        }
    }

    var body: some View {
        ThemedScreen {
            VStack(spacing: 12) {
                if visibleTabs.count > 1 {
                    Picker("View", selection: $selectedTab) {
                        ForEach(visibleTabs) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                switch selectedTab {
                case .input:
                    isPlacementGame ? AnyView(placementInputView) : AnyView(textInputView)
                case .leaderboard, .points:
                    leaderboardView
                }
            }
            .navigationTitle(gameId.title)
            .onAppear {
                if !session.isAdmin && !isPlayerSelfEntry {
                    selectedTab = .leaderboard
                } else {
                    selectedTab = .input
                }
                loadInputs()
            }
            .onChange(of: store.finalScoresByGame[gameId] ?? [:]) { _ in
                loadInputs()
            }
        }
    }

    // MARK: - Placement Dropdown (QB54 Ind / Ladder Ball Ind)

    private var placementInputView: some View {
        List {
            Section("Assign place 1st – 12th") {
                ForEach(store.players) { player in
                    HStack {
                        Text(player.displayName)
                            .font(.headline)
                        Spacer()
                        placementMenu(for: player)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.plain)
    }

    private func currentPlace(for player: BackyardPlayer) -> Int? {
        let score = store.finalScoresByGame[gameId]?[player.id] ?? 0
        return score > 0 ? Int(score) : nil
    }

    private func placementMenu(for player: BackyardPlayer) -> some View {
        let place = currentPlace(for: player)
        let label = place.map { ordinal($0) } ?? "—"

        return Menu {
            Button("—") { savePlace(playerId: player.id, place: 0) }
            ForEach(1...12, id: \.self) { p in
                Button(ordinal(p)) { savePlace(playerId: player.id, place: p) }
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

    private func savePlace(playerId: String, place: Int) {
        Task {
            await store.saveFinalScore(gameId: gameId, playerId: playerId, score: Double(place))
        }
    }

    // MARK: - Text Input (Golf Alt9 self-entry)

    private var textInputView: some View {
        List {
            Section(gameId.scoringLabel) {
                ForEach(playersToShow) { player in
                    HStack {
                        Text(player.displayName)
                        Spacer()
                        TextField(
                            "Score",
                            text: Binding(
                                get: { localInputs[player.id] ?? "" },
                                set: { localInputs[player.id] = $0 }
                            )
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                        Button("Save") { save(playerId: player.id) }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var playersToShow: [BackyardPlayer] {
        if session.isAdmin {
            return store.players
        } else {
            let myId = session.linkedPlayerId ?? ""
            return store.players.filter { $0.id == myId }
        }
    }

    // MARK: - Leaderboard

    private var leaderboardView: some View {
        List {
            Section("Standings") {
                BackyardLeaderboardList(
                    rows: rows,
                    showThru: false,
                    rawLabel: isPlacementGame ? "Place" : "Score"
                )
            }
        }
        .listStyle(.plain)
    }

    private var rows: [BackyardStandingRow] {
        switch gameId {
        case .bucketGolfClosest:
            return store.closestToPinLeaderboard()
        case .ladderBallIndividual, .qb54Individual:
            return store.finalScoreLeaderboard(gameId: gameId, multiplier: 2)
        default:
            return store.finalScoreLeaderboard(gameId: gameId)
        }
    }

    // MARK: - Helpers

    private func loadInputs() {
        let scores = store.finalScoresByGame[gameId] ?? [:]
        var next: [String: String] = [:]
        for player in store.players {
            if let score = scores[player.id] {
                next[player.id] = score.rounded() == score ? "\(Int(score))" : String(format: "%.1f", score)
            }
        }
        localInputs = next
    }

    private func save(playerId: String) {
        guard let text = localInputs[playerId], let score = Double(text) else { return }
        Task { await store.saveFinalScore(gameId: gameId, playerId: playerId, score: score) }
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }
}
