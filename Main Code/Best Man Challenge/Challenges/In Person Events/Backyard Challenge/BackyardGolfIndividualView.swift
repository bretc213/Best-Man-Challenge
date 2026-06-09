import SwiftUI

struct BackyardGolfIndividualView: View {
    @EnvironmentObject private var store: BackyardChallengeStore
    @EnvironmentObject private var session: SessionStore

    @State private var selectedHole = 1
    @State private var selectedScorerId = "bret"
    @State private var selectedTab: GolfTab = .input

    enum GolfTab: String, CaseIterable, Identifiable {
        case input = "Input"
        case golfLeaderboard = "Golf Leaderboard"
        case pointsLeaderboard = "BY Points"

        var id: String { rawValue }
    }

    private var selectedScorer: BackyardPlayer? {
        store.players.first { $0.id == selectedScorerId }
    }

    /// Admin: shows the selected scorer's tee time group.
    /// Player: shows only themselves.
    private var inputPlayers: [BackyardPlayer] {
        if session.isAdmin {
            let groupIds = BackyardPlayer.bucketGolfGroupPlayerIds(for: selectedScorerId)
            return groupIds.compactMap { playerId in
                store.players.first { $0.id == playerId }
            }
        } else {
            // Player only sees and enters their own score
            let myId = session.linkedPlayerId ?? ""
            if let me = store.players.first(where: { $0.id == myId }) {
                return [me]
            }
            return []
        }
    }

    var body: some View {
        ThemedScreen {
            VStack(spacing: 12) {
                Picker("View", selection: $selectedTab) {
                    ForEach(GolfTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch selectedTab {
                case .input:
                    inputView

                case .golfLeaderboard:
                    golfLeaderboardView

                case .pointsLeaderboard:
                    byPointsView
                }
            }
            .navigationTitle("18 Holes Individual")
            .onAppear {
                if session.isAdmin {
                    // Default scorer to first player if current default isn't in the list
                    if !store.players.contains(where: { $0.id == selectedScorerId }),
                       let first = store.players.first {
                        selectedScorerId = first.id
                    }
                } else {
                    // Lock scorer to the logged-in player
                    selectedScorerId = session.linkedPlayerId ?? selectedScorerId
                }
            }
            .task {
                await store.reloadGolf18ScoresFromFirestore()
            }
        }
    }

    private var inputView: some View {
        List {
            // Admin-only: scorer + group picker
            if session.isAdmin {
                Section("Scorer / Tee Time Group") {
                    Picker("Scorer", selection: $selectedScorerId) {
                        ForEach(store.players) { player in
                            Text(player.displayName).tag(player.id)
                        }
                    }

                    if let selectedScorer {
                        Text("Input covers \(selectedScorer.displayName)'s tee time group.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Hole") {
                Picker("Hole", selection: $selectedHole) {
                    ForEach(1...18, id: \.self) { hole in
                        Text("Hole \(hole)").tag(hole)
                    }
                }

                Text("Par \(store.bucketGolfPar(for: selectedHole))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Enter Strokes") {
                if inputPlayers.isEmpty {
                    Text("No player linked to your account.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(inputPlayers) { player in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.displayName)
                                    .font(.headline)

                                Text(currentStrokeSubtitle(for: player.id))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            strokeMenu(for: player.id)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var golfLeaderboardView: some View {
        List {
            Section("Live Golf Leaderboard") {
                ForEach(Array(store.golf18Leaderboard().enumerated()), id: \.element.id) { index, row in
                    golfRow(rank: index + 1, row: row)
                }
            }
        }
        .id(store.golfRefreshToken)
        .listStyle(.plain)
    }

    private var byPointsView: some View {
        List {
            Section("Projected BY Points") {
                ForEach(Array(store.golf18Leaderboard().enumerated()), id: \.element.id) { index, row in
                    byPointsRow(rank: index + 1, index: index, row: row)
                }
                .id(store.golfRefreshToken)
            }
        }
        .listStyle(.plain)
    }

    private func strokeMenu(for playerId: String) -> some View {
        let value = store.bucketGolfPickerValue(scorerId: selectedScorerId, playerId: playerId, hole: selectedHole)
        let label = value == -1 ? "—" : "\(value)"

        return Menu {
            Button("—") {
                store.clearBucketGolfScore(scorerId: selectedScorerId, playerId: playerId, hole: selectedHole)
            }

            ForEach(0...15, id: \.self) { strokes in
                Button("\(strokes)") {
                    store.updateBucketGolfScore(
                        scorerId: selectedScorerId,
                        playerId: playerId,
                        hole: selectedHole,
                        strokes: strokes
                    )
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.headline)
                    .frame(minWidth: 28, alignment: .trailing)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .frame(minWidth: 60, alignment: .trailing)
        }
    }

    private func currentStrokeSubtitle(for playerId: String) -> String {
        let value = store.bucketGolfPickerValue(scorerId: selectedScorerId, playerId: playerId, hole: selectedHole)
        if value == -1 { return "Not entered" }
        let par = store.bucketGolfPar(for: selectedHole)
        return "Hole \(selectedHole): \(value) strokes • Par \(par)"
    }

    private func golfRow(rank: Int, row: BackyardStandingRow) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.displayName)
                    .font(.headline)

                Text("Thru \(row.thru ?? 0)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(golfScoreText(row.rawScore))
                .font(.title3)
                .fontWeight(.bold)
        }
        .padding(.vertical, 6)
    }

    private func byPointsRow(rank: Int, index: Int, row: BackyardStandingRow) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline)
                .frame(width: 28)

            Text(row.displayName)
                .font(.headline)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(row.points)")
                    .font(.title3)
                    .fontWeight(.bold)

                Text(bmPointsText(for: index))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func golfScoreText(_ score: Double) -> String {
        let value = Int(score)
        if value == 0 { return "E" }
        if value > 0 { return "+\(value)" }
        return "\(value)"
    }

    private func bmPointsText(for index: Int) -> String {
        switch index {
        case 0: return "+5 BM Points"
        case 1: return "+3 BM Points"
        case 2: return "+1 BM Point"
        default: return ""
        }
    }
}
