//
//  WBC2026RootView.swift
//  Best Man Challenge
//

import SwiftUI
import FirebaseAuth

struct WBC2026RootView: View {
    @EnvironmentObject var session: SessionStore

    @State private var selectedTab: WBCStage = .pool
    @State private var didStart = false

    @StateObject private var picksStore = WBC2026PicksStore(bracketId: "wbc_2026")
    @StateObject private var resultsStore = WBC2026ResultsStore(bracketId: "wbc_2026")
    @StateObject private var scoresStore = WBC2026ScoresStore(bracketId: "wbc_2026")

    private var isExec: Bool {
        let role = (session.profile?.role ?? "").lowercased()
        return ["owner", "commish", "ref", "admin", "exec"].contains(role)
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("", selection: $selectedTab) {
                ForEach(WBCStage.allCases) { tab in
                    if tab != .admin || isExec {
                        Text(tab.rawValue).tag(tab)
                    }
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            switch selectedTab {
            case .pool:
                WBCPoolPicksView(store: picksStore, session: session)

            case .quarters:
                WBCBracketRoundView(
                    title: "Quarterfinals",
                    matchups: picksStore.qfMatchups(for: picksStore.myEntry),
                    pickKeyPrefix: "qf",
                    pickValueProvider: { picksStore.myEntry?.qfPicks[$0] },
                    onPick: { key, teamId in
                        try await picksStore.setBracketPick(
                            uid: Auth.auth().currentUser?.uid ?? "",
                            displayName: session.profile?.displayName ?? "Unknown",
                            role: session.profile?.role ?? "",
                            linkedPlayerId: session.profile?.linkedPlayerId,
                            stage: "qfPicks",
                            key: key,
                            teamId: teamId
                        )
                    },
                    teamLabel: { teamId in picksStore.teamLabel(teamId) },
                    locked: picksStore.isLocked
                )

            case .semis:
                WBCBracketRoundView(
                    title: "Semifinals",
                    matchups: picksStore.sfMatchups(for: picksStore.myEntry),
                    pickKeyPrefix: "sf",
                    pickValueProvider: { picksStore.myEntry?.sfPicks[$0] },
                    onPick: { key, teamId in
                        try await picksStore.setBracketPick(
                            uid: Auth.auth().currentUser?.uid ?? "",
                            displayName: session.profile?.displayName ?? "Unknown",
                            role: session.profile?.role ?? "",
                            linkedPlayerId: session.profile?.linkedPlayerId,
                            stage: "sfPicks",
                            key: key,
                            teamId: teamId
                        )
                    },
                    teamLabel: { teamId in picksStore.teamLabel(teamId) },
                    locked: picksStore.isLocked
                )

            case .championship:
                WBCChampionshipView(store: picksStore, session: session)

            case .leaderboard:
                WBCLeaderboardView(scoresStore: scoresStore, session: session)

            case .admin:
                if isExec {
                    WBCAdminResultsView(picksStore: picksStore, resultsStore: resultsStore)
                } else {
                    Text("Admin only.")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
        }
        .task { startIfPossible() }
        .onChange(of: session.profile?.linkedPlayerId ?? "") { _, _ in startIfPossible() }
        .onChange(of: session.profile?.displayName ?? "") { _, _ in startIfPossible() }
        .onChange(of: session.profile?.role ?? "") { _, _ in startIfPossible() }
    }

    private func startIfPossible() {
        guard let profile = session.profile else { return }
        let uid = Auth.auth().currentUser?.uid ?? ""
        guard !uid.isEmpty else { return }

        let linked = profile.linkedPlayerId
        let ready = (linked?.isEmpty == false) || isExec
        guard ready else { return }

        if didStart { return }
        didStart = true

        picksStore.startListening(
            linkedPlayerId: linked,
            uid: uid,
            displayName: profile.displayName ?? "Unknown",
            role: profile.role ?? ""
        )
        resultsStore.startListening()
        scoresStore.startListening()
    }
}
