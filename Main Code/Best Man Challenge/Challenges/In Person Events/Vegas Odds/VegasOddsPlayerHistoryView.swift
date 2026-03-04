//
//  VegasOddsPlayerHistoryView.swift
//  Best Man Challenge
//

import SwiftUI

struct VegasOddsPlayerHistoryView: View {
    let bettorId: String
    let bettorName: String

    @StateObject private var eventsStore = VegasOddsEventsStore()
    @StateObject private var historyStore = VegasOddsHistoryStore()

    @State private var selectedEventId: String? = nil

    private var finalizedEvents: [VegasOddsEvent] {
        eventsStore.events.filter { $0.status == "finalized" }
    }

    private var selectedBet: VegasOddsBet? {
        guard let id = selectedEventId else { return nil }
        return historyStore.betsByEventId[id]
    }

    var body: some View {
        VStack(spacing: 12) {
            header

            if finalizedEvents.isEmpty {
                Text("No completed events yet.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
            } else {
                Picker("Event", selection: Binding(
                    get: { selectedEventId ?? finalizedEvents.first?.id },
                    set: { selectedEventId = $0 }
                )) {
                    ForEach(finalizedEvents, id: \.id) { e in
                        Text(e.name).tag(Optional(e.id))
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(.horizontal)

                if let bet = selectedBet {
                    betSlipSection(bet)
                } else {
                    Text("No bet slip found for this event.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)
                }
            }

            Spacer()
        }
        .navigationTitle(bettorName)
        .onAppear {
            eventsStore.startListening()
            historyStore.startListening(bettorId: bettorId)
        }
        .onChange(of: eventsStore.events) { _ in
            if selectedEventId == nil {
                selectedEventId = finalizedEvents.first?.id
            }
        }
        .onDisappear {
            eventsStore.stopListening()
            historyStore.stopListening()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bet Slip History")
                .font(.headline)

            if let msg = historyStore.errorMessage {
                Text("Error: \(msg)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 6)
    }

    @ViewBuilder
    private func betSlipSection(_ bet: VegasOddsBet) -> some View {
        // Build a BetSlip for your existing ticket renderer.
        let slip = BetSlip(
            challenge: bet.eventName,
            selectedPlayers: bet.pickDisplayNames,
            odds: bet.oddsStrings,
            betAmount: bet.betPerPick * bet.maxPicks,
            toWin: Int(max(0, bet.payoutTotal - Double(bet.betPerPick * bet.maxPicks))),
            timestamp: bet.createdAt ?? Date()
        )

        VStack(spacing: 10) {
            BetSlipView(slip: slip)
                .padding(.horizontal)

            if bet.isSettled {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Settled")
                        .font(.headline)

                    Text("Effective Top 3 (self-excluded): \(bet.effectiveTop3.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Winning picks: \(bet.winningPicks.isEmpty ? "None" : bet.winningPicks.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(String(format: "Payout: $%.2f • Net: $%.2f", bet.payoutTotal, bet.netProfit))
                        .font(.subheadline.bold())

                    if bet.parlayHit {
                        Text("Parlay bonus hit ✅")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.12))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                Text("This bet hasn’t been settled yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }
}
