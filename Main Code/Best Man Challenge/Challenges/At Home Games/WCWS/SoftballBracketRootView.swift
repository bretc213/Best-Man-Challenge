//
//  SoftballBracketRootView.swift
//  Best Man Challenge
//

import SwiftUI

struct SoftballBracketRootView: View {
    @StateObject private var store: SoftballBracketStore
    let session: SessionStore

    @State private var selectedTab: SoftballTab = .picks

    enum SoftballTab: String, CaseIterable, Identifiable {
        case picks = "Picks"
        case standings = "Standings"
        case admin = "Admin"

        var id: String { rawValue }
    }

    init(challengeId: String = SoftballBracketConfig.challengeId, session: SessionStore) {
        _store = StateObject(wrappedValue: SoftballBracketStore(challengeId: challengeId))
        self.session = session
    }

    private var isAdmin: Bool {
        let role = session.role.lowercased()
        return role == "owner" || role == "admin" || role == "commish"
    }

    private var availableTabs: [SoftballTab] {
        isAdmin ? [.picks, .standings, .admin] : [.picks, .standings]
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("WCWS Tab", selection: $selectedTab) {
                ForEach(availableTabs) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            if let error = store.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)

                    Text("WCWS Bracket Error")
                        .font(.headline)

                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch selectedTab {
                case .picks:
                    SoftballBracketPicksView(store: store, session: session)

                case .standings:
                    SoftballBracketLeaderboardView(store: store)

                case .admin:
                    if isAdmin {
                        SoftballBracketAdminResultsView(store: store)
                    } else {
                        Text("Admin only")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .navigationTitle("WCWS Bracket")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.start(session: session)
        }
    }
}
