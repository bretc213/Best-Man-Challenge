//
//  VegasOddsLeaderboardTab.swift
//  Best Man Challenge
//
//  Player standings list + per-player event-by-event ledger sheet.
//

import SwiftUI

// MARK: - Standings list

struct VegasOddsLeaderboardTab: View {
    @StateObject private var leaderboardStore = VegasOddsLeaderboardStore()
    @State private var selectedPlayer: VegasWinningsRow? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if leaderboardStore.rows.isEmpty {
                    ProgressView("Loading standings…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    ForEach(Array(leaderboardStore.rows.enumerated()), id: \.element.id) { i, row in
                        Button { selectedPlayer = row } label: {
                            HStack(spacing: 12) {
                                Text("\(i + 1)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, alignment: .center)

                                Text(row.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Spacer()

                                Text(netText(row.vegasWinnings))
                                    .font(.subheadline.bold())
                                    .foregroundColor(row.vegasWinnings >= 0 ? .green : .red)

                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)

                        if i < leaderboardStore.rows.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
            .background(Color.gray.opacity(0.08))
            .cornerRadius(12)
            .padding()
        }
        .navigationTitle("Standings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { leaderboardStore.startListening() }
        .sheet(item: $selectedPlayer) { player in
            VegasOddsPlayerLedgerSheet(playerId: player.id, playerName: player.displayName)
        }
    }

    private func netText(_ v: Double) -> String {
        v >= 0 ? String(format: "+$%.0f", v) : String(format: "-$%.0f", abs(v))
    }
}

// MARK: - Player ledger sheet

struct VegasOddsPlayerLedgerSheet: View {
    let playerId: String
    let playerName: String

    @StateObject private var historyStore = VegasOddsHistoryStore()
    @StateObject private var eventsStore  = VegasOddsEventsStore()
    @Environment(\.dismiss) private var dismiss

    private var finalizedEvents: [VegasOddsEvent] {
        eventsStore.events.filter { $0.status == "finalized" }
    }

    private var totalNet: Double {
        finalizedEvents.reduce(0.0) { sum, event in
            if let bet = historyStore.betsByEventId[event.id] {
                return sum + bet.netProfit
            }
            return sum - 300
        }
    }

    var body: some View {
        NavigationView {
            List {
                if finalizedEvents.isEmpty {
                    Section {
                        Text("No finalized events yet.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section("Event History") {
                        ForEach(finalizedEvents) { event in
                            let bet = historyStore.betsByEventId[event.id]
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.name)
                                        .font(.subheadline)
                                    Text(bet == nil ? "No picks placed" : "Settled")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if let bet {
                                    Text(netText(bet.netProfit))
                                        .font(.subheadline.bold())
                                        .foregroundColor(bet.netProfit >= 0 ? .green : .red)
                                } else {
                                    Text("-$300")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    Section {
                        HStack {
                            Text("Total").font(.headline)
                            Spacer()
                            Text(netText(totalNet))
                                .font(.headline)
                                .foregroundColor(totalNet >= 0 ? .green : .red)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(playerName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            eventsStore.startListening()
            historyStore.startListening(bettorId: playerId)
        }
    }

    private func netText(_ v: Double) -> String {
        v >= 0 ? String(format: "+$%.0f", v) : String(format: "-$%.0f", abs(v))
    }
}
