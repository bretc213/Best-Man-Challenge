import SwiftUI
import FirebaseFirestore

struct AtHomeGamesView: View {

    // MARK: - Tabs

    private enum Tab: String, CaseIterable, Identifiable {
        case comingUp = "Coming Up"
        case live = "Live"
        case archived = "Archived"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .live
    @StateObject private var store = AtHomeGamesStore()
    @EnvironmentObject private var session: SessionStore

    private let db = Firestore.firestore()

    // MARK: - Grid

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 120), spacing: 18)
    ]

    // MARK: - Filters

    private var filteredGames: [AtHomeGame] {
        switch tab {
        case .comingUp:
            return store.games.filter { $0.state == "coming_up" }
        case .live:
            return store.games.filter { $0.state == "live" }
        case .archived:
            return store.games.filter { $0.state == "archived" }
        }
    }

    private func autoSelectNonEmptyTabIfNeeded() {
        if !filteredGames.isEmpty { return }

        let hasLive = store.games.contains { $0.state == "live" }
        let hasComingUp = store.games.contains { $0.state == "coming_up" }
        let hasArchived = store.games.contains { $0.state == "archived" }

        if hasLive { tab = .live }
        else if hasComingUp { tab = .comingUp }
        else if hasArchived { tab = .archived }
    }

    // MARK: - View

    var body: some View {
        ThemedScreen {
            ScrollView {
                VStack(spacing: 14) {

                    Picker("At Home Tab", selection: $tab) {
                        ForEach(Tab.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 6)

                    if let msg = store.errorMessage {
                        Text("Couldn’t load at-home games: \(msg)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    LazyVGrid(columns: columns, spacing: 18) {
                        if filteredGames.isEmpty {
                            ContentUnavailableView(
                                tab == .archived ? "No archived games yet" :
                                    tab == .comingUp ? "Nothing coming up yet" : "No live games",
                                systemImage: tab == .archived ? "archivebox" :
                                    (tab == .comingUp ? "clock" : "flame"),
                                description: Text("At-home challenges will appear here when available.")
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.top, 30)
                        } else {
                            ForEach(filteredGames) { game in
                                NavigationLink {
                                    destinationView(for: game)
                                } label: {
                                    FolderIconTile(title: game.title, assetImage: game.assetImage)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    adminContextMenu(for: game)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("At Home Games")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { store.startListening() }
        .onReceive(store.$games) { _ in
            autoSelectNonEmptyTabIfNeeded()
        }
    }

    // MARK: - Admin context menu

    @ViewBuilder
    private func adminContextMenu(for game: AtHomeGame) -> some View {
        if isAdmin {
            if game.state == "coming_up" {
                Button {
                    Task { await updateState(for: game, to: "live") }
                } label: {
                    Label("Move to Live", systemImage: "flame.fill")
                }
                Button {
                    Task { await updateState(for: game, to: "archived") }
                } label: {
                    Label("Archive", systemImage: "archivebox.fill")
                }
            }

            if game.state == "live" {
                Button {
                    Task { await updateState(for: game, to: "coming_up") }
                } label: {
                    Label("Move back to Coming Up", systemImage: "clock.fill")
                }
                Button {
                    Task { await updateState(for: game, to: "archived") }
                } label: {
                    Label("Archive", systemImage: "archivebox.fill")
                }
            }

            if game.state == "archived" {
                Button {
                    Task { await updateState(for: game, to: "live") }
                } label: {
                    Label("Unarchive (Move to Live)", systemImage: "flame.fill")
                }
                Button {
                    Task { await updateState(for: game, to: "coming_up") }
                } label: {
                    Label("Unarchive (Move to Coming Up)", systemImage: "clock.fill")
                }
            }
        }
    }

    private var mlbFuturesUserId: String {
        session.profile?.linkedPlayerId ?? ""
    }

    private var isAdmin: Bool {
        let role = session.profile?.role ?? ""
        return role == "owner" || role == "commish"
    }

    private func updateState(for game: AtHomeGame, to newState: String) async {
        do {
            try await db.collection("at_home_games")
                .document(game.id)
                .updateData([
                    "state": newState,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
        } catch {
            print("❌ Failed to update state for \(game.id):", error)
        }
    }

    // MARK: - Destinations

    /// True if this tile is the CFB Conference Championships game, matched
    /// leniently (route / id / challengeId / title) so a manually-created
    /// placeholder tile routes to the real view even if its route field differs.
    private func isConfChampsTile(_ game: AtHomeGame) -> Bool {
        let keys = [game.route, game.id, game.challengeId ?? ""]
            .map { $0.lowercased() }
        if keys.contains(where: { $0.contains("conf_champ") || $0.contains("conf champ") }) {
            return true
        }
        let title = game.title.lowercased()
        return title.contains("conf. champ") || title.contains("conf champ")
    }

    @ViewBuilder
    private func destinationView(for game: AtHomeGame) -> some View {
        // Generic bracket routing (Firebase-driven)
        if game.gameType == "bracket",
           let ref = game.gameRefId,
           !ref.isEmpty {
            BracketRootView(gameRefId: ref)

        } else if game.gameType == "softball_bracket" {
            SoftballBracketRootView(
                challengeId: game.gameRefId ?? "wcws_2026",
                session: session
            )

        } else if isConfChampsTile(game) {
            // Matches the CFB Conf. Champs tile by route/id/challengeId/title,
            // so a manually-created placeholder tile still routes correctly.
            CFBConfChampsRootView()

        } else {
            switch game.route {

            case "cfb_bracket":
                CFBBracketView()

            case "nfl_playoffs":
                NFLPlayoffsRootView()

            case "wbc_2026":
                WBC2026RootView()

            case "mlb_futures":
                MLBFuturesRootView(
                    userId: mlbFuturesUserId,
                    displayName: session.profile?.displayName ?? "Player",
                    isAdmin: isAdmin
                )

            case "the_masters_2026":
                MastersDraftRootView(gameRefId: "masters_draft_2026")

            case "world_cup_2026":
                WorldCup2026RootView()

            case "nfl_pickem_2026":
                if game.state == "coming_up" {
                    ComingSoonChallengeView(
                        title: game.title,
                        subtitle: "Pick every game, every week. Picks lock at kickoff.",
                        systemImage: "football.fill",
                        startsAt: game.startsAt
                    )
                } else {
                    NFLPickEmRootView()
                }

            default:
                ComingSoonChallengeView(
                    title: game.title,
                    subtitle: "Challenge details coming soon",
                    startsAt: game.startsAt
                )
            }
        }
    }
}

#Preview {
    NavigationView {
        AtHomeGamesView()
            .environmentObject(SessionStore())
    }
}
