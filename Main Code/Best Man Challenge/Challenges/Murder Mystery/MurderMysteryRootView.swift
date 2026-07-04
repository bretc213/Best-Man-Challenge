//
//  MurderMysteryRootView.swift
//  Best Man Challenge
//
//  "Dead in the Dust" — root tab container (admin test feature)
//

import SwiftUI

enum MMTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case suspects = "Suspects"
    case caseFiles = "Case Files"
    case locations = "Locations"
    case accusation = "Accusation"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard:  return "magnifyingglass.circle.fill"
        case .suspects:   return "person.3.fill"
        case .caseFiles:  return "folder.fill"
        case .locations:  return "map.fill"
        case .accusation: return "exclamationmark.bubble.fill"
        }
    }
}

struct MurderMysteryRootView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var store = MurderMysteryStore()
    @State private var tab: MMTab = .dashboard

    var body: some View {
        ThemedScreen {
            VStack(spacing: 0) {
                tabBar

                Group {
                    switch tab {
                    case .dashboard:
                        MurderMysteryDashboardView(store: store)
                    case .suspects:
                        MurderMysterySuspectsView()
                    case .caseFiles:
                        MurderMysteryCaseFilesView(store: store)
                    case .locations:
                        MurderMysteryLocationsView(store: store)
                    case .accusation:
                        MurderMysteryAccusationView(store: store)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Dead in the Dust")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MMTab.allCases) { t in
                    Button {
                        tab = t
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: t.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(t.rawValue)
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(tab == t ? Color.accent.opacity(0.25) : Color.white.opacity(0.08))
                        )
                        .overlay(
                            Capsule().strokeBorder(tab == t ? Color.accent : Color.clear, lineWidth: 1)
                        )
                        .foregroundStyle(tab == t ? Color.accent : Color.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}
