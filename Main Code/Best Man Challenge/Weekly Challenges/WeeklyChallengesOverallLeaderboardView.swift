//
//  WeeklyChallengesOverallLeaderboardView.swift
//  Best Man Challenge
//

import SwiftUI

struct WeeklyChallengesOverallLeaderboardView: View {
    @ObservedObject var store: WeeklyOverallStore

    @State private var mode: WeeklyGroupMode = .players

    var body: some View {
        VStack(spacing: 0) {

            HStack {
                Text("Overall Weekly")
                    .font(.title2.bold())

                Spacer()

                Picker("", selection: $mode) {
                    ForEach(WeeklyGroupMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Button {
                    store.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .padding(.leading, 8)
                .accessibilityLabel("Refresh overall")
            }
            .padding(.horizontal)
            .padding(.top, 10)

            Divider().opacity(0.35)
                .padding(.top, 8)

            Group {
                if store.isLoading {
                    ProgressView("Calculating totals…")
                        .padding()

                } else if let err = store.errorMessage {
                    VStack(spacing: 10) {
                        Text("Couldn’t load overall leaderboard")
                            .font(.headline)
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try Again") { store.refresh() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()

                } else if rows.isEmpty {
                    Text("No scores yet. They’ll appear after the first week is scored.")
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

                                Text("\(row.score)")
                                    .fontWeight(.semibold)
                                    .frame(width: 60, alignment: .trailing)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { store.refresh() }
    }

    private var rows: [WeeklyScoreRow] {
        switch mode {
        case .players: return store.playersRows
        case .admins:  return store.adminsRows
        }
    }
}
