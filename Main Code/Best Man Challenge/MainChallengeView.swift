//
//  MainChallengeView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/2/26.
//

import SwiftUI

struct MainChallengeView: View {
    @EnvironmentObject var session: SessionStore

    // ✅ Create once so it doesn't get recreated every navigation
    @StateObject private var weeklyChallengeManager = WeeklyChallengeManager()

    var body: some View {
        ThemedScreen {
            List {
                Section {
                    NavigationLink {
                        AtHomeGamesView()
                    } label: {
                        hubRow(
                            title: "At Home Games",
                            subtitle: "Brackets, pools, and at-home challenges",
                            systemImage: "house.fill"
                        )
                    }

                    NavigationLink {
                        InPersonEventsView()
                    } label: {
                        hubRow(
                            title: "In Person Events",
                            subtitle: "Bigger point events, day-of rulings",
                            systemImage: "figure.run"
                        )
                    }

                    // ✅ Inject env objects for Weekly Challenges
                    NavigationLink {
                        WeeklyChallengesRootView()
                            .environmentObject(session)
                            .environmentObject(weeklyChallengeManager)
                    } label: {
                        hubRow(
                            title: "Weekly Challenges",
                            subtitle: "New weekly challenge when active",
                            systemImage: "flame.fill"
                        )
                    }

                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.background)
            .navigationTitle("Challenges")
        }
    }

    @ViewBuilder
    private func hubRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 46, height: 46)

                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationView {
        MainChallengeView()
    }
}
