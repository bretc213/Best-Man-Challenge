//
//  VegasOddsHomeView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 5/24/25.
//

import SwiftUI

struct VegasOddsHomeView: View {
    let allSlips: [BetSlip]          // kept for compatibility
    let onStartBetting: () -> Void

    @StateObject private var playersStore = PlayersStore()
    @StateObject private var balanceStore = UserBalanceStore()

    var body: some View {
        VStack(spacing: 16) {
            header

            // Show Bret’s balance (the only bankroll that matters now)
            HStack {
                Text("Your Balance")
                    .foregroundColor(.secondary)
                Spacer()
                Text("$\(balanceStore.eventBalance)")
                    .bold()
            }
            .padding()
            .background(Color.gray.opacity(0.15))
            .cornerRadius(10)

            if let msg = playersStore.errorMessage {
                Text("Couldn’t load leaderboard: \(msg)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let msg = balanceStore.errorMessage {
                Text("Couldn’t load your balance: \(msg)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            List {
                ForEach(Array(playersStore.players.enumerated()), id: \.element.id) { index, p in
                    leaderboardRow(rank: index + 1, player: p)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)

            VStack(spacing: 10) {
                Button("Enter Betting Slip") {
                    onStartBetting()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)

                // Admin helper (Bret only): reset YOUR balance
                Button("Reset My Balance to $300") {
                    AdminTools.resetMyBalance(to: 300) { err in
                        if let err = err {
                            print("🔥 Reset failed:", err.localizedDescription)
                        } else {
                            print("✅ Reset balance complete")
                        }
                    }
                }
                .font(.footnote.bold())
                .foregroundColor(.secondary)
            }
            .padding(.bottom, 6)
        }
        .padding()
        .onAppear {
            playersStore.startListening()
            balanceStore.startListening()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🏆 Vegas Odds Leaderboard")
                .font(.title2)
                .bold()

            HStack {
                Text("Player")
                Spacer()
                Text("Winnings")
                    .frame(width: 100, alignment: .trailing)
            }
            .font(.caption.bold())
            .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func leaderboardRow(rank: Int, player: FirestorePlayer) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .frame(width: 22, alignment: .leading)

            Text(player.displayName)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("$\(String(format: "%.2f", player.totalWinnings))")
                .frame(width: 100, alignment: .trailing)
                .bold()
        }
        .padding(.vertical, 6)
    }
}
