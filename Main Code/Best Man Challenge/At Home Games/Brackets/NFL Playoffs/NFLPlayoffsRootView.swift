//
//  NFLPlayoffsRootView.swift
//  Best Man Challenge
//

import SwiftUI
import FirebaseAuth

struct NFLPlayoffsRootView: View {
    @EnvironmentObject var session: SessionStore

    @State private var selectedRound: BracketRound = .wildcard
    @State private var selectedTab: Tab = .picks

    // ✅ Prevent repeated starts (fixes flashing / blank states)
    @State private var didStart = false

    @StateObject private var picksStore = NFLPlayoffsPicksStore(
        bracketId: "nfl_2026_playoffs",
        roundId: BracketRound.wildcard.rawValue
    )

    @StateObject private var scoresStore = NFLPlayoffsScoresStore(
        bracketId: "nfl_2026_playoffs"
    )

    // ✅ Futures store reads from picks/wildcard and is constant regardless of selectedRound
    @StateObject private var futuresStore = NFLFuturesStore(
        bracketId: "nfl_2026_playoffs"
    )

    enum Tab: String, CaseIterable {
        case picks = "Picks"
        case myPicks = "All Picks"
        case futures = "Futures"
        case leaderboard = "Standings"
        case admin = "Admin"
    }

    private var isExec: Bool {
        let role = (session.profile?.role ?? "").lowercased()
        return ["owner", "commish", "ref", "admin", "exec"].contains(role)
    }

    var body: some View {
        VStack(spacing: 12) {

            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    if tab != .admin || isExec {
                        Text(tab.rawValue).tag(tab)
                    }
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            switch selectedTab {
            case .picks:
                NFLThisWeekPicksView(store: picksStore, selectedRound: $selectedRound)
                    .environmentObject(session)

            case .myPicks:
                NFLAllPicksView(store: picksStore, session: session)

            case .futures:
                // ✅ Constant screen: not tied to selectedRound
                // teamName: for now just show abbreviation (e.g., "LAR").
                // Later you can map to full names/logos.
                NFLFuturesView(
                    futuresStore: futuresStore,
                    teamName: { abbrev in abbrev }
                )

            case .leaderboard:
                NFLBracketLeaderboardView(scoresStore: scoresStore, session: session)

            case .admin:
                if isExec {
                    NFLAdminWinnersView(store: picksStore, session: session)
                } else {
                    Text("Admin only.")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
        }
        // ✅ Start once
        .task { startIfPossible() }

        // ✅ If identity changes, try starting again (but idempotent)
        .onChange(of: session.profile?.linkedPlayerId ?? "") { _, _ in startIfPossible() }
        .onChange(of: session.profile?.displayName ?? "") { _, _ in startIfPossible() }
        .onChange(of: session.profile?.role ?? "") { _, _ in startIfPossible() }

        // ✅ Keep store roundId in sync
        .onChange(of: selectedRound) { _, newValue in
            picksStore.setRound(newValue.rawValue)
        }

        // ❌ Do NOT stop listeners here; it can fire during transitions and kill your updates.
        // .onDisappear { picksStore.stopListening(); scoresStore.stopListening() }
    }

    /// ✅ Single source of truth for starting listeners
    private func startIfPossible() {
        guard let profile = session.profile else { return }

        let uid = Auth.auth().currentUser?.uid ?? ""
        guard !uid.isEmpty else { return }

        // We allow:
        // - players with linkedPlayerId
        // - exec/admin users even without linkedPlayerId
        let linked = profile.linkedPlayerId
        let ready = (linked?.isEmpty == false) || isExec
        guard ready else { return }

        // ✅ Don’t restart listeners if already started.
        // Just ensure round stays in sync.
        if didStart {
            picksStore.setRound(selectedRound.rawValue)
            return
        }

        didStart = true

        // Ensure store is on current round before starting
        picksStore.setRound(selectedRound.rawValue)

        // Start picks listener (players or admins lane handled inside store)
        picksStore.startListening(
            linkedPlayerId: linked,
            uid: uid,
            displayName: profile.displayName ?? "Unknown",
            role: profile.role ?? ""
        )

        // Start leaderboard listener
        scoresStore.startListening()

        // ✅ futuresStore starts listening in its init; nothing needed here
    }
}
