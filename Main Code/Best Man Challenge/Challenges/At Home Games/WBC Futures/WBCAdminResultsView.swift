//
//  WBCAdminResultsView.swift
//  Best Man Challenge
//

import SwiftUI

struct WBCAdminResultsView: View {
    @ObservedObject var picksStore: WBC2026PicksStore
    @ObservedObject var resultsStore: WBC2026ResultsStore
    @ObservedObject var scoresStore: WBC2026ScoresStore
    let session: SessionStore

    @State private var isFinalizing = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    private let challengeId = "wbc_2026"
    private let multiplier: Double = 1.0

    var body: some View {
        List {
            Section {
                Text("Set results here and the leaderboard will update live.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if resultsStore.results.isFinalized {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Finalized")
                            .font(.subheadline.bold())

                        if let finalizedAt = resultsStore.results.finalizedAt {
                            Text("Locked on \(finalizedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let finalizedBy = resultsStore.results.finalizedBy, !finalizedBy.isEmpty {
                            Text("By \(finalizedBy)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            Section("Finalize") {
                Button {
                    Task { await finalizeWBC() }
                } label: {
                    Label(
                        isFinalizing ? "Finalizing..." : "Finalize WBC Points",
                        systemImage: "checkmark.seal.fill"
                    )
                }
                .disabled(isFinalizing || resultsStore.results.isFinalized)

                Text("This locks the current WBC standings, updates overall challenge points, and stores a final snapshot in Firestore.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(WBCPool.allCases) { pool in
                Section(header: Text("Pool \(pool.rawValue) Results")) {
                    AdminPoolResultPicker(
                        title: "Winner (1)",
                        options: (picksStore.teamsByPool[pool] ?? []),
                        selectedId: resultsStore.results.poolResults[pool.rawValue]?["seed1"],
                        placeholder: "Pick",
                        label: { $0.abbr },
                        locked: resultsStore.results.isFinalized
                    ) { teamId in
                        Task { try? await resultsStore.setPoolResult(pool: pool, seed: "seed1", teamId: teamId) }
                    }

                    AdminPoolResultPicker(
                        title: "Runner-up (2)",
                        options: (picksStore.teamsByPool[pool] ?? []),
                        selectedId: resultsStore.results.poolResults[pool.rawValue]?["seed2"],
                        placeholder: "Pick",
                        label: { $0.abbr },
                        locked: resultsStore.results.isFinalized
                    ) { teamId in
                        Task { try? await resultsStore.setPoolResult(pool: pool, seed: "seed2", teamId: teamId) }
                    }
                }
            }

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
                        label: { $0.abbr },
                        locked: resultsStore.results.isFinalized
                    ) { teamId in
                        Task { try? await resultsStore.setFinalFour(index: idx, teamId: teamId) }
                    }
                }
            }

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
                        label: { $0.abbr },
                        locked: resultsStore.results.isFinalized
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
                    label: { $0.abbr },
                    locked: resultsStore.results.isFinalized
                ) { teamId in
                    Task { try? await resultsStore.setChampion(teamId: teamId) }
                }
            }
        }
        .navigationTitle("Admin")
        .alert("WBC 2026", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private var playerRows: [WBCScoreRow] {
        scoresStore.scores.filter { row in
            scoresStore.groupForPlayerId(row.id) == .players
        }
    }

    private func finalizeWBC() async {
        if resultsStore.results.isFinalized {
            alertMessage = "WBC is already finalized."
            showAlert = true
            return
        }

        isFinalizing = true
        defer { isFinalizing = false }

        do {
            let scoresByPlayer: [String: Double] = Dictionary(
                uniqueKeysWithValues: playerRows.map { row in
                    (row.linkedPlayerId, Double(row.score))
                }
            )

            let finalizer = ChallengePointsFinalizer()
            try await finalizer.finalizeChallenge(
                challengeId: challengeId,
                scoresByPlayer: scoresByPlayer,
                multiplier: multiplier,
                higherIsBetter: true
            )

            let finalizedBy = session.profile?.displayName ?? "Admin"
            try await resultsStore.finalizeStandings(rows: playerRows, finalizedBy: finalizedBy)

            alertMessage = "Finalize complete."
            showAlert = true
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}

private struct AdminPoolResultPicker: View {
    let title: String
    let options: [WBCTeam]
    let selectedId: String?
    let placeholder: String
    let label: (WBCTeam) -> String
    let locked: Bool
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
            .disabled(locked)
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
    let locked: Bool
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
            .disabled(locked)
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
