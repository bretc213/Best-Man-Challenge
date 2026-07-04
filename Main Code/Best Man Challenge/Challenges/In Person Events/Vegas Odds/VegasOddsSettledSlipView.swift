//
//  VegasOddsSettledSlipView.swift
//  Best Man Challenge
//
//  Finalized bet slip: green/red picks, parlay bonus banner, net result.
//  Also used as a sheet from Past Slips.
//

import SwiftUI

// MARK: - Main View

struct VegasOddsSettledSlipView: View {
    let bet: VegasOddsBet?       // nil → player never placed a bet
    let eventName: String
    let betPerPick: Int

    private var totalWager: Int { betPerPick * 3 }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.25)

            if let bet {
                picksSection(bet)
                if bet.parlayHit {
                    Divider().opacity(0.25)
                    parlayBonusRow(bet)
                }
                Divider().opacity(0.25)
                summarySection(bet)
            } else {
                noBetSection
            }
        }
        .background(Color.gray.opacity(0.08))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 3) {
            Text(eventName)
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)
            Text("FINAL RESULTS")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
                .kerning(0.8)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Picks

    @ViewBuilder
    private func picksSection(_ bet: VegasOddsBet) -> some View {
        ForEach(Array(bet.picks.enumerated()), id: \.offset) { i, playerId in
            let name   = bet.pickDisplayNames.indices.contains(i) ? bet.pickDisplayNames[i] : playerId
            let odds   = bet.oddsStrings.indices.contains(i)      ? bet.oddsStrings[i]       : "—"
            let hit    = bet.winningPicks.contains(playerId)

            HStack(spacing: 10) {
                Image(systemName: hit ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(hit ? .green : .red)
                    .font(.system(size: 16, weight: .semibold))

                Text(name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundColor(hit ? .primary : .secondary)

                Spacer()

                Text(odds)
                    .font(.subheadline.bold())
                    .foregroundColor(hit ? .green : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(hit ? Color.green.opacity(0.07) : Color.red.opacity(0.04))

            if i < bet.picks.count - 1 {
                Divider().opacity(0.2).padding(.horizontal, 14)
            }
        }
    }

    // MARK: - Parlay Bonus

    @ViewBuilder
    private func parlayBonusRow(_ bet: VegasOddsBet) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
                .font(.system(size: 14))
            Text("Parlay Bonus")
                .font(.subheadline.bold())
                .foregroundColor(.yellow)
            Spacer()
            Text("+\(formattedDollars(parlayBonusProfit(bet)))")
                .font(.subheadline.bold())
                .foregroundColor(.yellow)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.yellow.opacity(0.09))
    }

    // MARK: - Summary

    @ViewBuilder
    private func summarySection(_ bet: VegasOddsBet) -> some View {
        VStack(spacing: 6) {
            row("Wager", value: "-$\(totalWager)", color: .secondary)
            row("Payout", value: formattedDollars(bet.payoutTotal), color: .secondary)
            Divider().opacity(0.25)
            HStack {
                Text("Net")
                    .font(.subheadline.bold())
                Spacer()
                Text(netText(bet.netProfit))
                    .font(.subheadline.bold())
                    .foregroundColor(bet.netProfit >= 0 ? .green : .red)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - No-bet placeholder

    private var noBetSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No picks selected")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("-$\(totalWager)")
                .font(.title3.bold())
                .foregroundColor(.red)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func row(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).foregroundColor(color)
            Spacer()
            Text(value).foregroundColor(color)
        }
        .font(.subheadline)
    }

    private func parlayBonusProfit(_ bet: VegasOddsBet) -> Double {
        let decs: [Double] = bet.oddsStrings.compactMap { s in
            let clean = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let a = Int(clean) ?? Int(clean.replacingOccurrences(of: "+", with: "")) else { return nil }
            return a >= 0 ? 1.0 + Double(a)/100.0 : 1.0 + 100.0/Double(-a)
        }
        guard decs.count == bet.picks.count, !decs.isEmpty else {
            // Fallback: infer from payoutTotal
            let straightCollect = bet.winningPicks.map { _ in Double(betPerPick) }.reduce(0, +) * 2 // rough
            return max(0, bet.payoutTotal - Double(totalWager))
        }
        let parlayCollect = Double(betPerPick) * decs.reduce(1.0, *)
        return max(0, parlayCollect - Double(betPerPick))
    }

    private func formattedDollars(_ amount: Double) -> String {
        String(format: "$%.0f", amount)
    }

    private func netText(_ net: Double) -> String {
        net >= 0 ? String(format: "+$%.0f", net) : String(format: "-$%.0f", abs(net))
    }
}

// MARK: - Sheet wrapper (used from Past Slips)

struct VegasOddsSettledSlipSheet: View {
    let bet: VegasOddsBet?
    let eventName: String
    let betPerPick: Int
    let playerName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text(playerName)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    VegasOddsSettledSlipView(
                        bet: bet,
                        eventName: eventName,
                        betPerPick: betPerPick
                    )
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Bet Slip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
