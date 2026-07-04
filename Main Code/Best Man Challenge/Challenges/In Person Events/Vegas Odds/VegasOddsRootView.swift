//
//  VegasOddsRootView.swift
//  Best Man Challenge
//
//  Top-level container for the Vegas Odds challenge.
//  Provides segmented tabs: Standings | Sportsbook | Past Slips | Admin (owner only).
//

import SwiftUI

private enum VegasTab: Hashable {
    case standings, sportsbook, pastSlips, admin
}

struct VegasOddsRootView: View {
    @EnvironmentObject var session: SessionStore
    @State private var selectedTab: VegasTab = .standings

    private var isAdmin: Bool {
        let role = session.profile?.role ?? ""
        return role == "owner" || role == "commish"
    }

    var body: some View {
        ThemedScreen {
            VStack(spacing: 0) {
                // Segmented picker — matches EventsRootView style
                Picker("", selection: $selectedTab) {
                    Text("Standings").tag(VegasTab.standings)
                    Text("Sportsbook").tag(VegasTab.sportsbook)
                    Text("Past Slips").tag(VegasTab.pastSlips)
                    if isAdmin {
                        Text("Admin").tag(VegasTab.admin)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                Divider().opacity(0.25)

                // Tab content
                switch selectedTab {
                case .standings:
                    VegasOddsLeaderboardTab()
                case .sportsbook:
                    VegasOddsView()
                case .pastSlips:
                    VegasOddsPastSlipsView()
                case .admin:
                    VegasOddsAdminView()
                }
            }
        }
        .navigationTitle("Vegas Odds")
        .navigationBarTitleDisplayMode(.inline)
        // If admin role is revoked mid-session, fall back to standings
        .onChange(of: isAdmin) { adminNow in
            if !adminNow && selectedTab == .admin { selectedTab = .standings }
        }
    }
}
