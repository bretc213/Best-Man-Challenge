import SwiftUI

struct WeeklyChallengesRootView: View {

    enum Tab: String, CaseIterable, Identifiable {
        case thisWeek = "This Week"
        case standings = "Standings"
        case howToPlay = "How To"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .thisWeek

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
                    case .thisWeek:
                        WeeklyChallengeView()

                    case .standings:
                        PlaceholderWeeklyStandingsView()

                    case .howToPlay:
                        PlaceholderWeeklyHowToPlayView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Weekly Challenges")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Temporary placeholders so it compiles now

private struct PlaceholderWeeklyStandingsView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("Standings")
                .font(.title2).bold()
            Text("Coming soon.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PlaceholderWeeklyHowToPlayView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("How To Play")
                .font(.title2).bold()
            Text("Coming soon.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
