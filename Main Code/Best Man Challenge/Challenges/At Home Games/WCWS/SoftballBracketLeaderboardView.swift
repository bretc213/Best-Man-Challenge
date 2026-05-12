//
//  SoftballBracketLeaderboardView.swift
//  Best Man Challenge
//

import SwiftUI

struct SoftballBracketLeaderboardView: View {
    @ObservedObject var store: SoftballBracketStore

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.config.title)
                            .font(.headline)
                        Text("Leaderboard updates from official admin results.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(store.config.status.capitalized)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.14))
                        .clipShape(Capsule())
                }
            }

            Section("Standings") {
                let rows = store.leaderboardRows()
                if rows.isEmpty {
                    Text("No submitted picks yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("#\(index + 1)")
                                    .font(.headline)
                                    .frame(width: 36, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.displayName)
                                        .font(.headline)
                                    Text("Max: \(row.maxRemaining)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(row.total)")
                                    .font(.title3.bold())
                            }

                            HStack(spacing: 10) {
                                scorePill("Reg", row.regionalPoints)
                                scorePill("Supers", row.superRegionalPoints)
                                scorePill("Final", row.finalistPoints)
                                scorePill("Champ", row.championPoints)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Softball Standings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scorePill(_ label: String, _ value: Int) -> some View {
        Text("\(label): \(value)")
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Capsule())
    }
}
