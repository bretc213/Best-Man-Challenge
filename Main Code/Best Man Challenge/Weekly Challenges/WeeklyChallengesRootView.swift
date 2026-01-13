import SwiftUI

struct WeeklyChallengesRootView: View {
    @EnvironmentObject var session: SessionStore

    enum Tab: String, CaseIterable, Identifiable {
        case current = "Current"
        case week = "Week"
        case overall = "Overall"
        case past = "Past"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .current
    @StateObject private var manager = WeeklyChallengeManager()

    // ✅ Overall store lives here so it persists while switching tabs
    @StateObject private var overallStore = WeeklyOverallStore()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                Divider().opacity(0.35)

                Group {
                    switch tab {
                    case .current:
                        WeeklyChallengeView()
                            .environmentObject(manager)

                    case .week:
                        // ✅ use the REAL week standings view
                        WeeklyChallengeStandingsView()
                            .environmentObject(manager)

                    case .overall:
                        // ✅ use the REAL overall view and pass the store
                        WeeklyChallengesOverallLeaderboardView(store: overallStore)

                    case .past:
                        WeeklyPastChallengesPlaceholderView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Weekly Challenges")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                manager.setUserContext(
                    linkedPlayerId: session.profile?.linkedPlayerId,
                    displayName: session.profile?.displayName
                )
            }
            .onChange(of: session.profile?.linkedPlayerId ?? "") { _, _ in
                manager.setUserContext(
                    linkedPlayerId: session.profile?.linkedPlayerId,
                    displayName: session.profile?.displayName
                )
            }
            .onChange(of: session.profile?.displayName ?? "") { _, _ in
                manager.setUserContext(
                    linkedPlayerId: session.profile?.linkedPlayerId,
                    displayName: session.profile?.displayName
                )
            }
        }
    }
}

// MARK: - v2.2 placeholder (Past only)

private struct WeeklyPastChallengesPlaceholderView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("Past Challenges")
                .font(.title2.bold())
            Text("Under construction.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
