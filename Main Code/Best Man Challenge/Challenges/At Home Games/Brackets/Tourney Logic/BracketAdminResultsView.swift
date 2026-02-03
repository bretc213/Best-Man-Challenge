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

    @State private var matchups: [TourneyMatchup] = []
    @State private var teamsById: [String: TourneyTeam] = [:]
    @State private var errorMessage: String? = nil

    private let db = Firestore.firestore()

    var body: some View {
        ThemedScreen {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

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

            var map: [String: TourneyTeam] = [:]
            for doc in teamsSnap.documents {
                if let t = TourneyTeam(id: doc.documentID, data: doc.data()) {
                    map[t.id] = t
                }
            }

            let matchSnap = try await db.collection("bracket_games")
                .document(gameRefId)
                .collection("matchups")
                .getDocuments()

            let ms = matchSnap.documents
                .compactMap { TourneyMatchup(id: $0.documentID, data: $0.data()) }
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
}
