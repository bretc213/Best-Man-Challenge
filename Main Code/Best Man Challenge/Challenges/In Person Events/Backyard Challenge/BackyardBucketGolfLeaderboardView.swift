import SwiftUI

struct BackyardBucketGolfLeaderboardView: View {
    @EnvironmentObject private var store: BackyardChallengeStore

    @State private var selectedTab: BucketTab = .individual

    enum BucketTab: String, CaseIterable, Identifiable {
        case individual = "18 Ind."
        case altDoubles = "Alt Doubles"
        case closest = "Closest"
        case overall = "Overall"

        var id: String { rawValue }
    }

    var body: some View {
        ThemedScreen {
            VStack(spacing: 12) {
                Picker("Leaderboard", selection: $selectedTab) {
                    ForEach(BucketTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                List {
                    Section(sectionTitle) {
                        BackyardLeaderboardList(
                            rows: rows,
                            showThru: selectedTab == .individual,
                            rawLabel: rawLabel
                        )
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Bucket Golf Leaderboard")
        }
    }

    private var sectionTitle: String {
        switch selectedTab {
        case .individual: return "18 Holes Individual"
        case .altDoubles: return "9 Hole Alt Shot"
        case .closest: return "Closest to the Pin"
        case .overall: return "Bucket Golf Overall"
        }
    }

    private var rawLabel: String {
        switch selectedTab {
        case .individual:
            return "Golf"
        case .closest:
            return "Place"
        default:
            return "Score"
        }
    }

    private var rows: [BackyardStandingRow] {
        switch selectedTab {
        case .individual:
            return store.golf18Leaderboard()
        case .altDoubles:
            return store.finalScoreLeaderboard(gameId: .bucketGolfAlt9, doublesScoring: true)
        case .closest:
            return store.closestToPinLeaderboard()
        case .overall:
            return store.bucketGolfOverallRows()
        }
    }
}
