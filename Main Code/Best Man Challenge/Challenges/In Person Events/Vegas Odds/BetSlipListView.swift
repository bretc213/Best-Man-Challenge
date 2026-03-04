//
//  BetSlipListView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 5/24/25.
//


import SwiftUI

struct BetSlipListView: View {
    let slips: [BetSlip]

    // MARK: - Odds Calculation
    private func winnings(for bet: Int, with odds: String) -> Double {
        let value = Double(odds.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "-", with: "")) ?? 0
        if odds.contains("+") {
            return (Double(bet) * value / 100).rounded()
        } else {
            return (Double(bet) / value * 100).rounded()
        }
    }

    private func totalWinnings(for slip: BetSlip) -> Double {
        let perPlayerBet = slip.betAmount / slip.selectedPlayers.count
        return zip(slip.selectedPlayers, slip.odds).map { winnings(for: perPlayerBet, with: $1) }.reduce(0, +)
    }

    private func totalToCollect(for slip: BetSlip) -> Double {
        Double(slip.betAmount) + totalWinnings(for: slip)
    }

    var body: some View {
        NavigationView {
            List(slips) { slip in
                VStack(alignment: .leading, spacing: 5) {
                    Text("Challenge: \(slip.challenge)")
                        .font(.headline)

                    Text("Players: \(slip.selectedPlayers.joined(separator: ", "))")
                        .font(.subheadline)

                    Text("Odds: \(slip.odds.joined(separator: ", "))")
                        .font(.footnote)
                        .foregroundColor(.gray)

                    Text("Wagered: $\(slip.betAmount)")
                    Text("To Win: $\(String(format: "%.2f", totalWinnings(for: slip)))")
                    Text("To Collect: $\(String(format: "%.2f", totalToCollect(for: slip)))")

                    Text("Date: \(slip.timestamp.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("All Bet Slips")
        }
    }
}
