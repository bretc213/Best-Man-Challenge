import SwiftUI

struct BackyardChallengeHomeView: View {
    let eventId: String

    @StateObject private var store: BackyardChallengeStore
    @EnvironmentObject private var session: SessionStore

    init(eventId: String) {
        self.eventId = eventId
        _store = StateObject(wrappedValue: BackyardChallengeStore(eventId: eventId))
    }

    var body: some View {
        ThemedScreen {
            List {
                Section("Backyard Games") {
                    ForEach(visibleSections) { section in
                        NavigationLink {
                            destination(for: section)
                        } label: {
                            Label(section.rawValue, systemImage: section.icon)
                                .font(.headline)
                                .padding(.vertical, 6)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Backyard Challenge")
            .background(Color.background)
            .task {
                await store.bootstrapIfNeeded()
                store.startListeners()
            }
        }
    }

    // Relay race was not held. Admin reset hidden from non-admins.
    private var visibleSections: [BackyardGameSection] {
        BackyardGameSection.allCases.filter { section in
            if section == .relayRace { return false }
            if section == .adminReset { return session.isAdmin }
            return true
        }
    }

    @ViewBuilder
    private func destination(for section: BackyardGameSection) -> some View {
        switch section {
        case .bucketGolf:
            BackyardLeaderboardsView(mode: .gameGroup("Bucket Golf"))
                .environmentObject(store)

        case .cornhole:
            BackyardLeaderboardsView(mode: .gameGroup("Cornhole"))
                .environmentObject(store)

        case .qb54:
            BackyardLeaderboardsView(mode: .gameGroup("QB54"))
                .environmentObject(store)

        case .ladderBall:
            BackyardLeaderboardsView(mode: .gameGroup("Ladder Ball"))
                .environmentObject(store)

        case .relayRace:
            EmptyView()

        case .overallLeaderboard:
            BackyardLeaderboardsView(mode: .overall)
                .environmentObject(store)

        case .adminReset:
            BackyardAdminResetView()
                .environmentObject(store)
        }
    }
}
