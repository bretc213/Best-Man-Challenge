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
            WeeklyHowToPlayView()
                .environmentObject(challengeManager)
                .environmentObject(session)

        case .standings:
            WeeklyChallengeStandingsView()
                .environmentObject(challengeManager)
        }
    }
}
