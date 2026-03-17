import SwiftUI

struct MLBFuturesRootView: View {
    @StateObject private var store = MLBFuturesStore()

    let userId: String
    let displayName: String
    let isAdmin: Bool

    @State private var selectedTab: Tab = .submit

    private enum Tab: String, CaseIterable, Identifiable {
        case submit = "Submit"
        case allPicks = "All Picks"
        case summary = "Summary"
        case standings = "Standings"
        case admin = "Admin"

        var id: String { rawValue }
    }

    private var availableTabs: [Tab] {
        isAdmin ? [.submit, .allPicks, .summary, .standings, .admin]
                : [.submit, .allPicks, .summary, .standings]
    }

    var body: some View {
        ThemedScreen {
            VStack(spacing: 12) {
                Picker("MLB Futures Section", selection: $selectedTab) {
                    ForEach(availableTabs) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                Group {
                    switch selectedTab {
                    case .submit:
                        MLBFuturesSubmissionView(
                            store: store,
                            userId: userId,
                            displayName: displayName
                        )

                    case .allPicks:
                        MLBFuturesAllPicksView(store: store)

                    case .summary:
                        MLBFuturesSummaryView(store: store)

                    case .standings:
                        MLBFuturesStandingsView(store: store)

                    case .admin:
                        if isAdmin {
                            MLBFuturesAdminView(store: store)
                        } else {
                            ContentUnavailableView(
                                "Admin Only",
                                systemImage: "lock.shield",
                                description: Text("You do not have access to this section.")
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("MLB Futures")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            store.startListening()
        }
    }
}
