//
//  WorldCup2026LeaderboardView.swift
//  Best Man Challenge

import SwiftUI

struct WorldCup2026LeaderboardView: View {
    @ObservedObject var scoresStore: WorldCup2026ScoresStore
    let session: SessionStore

    @State private var showBreakdown: String? = nil   // scopedId of expanded row

    private var myLinkedId: String {
        session.profile?.linkedPlayerId ?? ""
    }

    var body: some View {
        List {
            if scoresStore.isLoading {
                Section {
                    ProgressView("Loading scores…")
                }
            } else if scoresStore.scores.isEmpty {
                Section {
                    Text("No scores yet. Scores update live as results are entered.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(header: Text("Standings")) {
                    ForEach(Array(scoresStore.playerRows.enumerated()), id: \.element.id) { idx, row in
                        VStack(spacing: 0) {
                            Button {
                                withAnimation {
                                    showBreakdown = showBreakdown == row.id ? nil : row.id
                                }
                            } label: {
                                HStack {
                                    // Rank
                                    Text("\(idx + 1)")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 28, alignment: .center)

                                    // Name
                                    Text(row.displayName)
                                        .fontWeight(row.linkedPlayerId == myLinkedId ? .bold : .regular)

                                    Spacer()

                                    // Phase badges
                                    if row.knockoutTotal > 0 {
                                        Text("+\(row.knockoutTotal) KO")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.orange)
                                            .clipShape(Capsule())
                                    }

                                    // Total
                                    Text("\(row.total) pts")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(row.total > 0 ? .primary : .secondary)

                                    Image(systemName: showBreakdown == row.id ? "chevron.up" : "chevron.down")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)

                            // Breakdown
                            if showBreakdown == row.id {
                                Divider().padding(.vertical, 4)

                                // Group stage grid
                                LazyVGrid(columns: [
                                    GridItem(.flexible()), GridItem(.flexible()),
                                    GridItem(.flexible()), GridItem(.flexible())
                                ], spacing: 6) {
                                    ForEach(WCGroup.allCases) { g in
                                        let pts = row.byGroup[g.rawValue] ?? 0
                                        VStack(spacing: 2) {
                                            Text("Grp \(g.rawValue)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text("\(pts > 0 ? "+" : "")\(pts)")
                                                .font(.caption.bold())
                                                .foregroundStyle(pointsColor(pts))
                                        }
                                        .padding(.vertical, 4)
                                        .frame(maxWidth: .infinity)
                                        .background(pointsColor(pts).opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }

                                // Knockout breakdown (only if any KO picks scored)
                                if !row.byRound.isEmpty {
                                    Divider().padding(.vertical, 4)
                                    HStack(spacing: 6) {
                                        ForEach(WCKORound.allCases) { round in
                                            let pts = row.byRound[round.rawValue] ?? 0
                                            VStack(spacing: 2) {
                                                Text(round.shortName)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                Text(pts > 0 ? "+\(pts)" : "—")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(pts > 0 ? Color.orange : Color.secondary)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 4)
                                            .background(pts > 0 ? Color.orange.opacity(0.1) : Color.clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        }
                                    }
                                }

                                HStack {
                                    Text("Groups: \(row.groupTotal) pts")
                                    Spacer()
                                    Text("Knockout: \(row.knockoutTotal) pts")
                                        .foregroundStyle(.orange)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                                .padding(.bottom, 6)
                            }
                        }
                    }
                }
            }

            // Scoring key
            Section {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Groups: +2 correct | +1 off by 1 | 0 off by 2 | -1 off by 3 (max 96 pts)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Knockout: R32 +2 | R16 +4 | QF +8 | SF +16 | Final +32 (max 160 pts)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Leaderboard")
    }

    private func pointsColor(_ pts: Int) -> Color {
        if pts > 0 { return .green }
        if pts < 0 { return .red }
        return .secondary
    }
}
