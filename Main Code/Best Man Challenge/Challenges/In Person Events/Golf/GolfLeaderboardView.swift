//
//  GolfLeaderboardView.swift
//  Best Man Challenge
//

import SwiftUI

struct GolfLeaderboardView: View {
    @ObservedObject var store: GolfEventStore
    var isOwner: Bool = false

    enum Board: String {
        case overall = "Overall"
        case sim     = "Sim"
        case duos    = "Duos"
        case admin   = "Admin"
    }

    @State private var selected: Board = .overall

    private var visibleBoards: [Board] {
        isOwner ? [.overall, .sim, .duos, .admin] : [.overall, .sim, .duos]
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selected) {
                ForEach(visibleBoards, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            switch selected {
            case .overall: overallBoard
            case .sim:     simBoard
            case .duos:    duosBoard
            case .admin:   GolfAdminView(store: store)
            }
        }
    }

    // MARK: - Overall

    private var overallBoard: some View {
        let entries = store.overallLeaderboard
        return Group {
            if entries.isEmpty {
                empty("Scores not entered yet.")
            } else {
                List {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { _, entry in
                        overallRow(entry)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.background)
            }
        }
    }

    @ViewBuilder
    private func overallRow(_ e: GolfOverallEntry) -> some View {
        HStack(spacing: 12) {
            rankBadge(e.overallRankIndex.map { $0 + 1 })

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(e.displayName).font(.headline)
                    if e.isBret {
                        Text("HOST").font(.caption2.bold())
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.accent.opacity(0.2))
                            .cornerRadius(4)
                            .foregroundStyle(Color.accent)
                    }
                }
                Text("Sim \(formatted(e.simPoints)) · Duos \(formatted(e.scramblePoints))")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatted(e.totalPoints))
                    .font(.headline).foregroundStyle(Color.textPrimary)
                if !e.isBret {
                    HStack(spacing: 4) {
                        Text("\(formatted(e.totalBMC)) BMC")
                            .font(.caption).foregroundStyle(.secondary)
                        if e.bretBonus > 0 {
                            Text("+3🔥").font(.caption)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: - Sim

    private var simBoard: some View {
        let entries = store.simLeaderboard
        return Group {
            if entries.isEmpty {
                empty("Simulator scores not entered yet.")
            } else {
                List {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { _, entry in
                        simRow(entry)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.background)
            }
        }
    }

    @ViewBuilder
    private func simRow(_ e: GolfSimEntry) -> some View {
        HStack(spacing: 12) {
            rankBadge(e.rankIndex.map { $0 + 1 })

            Text(e.displayName).font(.headline)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let score = e.score {
                    Text(scoreLabel(score))
                        .font(.subheadline.bold())
                        .foregroundStyle(score < 0 ? .green : score > 0 ? .red : Color.textPrimary)
                }
                Text(formatted(e.inGamePoints) + " pts")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: - Duos

    private var duosBoard: some View {
        let teams = store.duosLeaderboard
        return Group {
            if teams.isEmpty {
                empty("Teams not generated yet.")
            } else {
                List {
                    ForEach(Array(teams.enumerated()), id: \.element.id) { _, team in
                        duosRow(team)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.background)
            }
        }
    }

    @ViewBuilder
    private func duosRow(_ t: GolfTeamResult) -> some View {
        HStack(spacing: 12) {
            rankBadge(t.rankIndex.map { $0 + 1 })

            VStack(alignment: .leading, spacing: 2) {
                Text("\(t.assignment.playerAName) & \(t.assignment.playerBName)")
                    .font(.headline)
                Text("\(formatted(t.pointsPerPlayer)) pts each")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if let score = t.scrambleScore {
                Text(scoreLabel(score))
                    .font(.subheadline.bold())
                    .foregroundStyle(score < 0 ? .green : score > 0 ? .red : Color.textPrimary)
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func rankBadge(_ rank: Int?) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 32, height: 32)
            Text(rank.map { "\($0)" } ?? "—")
                .font(.caption.bold())
                .foregroundStyle(Color.textPrimary)
        }
    }

    @ViewBuilder
    private func empty(_ msg: String) -> some View {
        Text(msg)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }

    private func scoreLabel(_ score: Int) -> String {
        if score == 0 { return "E" }
        return score > 0 ? "+\(score)" : "\(score)"
    }

    private func formatted(_ d: Double) -> String {
        d == floor(d) ? "\(Int(d))" : String(format: "%.1f", d)
    }
}
