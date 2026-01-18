import SwiftUI

struct WeeklyChallengesRootView: View {
    @EnvironmentObject var challengeManager: WeeklyChallengeManager
    @EnvironmentObject var session: SessionStore

    private enum Tab: String, CaseIterable {
        case thisWeek = "This Week"
        case howToPlay = "How To Play"
        case standings = "Standings"
    }

    @State private var tab: Tab = .thisWeek

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                tabPicker
                tabContent
            }
            .navigationTitle("Weekly Challenge")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Small pieces (helps compiler)

    private var tabPicker: some View {
        Picker("", selection: $tab) {
            ForEach(Tab.allCases, id: \.self) { t in
                Text(t.rawValue).tag(t)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {

        case .thisWeek:
            WeeklyChallengeView()
                .environmentObject(challengeManager)
                .environmentObject(session)

        case .howToPlay:
            WeeklyHowToPlayPlaceholder()
                .padding(.horizontal)
                .padding(.top, 8)

        case .standings:
            WeeklyStandingsPlaceholder()
                .padding(.horizontal)
                .padding(.top, 8)
        }
    }
}

// MARK: - Placeholders (swap back to your real views later)

private struct WeeklyHowToPlayPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How To Play")
                .font(.title3.bold())
            Text("Hook this up to your How-To-Play view when ready.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct WeeklyStandingsPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Standings")
                .font(.title3.bold())
            Text("Hook this up to your Weekly Standings view when ready.")
                .foregroundStyle(.secondary)
        }
    }
}
