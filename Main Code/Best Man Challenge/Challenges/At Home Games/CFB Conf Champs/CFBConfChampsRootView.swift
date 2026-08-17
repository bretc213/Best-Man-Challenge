//
//  CFBConfChampsRootView.swift
//  Best Man Challenge
//

import SwiftUI
import FirebaseAuth

struct CFBConfChampsRootView: View {
    @EnvironmentObject var session: SessionStore

    @StateObject private var store = CFBConfChampsStore()
    @State private var selectedTab: CFBConfChampsTab = .preseason
    @State private var didStart = false

    private var isAdmin: Bool {
        ["owner", "commish", "ref", "admin", "exec"].contains((session.profile?.role ?? "").lowercased())
    }

    private var watchedLinkedId: String { session.profile?.linkedPlayerId ?? "" }
    private var watchedRole: String     { session.profile?.role ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            tabContent
        }
        .navigationTitle("CFB Conf. Champs")
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
                    CFBTabButton(label: tab.rawValue, isSelected: selectedTab == tab) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .background(Color(UIColor.secondarySystemBackground))
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .preseason:
            CFBPreseasonPicksView(store: store, session: session)
        case .champWeek:
            CFBChampWeekPicksView(store: store, session: session)
        case .leaderboard:
            CFBConfChampsLeaderboardView(store: store, session: session)
        case .allPicks:
            CFBConfChampsAllPicksView(store: store, session: session)
        case .admin:
            if isAdmin {
                CFBConfChampsAdminView(store: store, session: session)
            } else {
                Text("Admin only.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var visibleTabs: [CFBConfChampsTab] {
        CFBConfChampsTab.allCases.filter { $0 != .admin || isAdmin }
    }

    private func startIfReady() {
        guard !didStart else { return }
        guard let profile = session.profile else { return }
        let uid = Auth.auth().currentUser?.uid ?? ""
        guard !uid.isEmpty else { return }
        let linked = profile.linkedPlayerId
        guard linked?.isEmpty == false || isAdmin else { return }

        didStart = true
        store.start(
            linkedPlayerId: linked,
            displayName: profile.displayName ?? "Unknown",
            role: profile.role ?? ""
        )
    }
}

// MARK: - Shared Tab Button

struct CFBTabButton: View {
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

// MARK: - Shared Team Logo

/// Team badge. Uses the uploaded logo asset when one exists in the bundle;
/// otherwise falls back to a colored monogram (team initials on a stable,
/// per-team color) so every team stays visually distinct with no image assets.
struct CFBTeamLogo: View {
    let team: CFBTeam?
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            if let team, UIImage(named: team.logoAsset) != nil {
                Image(team.logoAsset)
                    .resizable()
                    .scaledToFit()
            } else {
                Circle()
                    .fill(badgeColor.gradient)
                    .overlay(
                        Text(monogram)
                            .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .padding(size * 0.1)
                    )
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                    )
            }
        }
        .frame(width: size, height: size)
    }

    /// 1–3 letter monogram derived from the team name.
    /// "Ohio State" → "OS", "Ole Miss" → "OM", "LSU" → "LSU", "Texas A&M" → "TA".
    private var monogram: String {
        guard let name = team?.name, !name.isEmpty else { return "?" }
        // All-caps acronym schools (LSU, BYU, TCU, UCLA, USC, UAB, UTSA, FIU, UNLV, UTEP, SMU, UCF…)
        if name == name.uppercased() {
            return String(name.filter { $0.isLetter }.prefix(3))
        }
        let words = name.split { !$0.isLetter }
        if words.count >= 2 {
            return words.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
        }
        return String(name.filter { $0.isLetter }.prefix(2)).uppercased()
    }

    /// Deterministic, launch-stable color per team (djb2 hash of the team id → hue).
    private var badgeColor: Color {
        let key = team?.id ?? "?"
        var hash: UInt64 = 5381
        for byte in key.utf8 { hash = (hash &* 33) ^ UInt64(byte) }
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.72)
    }
}
