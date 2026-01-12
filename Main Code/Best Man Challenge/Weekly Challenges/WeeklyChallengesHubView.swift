//
//  WeeklyChallengesHubView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/2/26.
//  Updated on 1/8/26: Navigate to WeeklyChallengesRootView (tabs), remove Week 1 hardcode.
//

import SwiftUI

struct WeeklyChallengesHubView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        ThemedScreen {
            List {
                Section {

                    // ✅ Main entry point now goes to the tabbed root
                    NavigationLink {
                        WeeklyChallengesRootView()
                            .environmentObject(session)
                    } label: {
                        hubRow(
                            title: "Weekly Challenge",
                            subtitle: "Current challenge, standings, past weeks, and overall leaderboard",
                            systemImage: "checklist"
                        )
                    }
                    


                    // OPTIONAL: Keep this if you still want a direct link to Week 1 standings.
                    // But it will become stale, so I recommend removing it once Overall/Past are live.
                    NavigationLink {
                        WeeklyChallengeLeaderboardView(
                            weekId: "2026_w01",
                            title: "Week 1 Standings"
                        )
                    } label: {
                        hubRow(
                            title: "Week 1 Standings (Legacy)",
                            subtitle: "Direct link (will be removed later)",
                            systemImage: "list.number"
                        )
                    }

                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.background)
            .navigationTitle("Weekly Challenges")
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
        WeeklyChallengesHubView()
            .environmentObject(SessionStore()) // Preview helper
    }
}
