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

    // MARK: - Odds Calculation
    private func winnings(for bet: Int, with odds: String) -> Double {
        let value = Double(
            odds.replacingOccurrences(of: "+", with: "")
                .replacingOccurrences(of: "-", with: "")
        ) ?? 0

        if odds.contains("+") {
            return (Double(bet) * value / 100).rounded()
        } else {
            return (Double(bet) / value * 100).rounded()
        }
    }

    private var totalToWin: Double {
        let perPick = max(1, betAmount / max(1, playerDisplayNames.count))

        // ✅ FIX: Use a named tuple parameter instead of mixing `_` and `$0`
        return zip(playerDisplayNames, odds)
            .map { pair in
                let oddsString = pair.1
                return winnings(for: perPick, with: oddsString)
            }
            .reduce(0, +)
    }

    private var totalToCollect: Double {
        Double(betAmount) + totalToWin
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
                Text("TO WIN:        $\(String(format: "%.2f", totalToWin))")
                Text("TO COLLECT:    $\(String(format: "%.2f", totalToCollect))")
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

        // Your own custom errors (recommended)
        if ns.domain == "BetService" {
            return ("Bet Not Placed", ns.localizedDescription)
        }

        // Firestore permission issues
        if ns.domain.contains("FIRFirestoreErrorDomain") || ns.domain.contains("FIRFirestore") {
            if ns.code == 7 { // permission denied
                return ("Permission Denied",
                        "Firestore blocked this action. This is usually a rules/auth issue. If you’re in dev, temporarily relax rules or ensure you’re signed in.")
            }
        }

        // Network-ish hints
        let lower = ns.localizedDescription.lowercased()
        if lower.contains("network") || lower.contains("offline") || lower.contains("unavailable") {
            return ("Connection Problem",
                    "Couldn’t reach the server. Check your internet and try again.")
        }

        // Fallback
        return ("Bet Failed", ns.localizedDescription)
    }
}
