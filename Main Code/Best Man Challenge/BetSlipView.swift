//
//  BetSlipView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 5/24/25.
//


import SwiftUI

struct BetSlipView: View {
    let slip: BetSlip
    @Environment(\.presentationMode) var presentationMode

    // MARK: - Odds Calculation
    private func winnings(for bet: Int, with odds: String) -> Double {
        let value = Double(odds.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "-", with: "")) ?? 0
        if odds.contains("+") {
            return (Double(bet) * value / 100).rounded()
        } else {
            return (Double(bet) / value * 100).rounded()
        }
    }

    var totalToWin: Double {
        zip(slip.selectedPlayers, slip.odds).map { winnings(for: slip.betAmount / slip.selectedPlayers.count, with: $1) }.reduce(0, +)
    }

    var totalToCollect: Double {
        Double(slip.betAmount) + totalToWin
    }

    // MARK: - View
    var body: some View {
        VStack(spacing: 15) {
            Text("BEST MAN CHALLENGE SPORTSBOOK")
                .font(.system(.headline, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(.top)

            Divider()

            Text("CONFIRMED BET SLIP")
                .font(.system(.subheadline, design: .monospaced))
                .padding(.bottom, 5)

            Text("BET ID: \(slip.id.uuidString.prefix(12))")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(slip.selectedPlayers.indices, id: \.self) { i in
                    Text("[\(slip.challenge)] \(slip.selectedPlayers[i])     \(slip.odds[i])")
                        .font(.system(.body, design: .monospaced))
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                Text("TOTAL WAGER:   $\(slip.betAmount)")
                Text("TO WIN:        $\(String(format: "%.2f", totalToWin))")
                Text("TO COLLECT:    $\(String(format: "%.2f", totalToCollect))")
            }
            .font(.system(.body, design: .monospaced))
            .padding(.top, 5)

            Divider()

            Text("Printed: \(slip.timestamp.formatted(date: .abbreviated, time: .shortened))")
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.bottom, 20)

            Button("Back to Challenges") {
                presentationMode.wrappedValue.dismiss()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .navigationTitle("Bet Slip")
    }
}
