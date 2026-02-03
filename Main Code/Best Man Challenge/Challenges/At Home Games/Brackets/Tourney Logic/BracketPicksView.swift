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

    @State private var meta: TourneyGameMeta? = nil
    @State private var teamsById: [String: TourneyTeam] = [:]
    @State private var matchups: [TourneyMatchup] = []
    @State private var picks: TourneyPicksDoc? = nil
    @State private var errorMessage: String? = nil
    @State private var isSaving: Bool = false

    private let db = Firestore.firestore()

    // feeder map: matchupId -> (homeFeederId, awayFeederId)
    private struct Feeders {
        var home: String? = nil
        var away: String? = nil
    }

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
                    let feedersById = buildFeeders(matchups: matchups)

                    LazyVStack(spacing: 12) {
                        ForEach(matchups) { m in
                            let home = slotDisplay(
                                matchup: m,
                                slot: "home",
                                matchupsById: matchupsById,
                                feedersById: feedersById
                            )

                            let away = slotDisplay(
                                matchup: m,
                                slot: "away",
                                matchupsById: matchupsById,
                                feedersById: feedersById
                            )

                            let locked = isLockedNow

                            BracketMatchupCard(
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

    // MARK: - Feeder graph

    private func buildFeeders(matchups: [TourneyMatchup]) -> [String: Feeders] {
        var feeders: [String: Feeders] = [:]

        for m in matchups {
            guard let nextId = m.nextMatchupId,
                  let nextSlot = m.nextSlot else { continue }

            var f = feeders[nextId] ?? Feeders()
            if nextSlot == "home" {
                f.home = m.id
            } else if nextSlot == "away" {
                f.away = m.id
            }
            feeders[nextId] = f
        }

        return feeders
    }

    private struct SlotResult {
        let teamId: String?
        let tint: BracketMatchupCard.Tint
    }

    private func slotDisplay(
        matchup: TourneyMatchup,
        slot: String, // "home" or "away"
        matchupsById: [String: TourneyMatchup],
        feedersById: [String: Feeders]
    ) -> SlotResult {

        let feeders = feedersById[matchup.id]
        let feederId: String? = (slot == "home") ? feeders?.home : feeders?.away

        if let feederId,
           let feeder = matchupsById[feederId] {

            let userPicked = picks?.selections[feederId]
            let winner = feeder.winnerTeamId

            if let winner {
                if userPicked == winner {
                    return SlotResult(teamId: winner, tint: .green)
                } else {
                    return SlotResult(teamId: winner, tint: .red)
                }
            }

            if let userPicked {
                return SlotResult(teamId: userPicked, tint: .none)
            }

            return SlotResult(teamId: nil, tint: .none)
        }

        // Round 1 fallback
        if slot == "home" {
            return SlotResult(teamId: matchup.homeTeamId, tint: .none)
        } else {
            return SlotResult(teamId: matchup.awayTeamId, tint: .none)
        }
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
                self.picks = TourneyPicksDoc(
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

    private func loadAll() async {
        do {
            let metaSnap = try await db.collection("bracket_games").document(gameRefId).getDocument()
            if let d = metaSnap.data() {
                self.meta = TourneyGameMeta(id: metaSnap.documentID, data: d)
            }

            let teamsSnap = try await db.collection("bracket_games").document(gameRefId).collection("teams").getDocuments()
            var tmap: [String: TourneyTeam] = [:]
            for doc in teamsSnap.documents {
                if let t = TourneyTeam(id: doc.documentID, data: doc.data()) {
                    tmap[t.id] = t
                }
            }

            let matchSnap = try await db.collection("bracket_games").document(gameRefId).collection("matchups").getDocuments()
            let ms = matchSnap.documents.compactMap { TourneyMatchup(id: $0.documentID, data: $0.data()) }
                .sorted {
                    if $0.round != $1.round { return $0.round < $1.round }
                    return $0.gameNumber < $1.gameNumber
                }

            let playerId = session.profile?.linkedPlayerId ?? ""
            var loadedPicks: TourneyPicksDoc? = nil
            if !playerId.isEmpty {
                let pickDoc = try await db.collection("bracket_games").document(gameRefId).collection("picks").document(playerId).getDocument()
                if let pd = pickDoc.data() {
                    loadedPicks = TourneyPicksDoc(id: pickDoc.documentID, data: pd)
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
