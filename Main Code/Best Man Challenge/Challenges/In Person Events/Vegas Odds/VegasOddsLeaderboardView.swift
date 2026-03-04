//
//  VegasOddsLeaderboardView.swift
//  Best Man Challenge
//

import SwiftUI

struct VegasOddsLeaderboardView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var leaderboardStore = VegasOddsLeaderboardStore()

    var body: some View {
        NavigationView {
            List {
                if let msg = leaderboardStore.errorMessage {
                    Text("Couldn’t load leaderboard: \(msg)")
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(leaderboardStore.rows.enumerated()), id: \.element.id) { index, row in
                    NavigationLink {
                        VegasOddsPlayerHistoryView(bettorId: row.id, bettorName: row.displayName)
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .frame(width: 22, alignment: .leading)

                            Text(row.displayName)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(String(format: "$%.2f", row.vegasWinnings))
                                .bold()
                                .frame(width: 120, alignment: .trailing)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Vegas Winnings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear { leaderboardStore.startListening() }
        .onDisappear { leaderboardStore.stopListening() }
    }
}
