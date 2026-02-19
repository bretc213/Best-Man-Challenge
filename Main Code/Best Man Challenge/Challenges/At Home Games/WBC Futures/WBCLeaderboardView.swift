//
//  WBCLeaderboardView.swift
//  Best Man Challenge
//

import SwiftUI

struct WBCLeaderboardView: View {
    @ObservedObject var scoresStore: WBC2026ScoresStore
    let session: SessionStore

    @State private var group: WBC2026ScoresStore.Group = .players

    var body: some View {
        List {
            Section {
                Picker("", selection: $group) {
                    ForEach(WBC2026ScoresStore.Group.allCases) { g in
                        Text(g.rawValue.capitalized).tag(g)
                    }
                }
                .pickerStyle(.segmented)
            }

            let rows = scoresStore.scores.filter { scoresStore.groupForPlayerId($0.id) == group }
            if rows.isEmpty {
                Section {
                    Text("No scores yet.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(header: Text("Standings")) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { idx, r in
                        HStack {
                            Text("\(idx + 1)")
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .leading)
                            Text(r.displayName)
                            Spacer()
                            Text("\(r.score)")
                                .fontWeight(.bold)
                        }
                    }
                }
            }
        }
        .navigationTitle("Standings")
    }
}
