//
//  NFLPickEmRootView.swift
//  Best Man Challenge
//

import SwiftUI
import FirebaseAuth

struct NFLPickEmRootView: View {
    @EnvironmentObject var session: SessionStore

    @StateObject private var store = NFLPickEmStore()
    @State private var selectedTab: NFLPickEmTab = .myPicks
    @State private var didStart = false

    private var isExec: Bool {
        let role = (session.profile?.role ?? "").lowercased()
        return ["owner", "commish", "ref", "admin", "exec"].contains(role)
    }

    private var watchedLinkedId: String { session.profile?.linkedPlayerId ?? "" }
    private var watchedRole: String     { session.profile?.role ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            tabContent
        }
        .navigationTitle("NFL Pick 'Em")
        .navigationBarTitleDisplayMode(.inline)
        .task { startIfReady() }
        .onChange(of: watchedLinkedId) { _, _ in startIfReady() }
        .onChange(of: watchedRole)     { _, _ in startIfReady() }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(visibleTabs) { tab in
                    NFLPickEmTabButton(
                        label: tab.rawValue,
                        isSelected: selectedTab == tab
                    ) { selectedTab = tab }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .myPicks:
            NFLPickEmPicksView(store: store, session: session)

        case .allPicks:
            NFLPickEmAllPicksView(store: store, session: session)

        case .leaderboard:
            NFLPickEmLeaderboardView(store: store, session: session)

        case .admin:
            if isExec {
                NFLPickEmAdminView(store: store, session: session)
            } else {
                Text("Admin only.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Helpers

    private var visibleTabs: [NFLPickEmTab] {
        NFLPickEmTab.allCases.filter { $0 != .admin || isExec }
    }

    private func startIfReady() {
        guard !didStart else { return }
        guard let profile = session.profile else { return }
        let uid = Auth.auth().currentUser?.uid ?? ""
        guard !uid.isEmpty else { return }

        let linked = profile.linkedPlayerId
        guard linked?.isEmpty == false || isExec else { return }

        didStart = true
        store.start(
            linkedPlayerId: linked,
            uid: uid,
            displayName: profile.displayName ?? "Unknown",
            role: profile.role ?? ""
        )
        store.listenWeekBonuses()
    }
}

// MARK: - Shared Tab Button

struct NFLPickEmTabButton: View {
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
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
