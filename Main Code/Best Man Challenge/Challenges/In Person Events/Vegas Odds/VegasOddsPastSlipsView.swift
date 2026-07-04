//
//  VegasOddsPastSlipsView.swift
//  Best Man Challenge
//
//  Past Slips tab: list of finalized events → player results → settled bet slip.
//

import SwiftUI

// MARK: - Event list

struct VegasOddsPastSlipsView: View {
    @StateObject private var eventsStore = VegasOddsEventsStore()

    private var finalizedEvents: [VegasOddsEvent] {
        eventsStore.events.filter { $0.status == "finalized" }
    }

    var body: some View {
        List {
            if finalizedEvents.isEmpty {
                if eventsStore.events.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading…").foregroundColor(.secondary)
                    }
                } else {
                    Text("No finalized events yet.")
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(finalizedEvents) { event in
                    NavigationLink {
                        VegasOddsPastEventDetailView(event: event)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.name)
                                .font(.subheadline.bold())
                            if let date = event.startsAt {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Past Slips")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { eventsStore.startListening() }
    }
}

// MARK: - Per-event player results

struct VegasOddsPastEventDetailView: View {
    let event: VegasOddsEvent

    @StateObject private var allBetsStore = VegasOddsAllBetsForEventStore()
    @StateObject private var playersStore = PlayersStore()

    @State private var sheetPlayer: FirestorePlayer? = nil
    @State private var sheetBet: VegasOddsBet? = nil

    var body: some View {
        List {
            if allBetsStore.isLoading || playersStore.players.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading…").foregroundColor(.secondary)
                }
            } else {
                Section("Player Results") {
                    ForEach(rankedPlayers) { player in
                        let bet = betFor(player)
                        let net = netFor(player)

                        Button {
                            sheetPlayer = player
                            sheetBet = bet
                        } label: {
                            HStack {
                                Text(player.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(netText(net))
                                    .font(.subheadline.bold())
                                    .foregroundColor(net >= 0 ? .green : .red)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { sheetPlayer != nil },
            set: { if !$0 { sheetPlayer = nil; sheetBet = nil } }
        )) {
            if let player = sheetPlayer {
                VegasOddsSettledSlipSheet(
                    bet: sheetBet,
                    eventName: event.name,
                    betPerPick: event.betPerPick,
                    playerName: player.displayName
                )
            }
        }
        .onAppear {
            allBetsStore.startListening(eventId: event.id)
            playersStore.startListening()
        }
    }

    // MARK: - Helpers

    private var rankedPlayers: [FirestorePlayer] {
        playersStore.players.sorted { netFor($0) > netFor($1) }
    }

    private func betFor(_ player: FirestorePlayer) -> VegasOddsBet? {
        allBetsStore.bets.first { $0.bettorPlayerId == player.id }
    }

    private func netFor(_ player: FirestorePlayer) -> Double {
        betFor(player)?.netProfit ?? -300
    }

    private func netText(_ v: Double) -> String {
        v >= 0 ? String(format: "+$%.0f", v) : String(format: "-$%.0f", abs(v))
    }
}
