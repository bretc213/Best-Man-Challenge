//
//  WeeklyChallengeStandingsView.swift
//  Best Man Challenge
//

import SwiftUI

struct WeeklyChallengeStandingsView: View {
    @EnvironmentObject var manager: WeeklyChallengeManager
    @StateObject private var store = WeeklyStandingsStore()

    @State private var mode: WeeklyGroupMode = .players

    var body: some View {
        VStack(spacing: 0) {

            // Header + toggle
            HStack {
                Text("This Week")
                    .font(.title2.bold())

                Spacer()

                Picker("", selection: $mode) {
                    ForEach(WeeklyGroupMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Button { startIfPossible() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .padding(.leading, 8)
                .accessibilityLabel("Refresh standings")
            }
            .padding(.horizontal)
            .padding(.top, 10)

            Divider().opacity(0.35)
                .padding(.top, 8)

            Group {
                if store.isLoading {
                    ProgressView("Loading standings…")
                        .padding()

                } else if let err = store.errorMessage {
                    VStack(spacing: 10) {
                        Text("Couldn’t load standings")
                            .font(.headline)
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try Again") { startIfPossible() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()

                } else if rows.isEmpty {
                    Text("No submissions yet.")
                        .foregroundStyle(.secondary)
                        .padding()

                } else {
                    List {
                        ForEach(Array(rankedRows.enumerated()), id: \.element.id) { idx, row in
                            HStack {
                                Text("\(idx + 1)")
                                    .frame(width: 28, alignment: .leading)
                                    .foregroundStyle(.secondary)

                                Text(row.displayName)
                                    .fontWeight(.semibold)

                                Spacer()

                                // ✅ Prefer "scorable" display if we can compute it
                                if let scorable = scorableDisplay(for: row), scorable.max > 0 {
                                    Text("\(scorable.score) pts")
                                        .fontWeight(.semibold)
                                } else {
                                    Text("\(row.score) pts")
                                        .fontWeight(.semibold)
                                }

                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { startIfPossible() }
        .onChange(of: manager.currentChallenge?.id ?? "") { _, _ in startIfPossible() }
        .onDisappear { store.stopListening() }
    }

    private var rows: [WeeklyScoreRow] {
        switch mode {
        case .players: return store.playersRows
        case .admins:  return store.adminsRows
        }
    }
    
    private var rankedRows: [WeeklyScoreRow] {
        rows.sorted {
            let a = scorableDisplay(for: $0)?.score ?? $0.score
            let b = scorableDisplay(for: $1)?.score ?? $1.score
            if a != b { return a > b }
            return $0.displayName < $1.displayName
        }
    }


    // MARK: - ✅ Scorable score/max (only counts questions with correct_index != nil)

    private func scorableDisplay(for row: WeeklyScoreRow) -> (score: Int, max: Int)? {
        guard
            let answers = row.answers,
            let questions = manager.currentChallenge?.quiz?.questions,
            !questions.isEmpty
        else { return nil }

        let pointsPerCorrect = manager.currentChallenge?.quiz?.points_per_correct ?? 1
        let scorableQuestions = questions.filter { $0.correct_index != nil }
        let scorableMax = scorableQuestions.count * pointsPerCorrect

        let scorableScore: Int = scorableQuestions.reduce(0) { partial, q in
            guard let correct = q.correct_index else { return partial }
            let picked = answers[q.id]
            return partial + ((picked == correct) ? pointsPerCorrect : 0)
        }

        return (scorableScore, scorableMax)
    }

    private func startIfPossible() {
        guard let cid = manager.currentChallenge?.id, !cid.isEmpty else { return }
        store.startListening(activeChallengeId: cid)
    }
}
