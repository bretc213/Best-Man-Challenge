//
//  VegasOddsHomeView.swift
//  Best Man Challenge
//

import SwiftUI

/// Lightweight home/landing screen for Vegas Odds.
/// - Shows leaderboard (total net winnings across events)
/// - Button to enter betting slip
struct VegasOddsHomeView: View {

    @StateObject private var leaderboardStore = VegasOddsLeaderboardStore()
    @State private var showBetting = false

    var body: some View {

        VStack(spacing: 16) {
            header

            if let msg = leaderboardStore.errorMessage {
                Text("Couldn’t load leaderboard: \(msg)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            List {
                ForEach(Array(leaderboardStore.rows.enumerated()), id: \.element.id) { index, row in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .frame(width: 22, alignment: .leading)

                        Text(row.displayName)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(String(format: "$%.2f", row.vegasWinnings))
                            .frame(width: 120, alignment: .trailing)
                            .bold()
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)

            Button("Enter Betting Slip") {
                showBetting = true
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.bottom, 6)

            // ✅ Hidden navigation trigger (keeps your InPersonEvents nav simple)
            NavigationLink(isActive: $showBetting) {
                // Pass an empty binding so this compiles even if VegasOddsView's binding init changes.
                VegasOddsView(allSlips: .constant([]))
            } label: {
                EmptyView()
            }
            .hidden()
        }
        .padding()
        .onAppear {
            leaderboardStore.startListening()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🎰 Vegas Odds")
                .font(.title2)
                .bold()

            HStack {
                Text("Player")
                Spacer()
                Text("Net Winnings")
                    .frame(width: 120, alignment: .trailing)
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        VegasOddsHomeView()
    }
}
