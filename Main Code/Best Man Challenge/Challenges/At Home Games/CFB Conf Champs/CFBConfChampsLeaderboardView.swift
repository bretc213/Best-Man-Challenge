//
//  CFBConfChampsLeaderboardView.swift
//  Best Man Challenge
//
//  In-game leaderboard: ranks raw scores (0…82). Ties shown as ties.
//  Final BMC points are awarded at Finalize via golf-payout tie logic + owner +3.
//

import SwiftUI

struct CFBConfChampsLeaderboardView: View {
    @ObservedObject var store: CFBConfChampsStore
    let session: SessionStore

    private var myId: String { session.profile?.linkedPlayerId ?? "" }

    var body: some View {
        List {
            Section {
                ForEach(Array(rankedRows.enumerated()), id: \.element.linkedPlayerId) { idx, row in
                    leaderRow(rank: rankFor(index: idx), row: row)
                        .listRowBackground(Color.clear)
                }
            } header: {
                headerRow
            } footer: {
                Text("Raw points shown (max 82). Final BMC points are awarded when the game is finalized, using golf-payout tie splitting plus a +3 bonus for anyone finishing above Bret.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .overlay {
            if store.scoreRows.isEmpty {
                ContentUnavailableView(
                    "No points yet",
                    systemImage: "list.number",
                    description: Text("Standings populate as conferences are graded.")
                )
            }
        }
    }

    private var rankedRows: [CFBScoreRow] { store.scoreRows }

    /// Standard competition ranking (ties share a rank).
    private func rankFor(index: Int) -> Int {
        let rows = rankedRows
        guard index > 0 else { return 1 }
        var rank = 1
        for i in 1...index {
            if rows[i].total != rows[i - 1].total { rank = i + 1 }
        }
        return rank
    }

    private var headerRow: some View {
        HStack {
            Text("#").frame(width: 28, alignment: .leading)
            Text("Player").frame(maxWidth: .infinity, alignment: .leading)
            Text("P1").frame(width: 34, alignment: .trailing)
            Text("P2").frame(width: 34, alignment: .trailing)
            Text("Total").frame(width: 46, alignment: .trailing)
        }
        .font(.caption.bold())
        .foregroundStyle(.secondary)
    }

    private func leaderRow(rank: Int, row: CFBScoreRow) -> some View {
        let isMe = row.linkedPlayerId == myId
        return HStack {
            Text("\(rank)")
                .frame(width: 28, alignment: .leading)
                .fontWeight(rank <= 3 ? .bold : .regular)
                .foregroundStyle(rank == 1 ? .yellow : .primary)

            HStack(spacing: 8) {
                Text(row.displayName)
                    .fontWeight(isMe ? .bold : .regular)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isMe {
                    Text("You").font(.caption2.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.2))
                        .foregroundStyle(Color.accentColor).clipShape(Capsule())
                }
            }

            Text(pointsString(row.phase1Points)).frame(width: 34, alignment: .trailing)
                .font(.subheadline).foregroundStyle(.secondary)
            Text(pointsString(row.phase2Points)).frame(width: 34, alignment: .trailing)
                .font(.subheadline).foregroundStyle(.secondary)
            Text(pointsString(row.total)).frame(width: 46, alignment: .trailing)
                .fontWeight(.bold)
        }
        .padding(.vertical, 6)
    }
}
