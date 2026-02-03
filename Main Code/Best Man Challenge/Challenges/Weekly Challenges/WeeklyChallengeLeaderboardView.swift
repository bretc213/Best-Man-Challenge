//
//  WeeklyChallengeLeaderboardView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/2/26.
//


import SwiftUI

struct WeeklyChallengeLeaderboardView: View {
    let weekId: String
    let title: String

    @StateObject private var store = WeeklyChallengeLeaderboardStore()

    var body: some View {
        ThemedScreen {
            List {
                if let msg = store.errorMessage {
                    Text("Couldn’t load standings: \(msg)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                Section(header: headerRow) {
                    ForEach(store.standings) { s in
                        StandingRow(standing: s)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(title)
        }
        .onAppear { store.startListening(weekId: weekId) }
        .onDisappear { store.stopListening() }
    }

    private var headerRow: some View {
        HStack {
            Text("Name")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Pts")
                .frame(width: 50, alignment: .trailing)
        }
        .font(.caption.bold())
        .secondaryText()
    }
}

private struct StandingRow: View {
    let standing: WeeklyChallengeStanding

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(standing.displayName)
                    .foregroundStyle(Color.textPrimary)

                if !standing.hasSubmitted {
                    Text("No submission")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("\(standing.points)")
                .frame(width: 50, alignment: .trailing)
                .fontWeight(.semibold)
        }
        .cardStyle()
    }
}
