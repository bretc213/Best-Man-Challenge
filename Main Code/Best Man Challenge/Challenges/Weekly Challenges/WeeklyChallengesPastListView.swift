//
//  WeeklyChallengesPastListView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/7/26.
//

import SwiftUI

struct WeeklyChallengesPastListView: View {
    @ObservedObject var store: WeeklyChallengesHistoryStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Past Challenges")
                .font(.title2.bold())

            if store.isLoading {
                ProgressView("Loading...")
                    .padding(.top, 8)

            } else if let err = store.errorMessage {
                Text("Couldn’t load: \(err)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

            } else if store.pastChallenges.isEmpty {
                Text("No past challenges yet.")
                    .foregroundStyle(.secondary)

            } else {
                List(store.pastChallenges, id: \.id) { ch in
                    NavigationLink {
                        WeeklyChallengePastDetailView(challenge: ch)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ch.title)
                                .font(.headline)

                            Text("Week \(ch.week)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
            }
        }
        .padding(.top, 8)
    }
}
