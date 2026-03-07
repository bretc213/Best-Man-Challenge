//
//  BracketAllPicksView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/31/26.
//

import SwiftUI
import FirebaseFirestore

struct BracketAllPicksView: View {
    let gameRefId: String

    @State private var meta: BMCBracketGameMeta? = nil
    @State private var matchups: [BMCBracketMatchup] = []
    @State private var teamsById: [String: BMCBracketTeam] = [:]
    @State private var pickDocs: [BMCBracketPicksDoc] = []
    @State private var displayNames: [String: String] = [:]
    @State private var errorMessage: String? = nil

    private let db = Firestore.firestore()
    private let directory = PlayerDirectory()

    var body: some View {
        ThemedScreen {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if pickDocs.isEmpty {
                    ContentUnavailableView(
                        "No picks yet",
                        systemImage: "person.3",
                        description: Text("Once players submit brackets, they’ll show up here.")
                    )
                    .padding(.vertical, 24)
                } else {
                    ForEach(sortedRows(), id: \.playerId) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(displayNames[row.playerId] ?? row.playerId)
                                    .font(.headline)
                                Spacer()
                                Text("\(row.points) pts")
                                    .font(.headline)
                            }

                            // lightweight preview: show a few key picks (champion = last round matchup, if any)
                            if let champ = row.championTeamName {
                                Text("Champion: \(champ)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("All Picks")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { Task { await load() } }
        }
    }

    // MARK: - Derived rows

    private struct Row {
        let playerId: String
        let points: Int
        let championTeamName: String?
    }

    private func sortedRows() -> [Row] {
        let rules = meta?.scoring ?? BMCBracketScoringRules(data: nil)

        // Guess "championship matchup" as the highest round number with a matchup.
        let maxRound = matchups.map(\.round).max() ?? 0
        let champMatchupIds = matchups.filter { $0.round == maxRound }.map(\.id)
        let champMatchupId = champMatchupIds.sorted().first // stable

        var rows: [Row] = []
        for p in pickDocs {
            let breakdown = BracketEngine.score(picks: p.selections, matchups: matchups, rules: rules)

            var champName: String? = nil
            if let champMatchupId,
               let teamId = p.selections[champMatchupId] {
                champName = teamsById[teamId]?.name ?? teamId
            }

            rows.append(Row(playerId: p.id, points: breakdown.totalPoints, championTeamName: champName))
        }

        return rows.sorted { $0.points > $1.points }
    }

    // MARK: - Load

    private func load() async {
        do {
            let metaSnap = try await db.collection("bracket_games").document(gameRefId).getDocument()
            if let d = metaSnap.data() {
                self.meta = BMCBracketGameMeta(id: metaSnap.documentID, data: d)
            }

            let teamsSnap = try await db.collection("bracket_games")
                .document(gameRefId)
                .collection("teams")
                .getDocuments()

            var tmap: [String: BMCBracketTeam] = [:]
            for doc in teamsSnap.documents {
                // BMCBracketTeam initializer is non-failable; no conditional binding.
                let t = BMCBracketTeam(id: doc.documentID, data: doc.data())
                tmap[t.id] = t
            }

            let matchSnap = try await db.collection("bracket_games")
                .document(gameRefId)
                .collection("matchups")
                .getDocuments()

            let ms = matchSnap.documents
                .compactMap { BMCBracketMatchup(id: $0.documentID, data: $0.data()) }
                .sorted {
                    if $0.round != $1.round { return $0.round < $1.round }
                    return $0.gameNumber < $1.gameNumber
                }

            let picksSnap = try await db.collection("bracket_games")
                .document(gameRefId)
                .collection("picks")
                .getDocuments()

            let ps = picksSnap.documents
                .compactMap { BMCBracketPicksDoc(id: $0.documentID, data: $0.data()) }

            let names = await directory.fetchDisplayNames(playerIds: ps.map { $0.playerId })

            await MainActor.run {
                self.teamsById = tmap
                self.matchups = ms
                self.pickDocs = ps
                self.displayNames = names
                self.errorMessage = nil
            }

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load all picks: \(error.localizedDescription)"
            }
        }
    }
}
