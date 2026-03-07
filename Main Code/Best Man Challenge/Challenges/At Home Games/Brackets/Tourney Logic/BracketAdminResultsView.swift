//
//  BracketAdminResultsView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/31/26.
//

import SwiftUI
import FirebaseFirestore

struct BracketAdminResultsView: View {
    @EnvironmentObject var session: SessionStore
    let gameRefId: String

    @State private var matchups: [BMCBracketMatchup] = []
    @State private var teamsById: [String: BMCBracketTeam] = [:]
    @State private var errorMessage: String? = nil
    @State private var isRecomputing: Bool = false

    private let db = Firestore.firestore()
    private let standingsService = BMCBracketStandingsService()

    var body: some View {
        ThemedScreen {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if isOwner {
                    Section {
                        Button {
                            Task { await recomputeStandings() }
                        } label: {
                            HStack {
                                Text(isRecomputing ? "Recomputing..." : "Recompute Standings")
                                Spacer()
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                        }
                        .disabled(isRecomputing)
                    } header: {
                        Text("Admin Tools")
                    }
                }

                Section {
                    ForEach(matchups) { m in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Round \(m.round) • Game \(m.gameNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack {
                                Text(teamName(m.homeTeamId) ?? "TBD")
                                Spacer()
                                Text("vs").foregroundStyle(.secondary)
                                Spacer()
                                Text(teamName(m.awayTeamId) ?? "TBD")
                            }
                            .font(.headline)

                            if isOwner,
                               let home = m.homeTeamId,
                               let away = m.awayTeamId {

                                HStack {
                                    Button("Set Home Winner") {
                                        Task { await setWinner(matchupId: m.id, winnerTeamId: home) }
                                    }
                                    .buttonStyle(.bordered)

                                    Button("Set Away Winner") {
                                        Task { await setWinner(matchupId: m.id, winnerTeamId: away) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }

                                if let winner = m.winnerTeamId {
                                    Text("Winner: \(teamName(winner) ?? winner)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Matchups")
                }
            }
            .listStyle(.plain)
            .navigationTitle("Admin")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { Task { await load() } }
        }
    }

    private var isOwner: Bool {
        (session.profile?.role ?? "") == "owner"
    }

    private func teamName(_ id: String?) -> String? {
        guard let id else { return nil }
        return teamsById[id]?.name
    }

    private func load() async {
        do {
            let teamsSnap = try await db.collection("bracket_games")
                .document(gameRefId)
                .collection("teams")
                .getDocuments()

            var map: [String: BMCBracketTeam] = [:]
            for doc in teamsSnap.documents {
                // BMCBracketTeam initializer is non-failable; no conditional binding.
                let t = BMCBracketTeam(id: doc.documentID, data: doc.data())
                map[t.id] = t
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

            await MainActor.run {
                self.teamsById = map
                self.matchups = ms
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load: \(error.localizedDescription)"
            }
        }
    }

    private func setWinner(matchupId: String, winnerTeamId: String) async {
        do {
            try await db.collection("bracket_games")
                .document(gameRefId)
                .collection("matchups")
                .document(matchupId)
                .updateData([
                    "winnerTeamId": winnerTeamId,
                    "updatedAt": FieldValue.serverTimestamp()
                ])

            await load()
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to set winner: \(error.localizedDescription)"
            }
        }
    }

    private func recomputeStandings() async {
        guard isOwner else { return }
        isRecomputing = true
        errorMessage = nil
        do {
            try await standingsService.recomputeStandings(gameRefId: gameRefId)
            await MainActor.run {
                self.isRecomputing = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to recompute standings: \(error.localizedDescription)"
                self.isRecomputing = false
            }
        }
    }
}
