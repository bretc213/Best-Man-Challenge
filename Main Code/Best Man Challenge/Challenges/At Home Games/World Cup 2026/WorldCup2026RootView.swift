//
//  WorldCup2026RootView.swift
//  Best Man Challenge

import SwiftUI
import FirebaseAuth
#if canImport(UIKit)
import UIKit
#endif

struct WorldCup2026RootView: View {
    @EnvironmentObject var session: SessionStore

    @StateObject private var picksStore     = WorldCup2026PicksStore(bracketId: "world_cup_2026")
    @StateObject private var resultsStore   = WorldCup2026ResultsStore(bracketId: "world_cup_2026")
    @StateObject private var scoresStore    = WorldCup2026ScoresStore(bracketId: "world_cup_2026")
    @StateObject private var knockoutStore  = WorldCup2026KnockoutStore(bracketId: "world_cup_2026")

    @State private var selectedTab: WCTab = .groupPicks
    @State private var didStart = false

    private var isExec: Bool {
        let role = (session.profile?.role ?? "").lowercased()
        return ["owner", "commish", "ref", "admin", "exec"].contains(role)
    }

    // Observed values extracted to avoid optional-chain inference in modifiers
    private var watchedLinkedId: String { session.profile?.linkedPlayerId ?? "" }
    private var watchedRole: String     { session.profile?.role ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            tabContent
        }
        .task { startIfReady() }
        .onChange(of: watchedLinkedId) { _, _ in startIfReady() }
        .onChange(of: watchedRole)     { _, _ in startIfReady() }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(visibleTabs) { tab in
                    WCTabButton(label: tab.rawValue, isSelected: selectedTab == tab) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .groupPicks:
            NavigationView {
                WorldCup2026GroupPicksView(store: picksStore, session: session)
            }
            .navigationViewStyle(.stack)
        case .knockout:
            NavigationView {
                WorldCup2026KnockoutView(
                    picksStore: picksStore,
                    resultsStore: resultsStore,
                    knockoutStore: knockoutStore,
                    session: session
                )
            }
            .navigationViewStyle(.stack)
        case .leaderboard:
            NavigationView {
                WorldCup2026LeaderboardView(scoresStore: scoresStore, session: session)
            }
            .navigationViewStyle(.stack)
        case .allPicks:
            NavigationView {
                WorldCup2026AllPicksView(
                    picksStore: picksStore,
                    resultsStore: resultsStore,
                    session: session
                )
            }
            .navigationViewStyle(.stack)
        case .admin:
            adminTab
        }
    }

    @ViewBuilder
    private var adminTab: some View {
        if isExec {
            NavigationView {
                WorldCup2026AdminView(
                    picksStore: picksStore,
                    resultsStore: resultsStore,
                    scoresStore: scoresStore,
                    knockoutStore: knockoutStore,
                    session: session
                )
            }
            .navigationViewStyle(.stack)
        } else {
            Text("Admin only.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Helpers

    private var visibleTabs: [WCTab] {
        WCTab.allCases.filter { $0 != .admin || isExec }
    }

    private func startIfReady() {
        guard !didStart else { return }
        guard let profile = session.profile else { return }
        let uid = Auth.auth().currentUser?.uid ?? ""
        guard !uid.isEmpty else { return }
        let linked = profile.linkedPlayerId
        guard linked?.isEmpty == false || isExec else { return }

        didStart = true
        picksStore.startListening(
            linkedPlayerId: linked,
            uid: uid,
            displayName: profile.displayName ?? "Unknown",
            role: profile.role ?? ""
        )
        resultsStore.startListening()
        scoresStore.startListening()
        knockoutStore.startListening()
    }
}

// MARK: - Tab button extracted to its own type (avoids inference pressure in ForEach)

private struct WCTabButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(bgColor)
                .foregroundStyle(fgColor)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var bgColor: Color {
        isSelected ? Color.accentColor.opacity(0.15) : Color.clear
    }

    private var fgColor: Color {
        isSelected ? Color.accentColor : Color.primary
    }
}
