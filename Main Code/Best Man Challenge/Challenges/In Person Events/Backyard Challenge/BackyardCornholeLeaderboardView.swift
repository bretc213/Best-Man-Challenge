import SwiftUI

struct BackyardCornholeLeaderboardView: View {
    @EnvironmentObject private var store: BackyardChallengeStore

    @State private var selectedTab: CornholeTab

    init(initialTab: CornholeTab = .overall) {
        _selectedTab = State(initialValue: initialTab)
    }

    enum CornholeTab: String, CaseIterable, Identifiable {
        case deka = "Deka"
        case singles = "Singles"
        case doubles = "Doubles"
        case overall = "Overall"

        var id: String { rawValue }
    }

    var body: some View {
        ThemedScreen {
            VStack(spacing: 12) {
                Picker("Leaderboard", selection: $selectedTab) {
                    ForEach(CornholeTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                List {
                    Section(sectionTitle) {
                        if selectedTab == .overall {
                            overallRowsView
                        } else {
                            BackyardLeaderboardList(
                                rows: rows,
                                showThru: false
                            )
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Cornhole Leaderboard")
        }
    }

    private var overallRowsView: some View {
        ForEach(store.players) { player in
            let deka = store.dekaLeaderboard().first(where: { $0.playerId == player.id })?.points ?? 0
            let singles = store.cornholeSinglesBonusRows().first(where: { $0.playerId == player.id })?.points ?? 0
            let doubles = store.finalScoreLeaderboard(gameId: .cornholeDoubles, doublesScoring: true).first(where: { $0.playerId == player.id })?.points ?? 0
            let total = deka + singles + doubles

            HStack {
                VStack(alignment: .leading) {
                    Text(player.displayName)
                        .font(.headline)

                    Text("\(deka) Deka • \(singles) Singles • \(doubles) Doubles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(total) BY pts")
                    .font(.headline)
            }
            .padding(.vertical, 6)
        }
    }

    private var sectionTitle: String {
        switch selectedTab {
        case .deka: return "Cornhole Deka"
        case .singles: return "Singles Bonus Points"
        case .doubles: return "Doubles Points"
        case .overall: return "Cornhole Overall"
        }
    }

    private var rows: [BackyardStandingRow] {
        switch selectedTab {
        case .deka:
            return store.dekaLeaderboard()
        case .singles:
            return store.cornholeSinglesBonusRows()
        case .doubles:
            return store.finalScoreLeaderboard(gameId: .cornholeDoubles, doublesScoring: true)
        case .overall:
            return store.cornholeOverallRows()
        }
    }
}
