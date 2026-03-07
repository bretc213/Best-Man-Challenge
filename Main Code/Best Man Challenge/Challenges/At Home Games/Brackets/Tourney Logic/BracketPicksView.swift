//
//  BracketPicksView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/31/26.
//

import SwiftUI
import FirebaseFirestore

struct BracketPicksView: View {
    @EnvironmentObject var session: SessionStore
    let gameRefId: String

    @State private var meta: BMCBracketGameMeta? = nil
    @State private var teamsById: [String: BMCBracketTeam] = [:]
    @State private var matchups: [BMCBracketMatchup] = []
    @State private var picks: BMCBracketPicksDoc? = nil
    @State private var errorMessage: String? = nil
    @State private var isSaving: Bool = false

    private let db = Firestore.firestore()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                headerCard()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                if matchups.isEmpty {
                    ContentUnavailableView(
                        "Bracket not seeded yet",
                        systemImage: "square.grid.3x3.middle.filled",
                        description: Text("Once teams + matchups are added in Firestore, picks will appear here.")
                    )
                    .padding(.top, 30)
                } else {
                    let matchupsById = Dictionary(uniqueKeysWithValues: matchups.map { ($0.id, $0) })
                    let feedersById = BracketEngine.buildFeeders(matchups: matchups)

                    LazyVStack(spacing: 12) {
                        ForEach(matchups) { m in
                            let selections = picks?.selections ?? [:]

                            let home = BracketEngine.slotDisplay(
                                matchup: m,
                                slot: "home",
                                picks: selections,
                                matchupsById: matchupsById,
                                feedersById: feedersById
                            )

                            let away = BracketEngine.slotDisplay(
                                matchup: m,
                                slot: "away",
                                picks: selections,
                                matchupsById: matchupsById,
                                feedersById: feedersById
                            )

                            let locked = isLockedNow

                            BMCBracketMatchupCard(
                                matchup: m,
                                teamsById: teamsById,
                                userPickTeamId: picks?.selections[m.id],
                                isLocked: locked,
                                homeDisplayTeamId: home.teamId,
                                awayDisplayTeamId: away.teamId,
                                homeTint: home.tint,
                                awayTint: away.tint,
                                onSelectHome: (locked ? nil : {
                                    Task { await setPick(matchupId: m.id, teamId: home.teamId) }
                                }),
                                onSelectAway: (locked ? nil : {
                                    Task { await setPick(matchupId: m.id, teamId: away.teamId) }
                                })
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 4)
                }

                if isSaving {
                    Text("Saving...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
            }
            .padding(.top, 8)
        }
        .onAppear { Task { await loadAll() } }
    }

    // MARK: - Locked logic

    private var isLockedNow: Bool {
        if picks?.isLocked == true { return true }
        guard let lockAt = meta?.lockAt else { return false }
        return Date() >= lockAt
    }

    // MARK: - Header

    @ViewBuilder
    private func headerCard() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(meta?.title ?? "Bracket Picks")
                .font(.title2.bold())

            if let startsAt = meta?.startsAt {
                Text("Starts \(dateString(startsAt))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let lockAt = meta?.lockAt {
                let lockedText = Date() >= lockAt ? "Locked" : "Locks"
                Text("\(lockedText) \(dateString(lockAt))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    // MARK: - Save pick

    private func setPick(matchupId: String, teamId: String?) async {
        guard !isLockedNow else { return }
        guard let teamId else { return } // can't pick TBD

        let playerId = session.profile?.linkedPlayerId ?? ""
        if playerId.isEmpty {
            await MainActor.run { self.errorMessage = "No linked player id." }
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let ref = db.collection("bracket_games")
                .document(gameRefId)
                .collection("picks")
                .document(playerId)

            // merge update: set the selection for this matchup
            try await ref.setData([
                "isLocked": false,
                "updatedAt": FieldValue.serverTimestamp(),
                "selections": [matchupId: teamId]
            ], merge: true)

            // Update local state immediately for instant UI response
            await MainActor.run {
                var current = picks?.selections ?? [:]
                current[matchupId] = teamId
                self.picks = BMCBracketPicksDoc(
                    id: playerId,
                    data: [
                        "isLocked": false,
                        "selections": current
                    ]
                )
                self.isSaving = false
            }

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to save pick: \(error.localizedDescription)"
                self.isSaving = false
            }
        }
        
    }

    // MARK: - Load

    // MARK: - Load

    private func loadAll() async {
        do {
            let metaSnap = try await db.collection("bracket_games").document(gameRefId).getDocument()
            if let d = metaSnap.data() {
                self.meta = BMCBracketGameMeta(id: metaSnap.documentID, data: d)
            }

            // ✅ TEAMS
            let teamsSnap = try await db.collection("bracket_games")
                .document(gameRefId)
                .collection("teams")
                .getDocuments()

            var tmap: [String: BMCBracketTeam] = [:]
            for doc in teamsSnap.documents {
                let t = BMCBracketTeam(id: doc.documentID, data: doc.data())

                tmap[t.id] = t
            }

            // ✅ MATCHUPS
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

            // ✅ PICKS
            let playerId = session.profile?.linkedPlayerId ?? ""
            var loadedPicks: BMCBracketPicksDoc? = nil
            if !playerId.isEmpty {
                let pickDoc = try await db.collection("bracket_games")
                    .document(gameRefId)
                    .collection("picks")
                    .document(playerId)
                    .getDocument()

                if let pd = pickDoc.data() {
                    loadedPicks = BMCBracketPicksDoc(id: pickDoc.documentID, data: pd)
                }
            }

            await MainActor.run {
                self.teamsById = tmap
                self.matchups = ms
                self.picks = loadedPicks
                self.errorMessage = nil
            }

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load: \(error.localizedDescription)"
            }
        }
    }
}
