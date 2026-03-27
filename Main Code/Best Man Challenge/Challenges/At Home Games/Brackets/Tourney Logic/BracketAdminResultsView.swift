
//  BracketAdminResultsView.swift
//  Best Man Challenge
//
//  Updated to auto-advance winners in admin:
//  - When admin selects a winner, that team is pushed into the next matchup slot
//  - Downstream winners are cleared so later rounds cannot stay stale
//

import SwiftUI
import FirebaseFirestore

struct BracketAdminResultsView: View {
    @EnvironmentObject var session: SessionStore
    let gameRefId: String

    @State private var meta: BMCBracketGameMeta? = nil
    @State private var matchups: [BMCBracketMatchup] = []
    @State private var teamsById: [String: BMCBracketTeam] = [:]
    @State private var errorMessage: String? = nil
    @State private var isRecomputing: Bool = false
    @State private var isFinalizing: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    private let db = Firestore.firestore()
    private let standingsService = BMCBracketStandingsService()
    private let multiplier: Double = 1.0

    var body: some View {
        ThemedScreen {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if isOwner {
                    adminToolsSection
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
                                    .disabled(isFinalized)

                                    Button("Set Away Winner") {
                                        Task { await setWinner(matchupId: m.id, winnerTeamId: away) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(isFinalized)
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
            .alert("Bracket", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var isOwner: Bool {
        (session.profile?.role ?? "") == "owner"
    }

    private var isFinalized: Bool {
        meta?.isFinalized ?? false
    }

    @ViewBuilder
    private var adminToolsSection: some View {
        Section {
            Text("Use recompute while results are still moving. Finalize only once the bracket is done.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if isFinalized {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Finalized")
                        .font(.subheadline.bold())

                    if let finalizedAt = meta?.finalizedAt {
                        Text("Locked on \(finalizedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let finalizedBy = meta?.finalizedBy, !finalizedBy.isEmpty {
                        Text("By \(finalizedBy)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }

            Button {
                Task { await recomputeStandings() }
            } label: {
                HStack {
                    Text(isRecomputing ? "Recomputing..." : "Recompute Standings")
                    Spacer()
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
            }
            .disabled(isRecomputing || isFinalizing || isFinalized)

            Button {
                Task { await finalizeBracket() }
            } label: {
                HStack {
                    Text(isFinalizing ? "Finalizing..." : "Finalize Bracket Points")
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                }
            }
            .disabled(isRecomputing || isFinalizing || isFinalized)

            Text("Finalize uses the current standings, awards challenge points with multiplier ×1, saves a final snapshot, and locks further admin edits for this bracket.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("Admin Tools")
        }
    }

    private func teamName(_ id: String?) -> String? {
        guard let id else { return nil }
        return teamsById[id]?.name
    }

    private func load() async {
        do {
            let metaSnap = try await db.collection("bracket_games").document(gameRefId).getDocument()
            let loadedMeta = BMCBracketGameMeta(id: metaSnap.documentID, data: metaSnap.data() ?? [:])

            let teamsSnap = try await db.collection("bracket_games")
                .document(gameRefId)
                .collection("teams")
                .getDocuments()

            var map: [String: BMCBracketTeam] = [:]
            for doc in teamsSnap.documents {
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
                self.meta = loadedMeta
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
        guard !isFinalized else { return }
        guard let current = matchups.first(where: { $0.id == matchupId }) else { return }

        do {
            let currentRef = db.collection("bracket_games")
                .document(gameRefId)
                .collection("matchups")
                .document(matchupId)

            try await currentRef.updateData([
                "winnerTeamId": winnerTeamId,
                "updatedAt": FieldValue.serverTimestamp()
            ])

            if let nextMatchupId = current.nextMatchupId,
               let nextSlot = current.nextSlot {

                let nextRef = db.collection("bracket_games")
                    .document(gameRefId)
                    .collection("matchups")
                    .document(nextMatchupId)

                let slotField = (nextSlot == "home") ? "homeTeamId" : "awayTeamId"

                try await nextRef.updateData([
                    slotField: winnerTeamId,
                    "winnerTeamId": FieldValue.delete(),
                    "updatedAt": FieldValue.serverTimestamp()
                ])

                try await clearDescendantAdvancement(startingAt: nextMatchupId)
            }

            await load()
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to set winner: \(error.localizedDescription)"
            }
        }
    }

    private func clearDescendantAdvancement(startingAt matchupId: String) async throws {
        let ref = db.collection("bracket_games")
            .document(gameRefId)
            .collection("matchups")
            .document(matchupId)

        let snap = try await ref.getDocument()
        guard let data = snap.data() else { return }

        let matchup = BMCBracketMatchup(id: snap.documentID, data: data)

        guard let nextMatchupId = matchup.nextMatchupId,
              let nextSlot = matchup.nextSlot else {
            return
        }

        let nextRef = db.collection("bracket_games")
            .document(gameRefId)
            .collection("matchups")
            .document(nextMatchupId)

        let slotField = (nextSlot == "home") ? "homeTeamId" : "awayTeamId"

        try await nextRef.updateData([
            slotField: FieldValue.delete(),
            "winnerTeamId": FieldValue.delete(),
            "updatedAt": FieldValue.serverTimestamp()
        ])

        try await clearDescendantAdvancement(startingAt: nextMatchupId)
    }

    private func recomputeStandings() async {
        guard isOwner else { return }
        guard !isFinalized else { return }

        isRecomputing = true
        errorMessage = nil
        defer { isRecomputing = false }

        do {
            try await standingsService.recomputeStandings(gameRefId: gameRefId)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to recompute standings: \(error.localizedDescription)"
            }
        }
    }

    private func finalizeBracket() async {
        guard isOwner else { return }

        if isFinalized {
            await MainActor.run {
                alertMessage = "This bracket is already finalized."
                showAlert = true
            }
            return
        }

        isFinalizing = true
        errorMessage = nil
        defer { isFinalizing = false }

        do {
            let finalizedBy = session.profile?.displayName ?? "Admin"
            try await standingsService.finalizeGame(
                gameRefId: gameRefId,
                finalizedBy: finalizedBy,
                multiplier: multiplier
            )

            await load()
            await MainActor.run {
                alertMessage = "Finalize complete."
                showAlert = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to finalize bracket: \(error.localizedDescription)"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}
