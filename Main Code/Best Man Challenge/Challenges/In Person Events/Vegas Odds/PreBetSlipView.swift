//
//  PreBetSlipView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 5/24/25.
//

import SwiftUI

struct PreBetSlipView: View {
    let challengeId: String
    let challengeTitle: String

    // For printing
    let playerDisplayNames: [String]

    // For Firestore write
    let playerIds: [String]

    let odds: [String]
    let betAmount: Int

    let cancelAction: () -> Void
    let onConfirmed: () -> Void

    // UI state
    @State private var isSubmitting = false
    @State private var showErrorAlert = false
    @State private var errorTitle = "Bet Failed"
    @State private var errorMessage = "Something went wrong."

    // MARK: - Odds helpers

    private func parseAmerican(_ odds: String) -> Int? {
        let s = odds.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        // supports "+200", "-120", "200"
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

    private var picksCount: Int { max(1, odds.count) }

    /// Straight bets: $300 total split across 3 picks => $100 each.
    private var perPickStake: Double {
        Double(betAmount) / Double(picksCount)
    }

    /// ✅ Parlay stake should be ONE pick cost ($100), not total wager.
    private var parlayStake: Double {
        perPickStake
    }

    // MARK: - Totals (Straight)

    private var straightToWin: Double {
        zip(playerDisplayNames, odds).reduce(0.0) { acc, pair in
            guard let a = parseAmerican(pair.1) else { return acc }
            return acc + straightProfit(stake: perPickStake, americanOdds: a)
        }
    }

    private var straightToCollect: Double {
        Double(betAmount) + straightToWin
    }

    // MARK: - Totals (Parlay using $100 stake)

    private var parlayToWin: Double {
        let decimals: [Double] = odds.compactMap { s in
            guard let a = parseAmerican(s) else { return nil }
            return decimalOdds(from: a)
        }
        guard decimals.count == odds.count, !decimals.isEmpty else { return 0 }

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

            Text("PREVIEW YOUR WAGER")
                .font(.system(.subheadline, design: .monospaced))
                .padding(.bottom, 5)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(playerDisplayNames.indices, id: \.self) { i in
                    Text("[\(challengeTitle)] \(playerDisplayNames[i])     \(odds.indices.contains(i) ? odds[i] : "")")
                        .font(.system(.body, design: .monospaced))
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                Text("TOTAL WAGER:   $\(betAmount)")
                Text("TO WIN:        $\(String(format: "%.0f", straightToWin))")
                Text("TO COLLECT:    $\(String(format: "%.0f", straightToCollect))")

                Text("PARLAY WIN:   $\(String(format: "%.0f", parlayToWin))")
                Text("TOTAL COLLECT:$\(String(format: "%.0f", totalCollectWithParlay))")
            }
            .font(.system(.body, design: .monospaced))
            .padding(.top, 5)

            Divider()

            Text("Printed: \(Date().formatted(date: .abbreviated, time: .shortened))")
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.bottom, 20)

            if isSubmitting {
                ProgressView("Confirming bet…")
                    .padding(.bottom, 4)
            }

            HStack(spacing: 16) {
                Button("Adjust Bet") {
                    cancelAction()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(isSubmitting)

                Button("Confirm Bet") {
                    confirmBet()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(isSubmitting)
            }
        }
        .padding()
        .alert(errorTitle, isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Actions

    private func confirmBet() {
        guard !isSubmitting else { return }
        isSubmitting = true

        BetService.confirmBet(
            challengeId: challengeId,
            challengeTitle: challengeTitle,
            selectedPlayerIds: playerIds,
            betAmount: betAmount,
            odds: odds
        ) { result in
            DispatchQueue.main.async {
                isSubmitting = false
                switch result {
                case .success:
                    onConfirmed()
                case .failure(let err):
                    let (title, msg) = friendlyError(err)
                    errorTitle = title
                    errorMessage = msg
                    showErrorAlert = true
                }
            }
        }
    }

    // MARK: - Friendly errors

    private func friendlyError(_ error: Error) -> (String, String) {
        let ns = error as NSError

        if ns.domain == "BetService" {
            return ("Bet Not Placed", ns.localizedDescription)
        }

        if ns.domain.contains("FIRFirestoreErrorDomain") || ns.domain.contains("FIRFirestore") {
            if ns.code == 7 {
                return ("Permission Denied",
                        "Firestore blocked this action. This is usually a rules/auth issue. If you’re in dev, temporarily relax rules or ensure you’re signed in.")
            }
        }

        let lower = ns.localizedDescription.lowercased()
        if lower.contains("network") || lower.contains("offline") || lower.contains("unavailable") {
            return ("Connection Problem",
                    "Couldn’t reach the server. Check your internet and try again.")
        }

        return ("Bet Failed", ns.localizedDescription)
    }
}
