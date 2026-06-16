//
//  NFLPickEmLeaderboardView.swift
//  Best Man Challenge
//

import SwiftUI

struct NFLPickEmLeaderboardView: View {
    @ObservedObject var store: NFLPickEmStore
    let session: SessionStore

    @State private var selectedView: LeaderboardSegment = .overall

    enum LeaderboardSegment: String, CaseIterable {
        case overall = "Overall"
        case weekly  = "Weekly"
    }

    private var myLinkedId: String {
        session.profile?.linkedPlayerId ?? ""
    }

    // Ranked overall rows (sorted by total correct)
    private var rankedRows: [(row: NFLPickEmScoreRow, rank: Int)] {
        let sorted = store.scoreRows.sorted {
            if $0.totalCorrect != $1.totalCorrect { return $0.totalCorrect > $1.totalCorrect }
            return $0.displayName < $1.displayName
        }

        var result: [(row: NFLPickEmScoreRow, rank: Int)] = []
        var rank = 1
        for (idx, row) in sorted.enumerated() {
            if idx > 0 && sorted[idx - 1].totalCorrect > row.totalCorrect {
                rank = idx + 1
            }
            result.append((row, rank))
        }
        return result
    }

    private var completedWeeks: [Int] {
        store.availableWeeks.filter { week in
            let weekGames = store.games(for: week)
            return !weekGames.isEmpty && weekGames.allSatisfy { $0.isFinal }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedView) {
                ForEach(LeaderboardSegment.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if store.isLoading {
                Spacer()
                ProgressView("Loading leaderboard…")
                Spacer()
            } else {
                switch selectedView {
                case .overall:
                    overallView
                case .weekly:
                    weeklyView
                }
            }
        }
    }

    // MARK: - Overall Leaderboard

    private var overallView: some View {
        ScrollView {
            VStack(spacing: 10) {
                overallHeader

                ForEach(rankedRows, id: \.row.id) { entry in
                    OverallRow(
                        rank: entry.rank,
                        row: entry.row,
                        isMe: entry.row.linkedPlayerId == myLinkedId,
                        weekWins: entry.row.weekWins.count
                    )
                }

                if rankedRows.isEmpty {
                    Text("No picks yet — check back once Week 1 kicks off.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                }

                totalGamesNote
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }

    private var overallHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Overall Standings")
                    .font(.title3.bold())
                Text("Weeks 1–16 · 1 pt per correct pick")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var totalGamesNote: some View {
        let finalCount = store.games.filter { $0.isFinal }.count
        let totalCount = store.games.count
        return Text("\(finalCount) of \(totalCount) games decided")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }

    // MARK: - Weekly Breakdown

    private var weeklyView: some View {
        ScrollView {
            VStack(spacing: 16) {
                weeklyHeader

                if completedWeeks.isEmpty {
                    Text("Weekly results will appear once games are finalized.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                } else {
                    ForEach(completedWeeks.sorted(by: >), id: \.self) { week in
                        WeeklyBreakdownCard(
                            week: week,
                            store: store,
                            myLinkedId: myLinkedId
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }

    private var weeklyHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Weekly Results")
                    .font(.title3.bold())
                Text("Winners earn +1 BMC bonus point")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Overall Row

private struct OverallRow: View {
    let rank: Int
    let row: NFLPickEmScoreRow
    let isMe: Bool
    let weekWins: Int

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(rank)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(rank == 1 ? .yellow : .secondary)
                .frame(width: 32, alignment: .leading)

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(row.displayName)
                    .font(.subheadline)
                    .fontWeight(isMe ? .bold : .regular)

                if weekWins > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "trophy.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text("\(weekWins) week win\(weekWins == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Score
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(row.totalCorrect)")
                    .font(.title3.monospacedDigit().bold())
                Text("correct")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            isMe
            ? Color.accentColor.opacity(0.08)
            : Color(UIColor.secondarySystemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isMe ? Color.accentColor.opacity(0.3) : .clear, lineWidth: 1)
        )
    }
}

// MARK: - Weekly Breakdown Card

private struct WeeklyBreakdownCard: View {
    let week: Int
    @ObservedObject var store: NFLPickEmStore
    let myLinkedId: String

    private var weekGames: [NFLPickEmGame] {
        store.games(for: week).filter { $0.isFinal }
    }

    private struct PlayerWeekResult: Identifiable {
        let id: String
        let displayName: String
        let correct: Int
        let isWinner: Bool
        let isMe: Bool
    }

    private var results: [PlayerWeekResult] {
        let maxCorrect = store.allEntries.map { entry in
            weekGames.filter { g in
                guard let w = g.winnerId else { return false }
                return entry.picks[g.id] == w
            }.count
        }.max() ?? 0

        return store.allEntries.map { entry in
            let correct = weekGames.filter { g in
                guard let w = g.winnerId else { return false }
                return entry.picks[g.id] == w
            }.count
            return PlayerWeekResult(
                id: entry.linkedPlayerId,
                displayName: entry.displayName,
                correct: correct,
                isWinner: correct == maxCorrect && correct > 0,
                isMe: entry.linkedPlayerId == myLinkedId
            )
        }
        .sorted {
            if $0.correct != $1.correct { return $0.correct > $1.correct }
            return $0.displayName < $1.displayName
        }
    }

    private var bonusApplied: Bool {
        store.appliedWeekBonuses.contains(week)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Week \(week)")
                    .font(.headline)

                Spacer()

                if bonusApplied {
                    Label("BMC Bonus Applied", systemImage: "star.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.yellow)
                } else {
                    Text("\(weekGames.count) games")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            ForEach(results) { result in
                HStack {
                    if result.isWinner {
                        Image(systemName: "trophy.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .frame(width: 18)
                    } else {
                        Image(systemName: "circle")
                            .font(.caption)
                            .foregroundStyle(.clear)
                            .frame(width: 18)
                    }

                    Text(result.displayName)
                        .font(.subheadline)
                        .fontWeight(result.isMe ? .bold : .regular)

                    Spacer()

                    Text("\(result.correct)/\(weekGames.count)")
                        .font(.subheadline.monospacedDigit())
                        .fontWeight(result.isMe ? .bold : .regular)
                        .foregroundStyle(result.isWinner ? .primary : .secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
