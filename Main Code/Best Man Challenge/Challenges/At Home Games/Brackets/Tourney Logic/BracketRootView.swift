//
//  BracketRootView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/31/26.
//


import SwiftUI
import FirebaseFirestore

struct BracketRootView: View {
    @EnvironmentObject var session: SessionStore
    let gameRefId: String

    private enum TopTab: String, CaseIterable, Identifiable {
        case picks = "Picks"
        case allPicks = "All Picks"
        case futures = "Futures"
        case standings = "Standings"
        case admin = "Admin"
        var id: String { rawValue }
    }

    @State private var tab: TopTab = .picks

    private var isOwner: Bool {
        (session.profile?.role ?? "") == "owner"
    }

    private var visibleTabs: [TopTab] {
        // Owner sees Admin, everyone else does not.
        isOwner ? TopTab.allCases : TopTab.allCases.filter { $0 != .admin }
    }

    var body: some View {
        ThemedScreen {
            VStack(spacing: 12) {

                // Top tab strip (like NFL)
                Picker("Bracket Tab", selection: $tab) {
                    ForEach(visibleTabs) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 6)

                // Content
                Group {
                    switch tab {
                    case .picks:
                        BracketPicksView(gameRefId: gameRefId)

                    case .allPicks:
                        BracketAllPicksView(gameRefId: gameRefId)

                    case .futures:
                        BracketFuturesView(gameRefId: gameRefId)

                    case .standings:
                        BracketStandingsView(gameRefId: gameRefId)

                    case .admin:
                        BracketAdminResultsView(gameRefId: gameRefId)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("March Madness")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
