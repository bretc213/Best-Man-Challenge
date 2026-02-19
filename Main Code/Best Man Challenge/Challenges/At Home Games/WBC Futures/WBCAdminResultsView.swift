//
//  WBCAdminResultsView.swift
//  Best Man Challenge
//

import SwiftUI

struct WBCAdminResultsView: View {
    @ObservedObject var picksStore: WBC2026PicksStore
    @ObservedObject var resultsStore: WBC2026ResultsStore

    var body: some View {
        List {
            Section {
                Text("Set results here and the leaderboard will update live.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Pools
            ForEach(WBCPool.allCases) { pool in
                Section(header: Text("Pool \(pool.rawValue) Results")) {
                    AdminPoolResultPicker(
                        title: "Winner (1)",
                        options: (picksStore.teamsByPool[pool] ?? []),
                        selectedId: resultsStore.results.poolResults[pool.rawValue]?["seed1"],
                        placeholder: "Pick",
                        label: { $0.abbr }
                    ) { teamId in
                        Task { try? await resultsStore.setPoolResult(pool: pool, seed: "seed1", teamId: teamId) }
                    }

                    AdminPoolResultPicker(
                        title: "Runner-up (2)",
                        options: (picksStore.teamsByPool[pool] ?? []),
                        selectedId: resultsStore.results.poolResults[pool.rawValue]?["seed2"],
                        placeholder: "Pick",
                        label: { $0.abbr }
                    ) { teamId in
                        Task { try? await resultsStore.setPoolResult(pool: pool, seed: "seed2", teamId: teamId) }
                    }
                }
            }

            // Final Four (unordered)
            Section(header: Text("Final Four")) {
                Text("Order does not matter. Pick the 4 teams that advanced to the semifinals.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(0..<4, id: \.self) { idx in
                    AdminAllTeamsPicker(
                        title: "Final Four Team \(idx + 1)",
                        options: picksStore.teams,
                        selectedId: resultsStore.results.finalFour.count > idx ? resultsStore.results.finalFour[idx] : nil,
                        placeholder: "Pick",
                        label: { $0.abbr }
                    ) { teamId in
                        Task { try? await resultsStore.setFinalFour(index: idx, teamId: teamId) }
                    }
                }
            }

            // Final Two (unordered)
            Section(header: Text("Final Two")) {
                Text("Order does not matter. Pick the 2 teams that made the final.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ForEach(0..<2, id: \.self) { idx in
                    AdminAllTeamsPicker(
                        title: "Finalist \(idx + 1)",
                        options: picksStore.teams,
                        selectedId: resultsStore.results.finalTwo.count > idx ? resultsStore.results.finalTwo[idx] : nil,
                        placeholder: "Pick",
                        label: { $0.abbr }
                    ) { teamId in
                        Task { try? await resultsStore.setFinalTwo(index: idx, teamId: teamId) }
                    }
                }
            }

            Section(header: Text("Champion")) {
                AdminAllTeamsPicker(
                    title: "Winner",
                    options: picksStore.teams,
                    selectedId: resultsStore.results.champion,
                    placeholder: "Pick",
                    label: { $0.abbr }
                ) { teamId in
                    Task { try? await resultsStore.setChampion(teamId: teamId) }
                }
            }
        }
        .navigationTitle("Admin")
    }

    // (Intentionally no ordering helpers — KO results are scored unordered)
}

private struct AdminPoolResultPicker: View {
    let title: String
    let options: [WBCTeam]
    let selectedId: String?
    let placeholder: String
    let label: (WBCTeam) -> String
    let onSelect: (String) -> Void

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Menu {
                ForEach(options) { t in
                    Button { onSelect(t.id) } label: { Text(label(t)) }
                }
            } label: {
                Text(selectedText)
                    .fontWeight(.semibold)
            }
        }
    }

    private var selectedText: String {
        guard let id = selectedId, !id.isEmpty else { return placeholder }
        if let t = options.first(where: { $0.id == id }) {
            return label(t)
        }
        return id
    }
}

private struct AdminAllTeamsPicker: View {
    let title: String
    let options: [WBCTeam]
    let selectedId: String?
    let placeholder: String
    let label: (WBCTeam) -> String
    let onSelect: (String) -> Void

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Menu {
                ForEach(options) { t in
                    Button { onSelect(t.id) } label: { Text(label(t)) }
                }
            } label: {
                Text(selectedText)
                    .fontWeight(.semibold)
            }
        }
    }

    private var selectedText: String {
        guard let id = selectedId, !id.isEmpty else { return placeholder }
        if let t = options.first(where: { $0.id == id }) {
            return label(t)
        }
        return id
    }
}
