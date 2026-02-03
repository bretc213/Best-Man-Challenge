import SwiftUI

struct WeeklyChallengesHubView: View {
    @EnvironmentObject var session: SessionStore

    // ✅ Own these once for the Weekly Challenges area
    @StateObject private var weeklyManager = WeeklyChallengeManager()
    @StateObject private var historyStore = WeeklyChallengesHistoryStore()

    var body: some View {
        NavigationStack {   // ✅ THE single NavigationStack for this area
            ThemedScreen {
                List {
                    Section("Weekly Challenges") {

                        NavigationLink {
                            WeeklyChallengesRootView()
                                .environmentObject(weeklyManager)
                                .environmentObject(session)
                        } label: {
                            hubRow(
                                title: "This Week",
                                subtitle: "Current challenge, how to play, and standings",
                                systemImage: "flame.fill"
                            )
                        }

                        /* NavigationLink {
                            WeeklyChallengesPastListView(store: historyStore)
                                .environmentObject(session)
                                .environmentObject(weeklyManager)
                        } label: {
                            hubRow(
                                title: "Past Weeks",
                                subtitle: "View prior weekly challenges and results",
                                systemImage: "clock.arrow.circlepath"
                            )
                        } */

                        NavigationLink {
                            UnderConstructionView()
                        } label: {
                            hubRow(
                                title: "Past Weeks",
                                subtitle: "View prior weekly challenges and results",
                                systemImage: "clock.arrow.circlepath"
                            )
                        }

                        NavigationLink {
                            WeeklyOverallLeaderboardView()
                                .environmentObject(session)
                        } label: {
                            hubRow(
                                title: "Overall Leaderboard",
                                subtitle: "Total points across all weekly challenges",
                                systemImage: "trophy.fill"
                            )
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.background)
                .navigationTitle("Weekly Challenges")
                .navigationBarTitleDisplayMode(.large)
            }
        }
    }

    @ViewBuilder
    private func hubRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 46, height: 46)

                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
