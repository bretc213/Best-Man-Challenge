import SwiftUI

struct BackyardChallengeGameHubView: View {
    let title: String
    let entries: [BackyardGameId]

    @EnvironmentObject private var store: BackyardChallengeStore
    @EnvironmentObject private var session: SessionStore

    /// Golf hub entries are always shown (those views self-gate by role).
    /// Non-golf hub entries are admin-only — players reach those hubs directly as leaderboards.
    private var visibleEntries: [BackyardGameId] {
        let isGolfHub = title == "Bucket Golf"
        if session.isAdmin || isGolfHub {
            return entries
        }
        return []
    }

    var body: some View {
        ThemedScreen {
            List {
                Section {
                    BackyardPriorityDeclarationView()
                        .listRowBackground(Color.clear)
                }

                if !visibleEntries.isEmpty {
                    Section(title) {
                        ForEach(visibleEntries) { game in
                            NavigationLink {
                                destination(for: game)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(game.title)
                                        .font(.headline)

                                    Text(game.scoringLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 6)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                }

                Section("Leaderboard") {
                    NavigationLink("\(title) Leaderboard") {
                        if title == "Bucket Golf" {
                            BackyardBucketGolfLeaderboardView()
                                .environmentObject(store)
                        } else if title == "Cornhole" {
                            BackyardCornholeLeaderboardView()
                                .environmentObject(store)
                        } else {
                            BackyardLeaderboardsView(mode: .gameGroup(title))
                                .environmentObject(store)
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .navigationTitle(title)
            .background(Color.background)
        }
    }

    @ViewBuilder
    private func destination(for game: BackyardGameId) -> some View {
        switch game {
        case .bucketGolfInd18:
            BackyardGolfIndividualView()
                .environmentObject(store)

        case .bucketGolfClosest:
            BackyardBucketGolfClosestView()
                .environmentObject(store)

        case .cornholeDeka:
            BackyardDekaAdminView()
                .environmentObject(store)

        case .cornholeSingles:
            BackyardCornholeSinglesView()
                .environmentObject(store)

        case .bucketGolfAlt9:
            BackyardFinalScoreInputView(gameId: game)
                .environmentObject(store)

        case .cornholeDoubles, .ladderBallDoubles, .qb54Doubles:
            BackyardDoublesScoreInputView(gameId: game)
                .environmentObject(store)

        case .relayRace:
            BackyardRelayRaceView()
                .environmentObject(store)

        default:
            BackyardFinalScoreInputView(gameId: game)
                .environmentObject(store)
        }
    }
}
