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

    // MARK: - Odds helpers

    private func parseAmerican(_ odds: String) -> Int? {
        let s = odds.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        return Int(s) ?? Int(s.replacingOccurrences(of: "+", with: ""))
    }

    /// Profit (not including stake) for a single straight bet.
    private func straightProfit(stake: Double, americanOdds: Int) -> Double {
        if americanOdds >= 0 {
            return stake * (Double(americanOdds) / 100.0)
        } else {
            return stake * (100.0 / Double(-americanOdds))
        }
    }

    private func decimalOdds(from americanOdds: Int) -> Double {
        if americanOdds >= 0 {
            return 1.0 + (Double(americanOdds) / 100.0)
        } else {
            return 1.0 + (100.0 / Double(-americanOdds))
        }
    }

    // MARK: - Stakes

    private var picksCount: Int { max(1, slip.odds.count) }

    /// Straight bets: total wager split across picks.
    private var perPickStake: Double {
        Double(slip.betAmount) / Double(picksCount)
    }

    /// ✅ Parlay stake is ONE pick cost ($100), not total wager.
    private var parlayStake: Double {
        perPickStake
    }

    // MARK: - Totals (Straight)

    private var straightToWin: Double {
        zip(slip.selectedPlayers, slip.odds).reduce(0.0) { acc, pair in
            guard let a = parseAmerican(pair.1) else { return acc }
            return acc + straightProfit(stake: perPickStake, americanOdds: a)
        }
    }

    private var straightToCollect: Double {
        Double(slip.betAmount) + straightToWin
    }

    // MARK: - Totals (Parlay using $100 stake)

    private var parlayToWin: Double {
        let decimals: [Double] = slip.odds.compactMap { s in
            guard let a = parseAmerican(s) else { return nil }
            return decimalOdds(from: a)
        }
        guard decimals.count == slip.odds.count, !decimals.isEmpty else { return 0 }

        let parlayDecimal = decimals.reduce(1.0, *)
        let profit = (parlayStake * parlayDecimal) - parlayStake
        return max(0, profit).rounded()
    }

    private var totalCollectWithParlay: Double {
        straightToCollect + parlayToWin
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
                    Text("[\(slip.challenge)] \(slip.selectedPlayers[i])     \(slip.odds.indices.contains(i) ? slip.odds[i] : "")")
                        .font(.system(.body, design: .monospaced))
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                Text("TOTAL WAGER:   $\(slip.betAmount)")
                Text("TO WIN:        $\(String(format: "%.0f", straightToWin))")
                Text("TO COLLECT:    $\(String(format: "%.0f", straightToCollect))")

                Text("PARLAY WIN:   $\(String(format: "%.0f", parlayToWin))")
                Text("TOTAL COLLECT:$\(String(format: "%.0f", totalCollectWithParlay))")
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
