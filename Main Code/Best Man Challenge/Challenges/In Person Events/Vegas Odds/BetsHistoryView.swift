//
//  BetsHistoryView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 12/23/25.
//


import SwiftUI

struct BetsHistoryView: View {
    @ObservedObject var playersStore: PlayersStore
    @StateObject private var store = BetsHistoryStore()

    private func name(for playerId: String) -> String {
        playersStore.players.first(where: { $0.id == playerId })?.displayName ?? playerId
    }

    var body: some View {
        NavigationView {
            List {
                if let msg = store.errorMessage {
                    Text("Couldn’t load bets: \(msg)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForEach(store.bets) { bet in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(bet.challengeTitle)
                                .font(.headline)
                            Spacer()
                            Text("$\(bet.betAmount)")
                                .bold()
                        }

                        ForEach(Array(zip(bet.selectedPlayerIds, bet.odds)).indices, id: \.self) { i in
                            let pid = bet.selectedPlayerIds[i]
                            let odd = bet.odds.indices.contains(i) ? bet.odds[i] : ""
                            Text("\(name(for: pid))  \(odd)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let date = bet.createdAt {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("My Bets")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { /* sheet dismiss handled by system */ }
                }
            }
        }
        .onAppear {
            store.startListening()
        }
    }
}
