import SwiftUI

struct MastersDraftRootView: View {
    @EnvironmentObject var session: SessionStore
    let gameRefId: String

    private enum TopTab: String, CaseIterable, Identifiable {
        case board = "Draft"
        case teams = "Teams"
        case standings = "Standings"
        case admin = "Admin"

        var id: String { rawValue }
    }

    @State private var tab: TopTab = .board

    private var isOwner: Bool {
        (session.profile?.role ?? "") == "owner"
    }

    private var visibleTabs: [TopTab] {
        isOwner ? TopTab.allCases : TopTab.allCases.filter { $0 != .admin }
    }

    var body: some View {
        ThemedScreen {
            VStack(spacing: 12) {
                Picker("Masters Tab", selection: $tab) {
                    ForEach(visibleTabs) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 6)

                Group {
                    switch tab {
                    case .board:
                        MastersDraftBoardView(gameRefId: gameRefId)

                    case .teams:
                        MastersDraftTeamsView(gameRefId: gameRefId)

                    case .standings:
                        MastersDraftStandingsView(gameRefId: gameRefId)

                    case .admin:
                        MastersDraftAdminView(gameRefId: gameRefId)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("The Masters")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
