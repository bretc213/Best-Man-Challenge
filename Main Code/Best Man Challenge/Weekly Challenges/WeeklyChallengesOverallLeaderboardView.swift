//
//  WeeklyChallengesOverallLeaderboardView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/7/26.
//


import SwiftUI

struct WeeklyChallengesOverallLeaderboardView: View {
    @ObservedObject var store: WeeklyChallengesOverallStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overall Weekly Leaderboard")
                .font(.title2.bold())

            if store.isLoading {
                ProgressView("Loading...")
            } else if let err = store.errorMessage {
                Text("Couldn’t load: \(err)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if store.rows.isEmpty {
                Text("No scores yet. They’ll appear after the first week is scored.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(Array(store.rows.enumerated()), id: \.element.id) { idx, row in
                        HStack {
                            Text("\(idx + 1)")
                                .frame(width: 26, alignment: .leading)

                            Text(row.displayName)
                            Spacer()

                            Text("\(row.totalPoints)")
                                .frame(width: 50, alignment: .trailing)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}
