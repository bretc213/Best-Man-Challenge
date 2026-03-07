//
//  BMCBracketStandingsView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/31/26.
//

import SwiftUI
import FirebaseFirestore

struct BMCBracketStandingsView: View {
    let gameRefId: String

    @State private var standings: [BMCBracketStanding] = []
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

                if standings.isEmpty {
                    ContentUnavailableView(
                        "No standings yet",
                        systemImage: "list.number",
                        description: Text("Once results are entered and standings are computed, they’ll appear here.")
                    )
                    .padding(.vertical, 24)
                } else {
                    ForEach(Array(standings.enumerated()), id: \.element.id) { idx, s in
                        HStack {
                            Text("#\(idx + 1)")
                                .font(.headline)
                                .frame(width: 44, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.displayName ?? s.playerId)
                                    .font(.headline)
                                Text("\(s.points) pts")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Standings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { Task { await load() } }
        }
    }

    private func load() async {
        do {
            let snap = try await db.collection("bracket_games")
                .document(gameRefId)
                .collection("standings")
                .getDocuments()

            let rows = snap.documents
                .compactMap { BMCBracketStanding(id: $0.documentID, data: $0.data()) }
                .sorted { $0.points > $1.points }

            await MainActor.run {
                self.standings = rows
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load standings: \(error.localizedDescription)"
            }
        }
    }
}
