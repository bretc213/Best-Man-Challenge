//
//  PlayerLedgerView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/24/26.
//


import SwiftUI

struct PlayerLedgerView: View {
    let playerId: String
    let playerName: String

    @StateObject private var store = PlayerLedgerStore()

    private let challengeTitles: [String: String] = [
        "cfb_playoffs_2025": "CFB Playoffs 2025",
        "nfl_playoffs_2026_overall": "NFL Playoffs 2026 (Overall)"
    ]

    var body: some View {
        ThemedScreen {
            VStack(alignment: .leading, spacing: 12) {

                VStack(alignment: .leading, spacing: 4) {
                    Text(playerName)
                        .font(.title2.bold())
                    Text("Points Ledger")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if store.isLoading {
                    ProgressView("Loading ledger...")
                        .padding()
                }

                if let err = store.errorMessage {
                    Text("Couldn’t load ledger: \(err)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                List {
                    if store.awards.isEmpty && !store.isLoading {
                        Text("No finalized points yet.")
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                    } else {
                        Section {
                            ForEach(store.awards) { a in
                                ledgerRow(a)
                                    .listRowBackground(Color.clear)
                            }
                        } header: {
                            ledgerHeader()
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.background)
            }
        }
        .onAppear {
            store.startListening(playerId: playerId)
        }
        .onDisappear {
            store.stopListening()
        }
    }

    private func ledgerHeader() -> some View {
        HStack {
            Text("Challenge")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Pts")
                .frame(width: 50, alignment: .trailing)
            Text("Finalized")
                .frame(width: 110, alignment: .trailing)
        }
        .font(.caption.bold())
        .secondaryText()
    }

    private func ledgerRow(_ a: PointAward) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // ✅ Prefer note (weekly winner), else friendly title, else raw id
                Text(a.note ?? (challengeTitles[a.challengeId] ?? a.challengeId))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(formatPoints(a.points))
                    .frame(width: 50, alignment: .trailing)
                    .fontWeight(.semibold)

                Text(formatDate(a.createdAt))
                    .frame(width: 110, alignment: .trailing)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            HStack(spacing: 8) {
                Text("Base: \(formatPoints(a.basePoints))")
                Text("•").foregroundStyle(.secondary)
                Text("Bonus: \(formatPoints(a.bonusPoints))")

                if let m = a.multiplier {
                    Text("•").foregroundStyle(.secondary)
                    Text("×\(formatPoints(m))")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private func formatPoints(_ pts: Double) -> String {
        pts == floor(pts) ? String(Int(pts)) : String(format: "%.1f", pts)
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
    }
}
