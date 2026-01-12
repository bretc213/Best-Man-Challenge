//
//  WeeklyChallengeStandingsView.swift
//  Best Man Challenge
//

import SwiftUI

struct WeeklyChallengeStandingsView: View {
    @ObservedObject var store: WeeklyChallengeStandingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This Week Standings")
                .font(.headline)

            if store.isLoading {
                ProgressView()
                    .padding(.top, 6)

            } else if let err = store.errorMessage {
                Text("Couldn’t load standings: \(err)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

            } else if store.rows.isEmpty {
                Text("No players found.")
                    .foregroundStyle(.secondary)

            } else {
                VStack(spacing: 8) {
                    ForEach(Array(store.rows.enumerated()), id: \.element.id) { idx, row in
                        HStack {
                            Text("\(idx + 1)")
                                .frame(width: 24, alignment: .leading)
                                .foregroundStyle(.secondary)

                            Text(row.displayName)
                                .fontWeight(.semibold)
                                .opacity(row.hasSubmitted ? 1.0 : 0.65)

                            Spacer()

                            if row.maxScore > 0 {
                                Text("\(row.score)/\(row.maxScore)")
                                    .foregroundStyle(.secondary)
                                    .opacity(row.hasSubmitted ? 1.0 : 0.65)
                            } else {
                                Text("\(row.score)")
                                    .foregroundStyle(.secondary)
                                    .opacity(row.hasSubmitted ? 1.0 : 0.65)
                            }
                        }
                        .padding(.vertical, 6)

                        if idx != store.rows.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.top, 4)
                .padding(12)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}
