//
//  WeeklyChallengeStandingsOnlyView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/8/26.
//


import SwiftUI

struct WeeklyChallengeStandingsOnlyView: View {
    @EnvironmentObject var manager: WeeklyChallengeManager
    @StateObject private var store = WeeklyChallengeStandingsStore()

    @State private var mode: WeeklyGroupMode = .players

    var body: some View {
        VStack(spacing: 0) {

            HStack {
                Text("This Week")
                    .font(.headline)

                Spacer()

                Picker("", selection: $mode) {
                    ForEach(WeeklyGroupMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
            .padding(.horizontal)
            .padding(.top, 10)

            Divider().opacity(0.35)
                .padding(.top, 8)

            if store.isLoading {
                ProgressView("Loading standings…")
                    .padding()

            } else if let err = store.errorMessage {
                Text("Couldn’t load: \(err)")
                    .foregroundStyle(.secondary)
                    .padding()

            } else if rows.isEmpty {
                Text("No submissions yet.")
                    .foregroundStyle(.secondary)
                    .padding()

            } else {
                List {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                        HStack {
                            Text("\(idx + 1)")
                                .frame(width: 28, alignment: .leading)
                                .foregroundStyle(.secondary)

                            Text(row.displayName)
                                .fontWeight(.semibold)

                            Spacer()

                            if let max = row.maxScore, max > 0 {
                                Text("\(row.score)/\(max)")
                                    .fontWeight(.semibold)
                            } else {
                                Text("\(row.score)")
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.plain)
            }
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

    private func startIfPossible() {
        guard let cid = manager.currentChallenge?.id, !cid.isEmpty else { return }
        store.startListening(activeChallengeId: cid)
    }
}
