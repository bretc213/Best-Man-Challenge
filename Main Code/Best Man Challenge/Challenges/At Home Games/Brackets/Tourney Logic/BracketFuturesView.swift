
//  BracketFuturesView.swift
//

import SwiftUI
import FirebaseFirestore

struct BracketFuturesView: View {
    @EnvironmentObject var session: SessionStore
    let gameRefId: String

    private enum FuturesTab: String, CaseIterable, Identifiable {
        case games = "Games"
        case potentialStandings = "Potential Standings"
        var id: String { rawValue }
    }

    private struct ProjectedRow: Identifiable {
        let id: String
        let playerId: String
        let displayName: String
        let currentPoints: Int
        let projectedPoints: Int

        var delta: Int { projectedPoints - currentPoints }
    }

    @State private var selectedTab: FuturesTab = .games
    @State private var meta: BMCBracketGameMeta? = nil
    @State private var teamsById: [String: BMCBracketTeam] = [:]
    @State private var matchups: [BMCBracketMatchup] = []
    @State private var pickDocs: [BMCBracketPicksDoc] = []
    @State private var displayNames: [String: String] = [:]
    @State private var hypotheticalWinners: [String: String] = [:]
    @State private var errorMessage: String? = nil
    @State private var listeners: [ListenerRegistration] = []

    private let db = Firestore.firestore()
    private let directory = PlayerDirectory()

    var body: some View {
        ThemedScreen {
            VStack(spacing: 12) {
                Picker("Futures Tab", selection: $selectedTab) {
                    ForEach(FuturesTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 6)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                switch selectedTab {
                case .games:
                    gamesView
                case .potentialStandings:
                    potentialStandingsView
                }
            }
            .navigationTitle("Futures")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { attachListeners() }
            .onDisappear { detachListeners() }
        }
    }

    private var rules: BMCBracketScoringRules {
        meta?.scoring ?? BMCBracketScoringRules(data: nil)
    }

    private var matchupsById: [String: BMCBracketMatchup] {
        Dictionary(uniqueKeysWithValues: matchups.map { ($0.id, $0) })
    }

    private var feedersById: [String: BracketEngine.Feeders] {
        BracketEngine.buildFeeders(matchups: matchups)
    }

    private var unresolvedMatchups: [BMCBracketMatchup] {
        matchups.filter { $0.winnerTeamId == nil }
    }

    @ViewBuilder
    private var gamesView: some View {
        if unresolvedMatchups.isEmpty {
            ContentUnavailableView(
                "No undecided games",
                systemImage: "checkmark.circle",
                description: Text("As the admin sets winners, undecided games disappear from this playground.")
            )
            .padding(.top, 30)
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    infoCard

                    LazyVStack(spacing: 12) {
                        ForEach(unresolvedMatchups) { matchup in
                            let home = BracketEngine.slotDisplay(
                                matchup: matchup,
                                slot: "home",
                                picks: hypotheticalWinners,
                                matchupsById: matchupsById,
                                feedersById: feedersById
                            )

                            let away = BracketEngine.slotDisplay(
                                matchup: matchup,
                                slot: "away",
                                picks: hypotheticalWinners,
                                matchupsById: matchupsById,
                                feedersById: feedersById
                            )

                            BMCBracketMatchupCard(
                                matchup: matchup,
                                teamsById: teamsById,
                                userPickTeamId: hypotheticalWinners[matchup.id],
                                isLocked: false,
                                homeDisplayTeamId: home.teamId,
                                awayDisplayTeamId: away.teamId,
                                homeTint: home.tint,
                                awayTint: away.tint,
                                onSelectHome: {
                                    setHypotheticalWinner(matchupId: matchup.id, teamId: home.teamId)
                                },
                                onSelectAway: {
                                    setHypotheticalWinner(matchupId: matchup.id, teamId: away.teamId)
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder
    private var potentialStandingsView: some View {
        let rows = projectedRows()

        if pickDocs.isEmpty {
            ContentUnavailableView(
                "No picks yet",
                systemImage: "person.3",
                description: Text("Projected standings will appear once players submit brackets.")
            )
            .padding(.top, 30)
        } else {
            List {
                Section {
                    Text("These standings update live from admin results plus your hypothetical winners in Games.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    HStack(alignment: .top) {
                        Text("#\(index + 1)")
                            .font(.headline)
                            .frame(width: 44, alignment: .leading)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.displayName)
                                .font(.headline)

                            Text("Projected: \(row.projectedPoints) pts")
                                .font(.subheadline.weight(.semibold))

                            Text("Current: \(row.currentPoints) • Change: \(row.delta >= 0 ? "+" : "")\(row.delta)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Undecided Games")
                .font(.headline)

            Text("Pick hypothetical winners for any game the admin has not finalized yet. Your choices update Potential Standings instantly and use the latest live admin results.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !hypotheticalWinners.isEmpty {
                Button("Clear Hypothetical Winners") {
                    hypotheticalWinners = [:]
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func projectedRows() -> [ProjectedRow] {
        pickDocs.map { doc in
            let current = BracketEngine.score(
                picks: doc.selections,
                matchups: matchups,
                rules: rules
            ).totalPoints

            let projected = BracketEngine.score(
                picks: doc.selections,
                matchups: matchups,
                rules: rules,
                simulatedWinners: hypotheticalWinners
            ).totalPoints

            return ProjectedRow(
                id: doc.playerId,
                playerId: doc.playerId,
                displayName: displayNames[doc.playerId] ?? doc.playerId,
                currentPoints: current,
                projectedPoints: projected
            )
        }
        .sorted {
            if $0.projectedPoints != $1.projectedPoints { return $0.projectedPoints > $1.projectedPoints }
            if $0.currentPoints != $1.currentPoints { return $0.currentPoints > $1.currentPoints }
            return $0.displayName < $1.displayName
        }
    }

    private func setHypotheticalWinner(matchupId: String, teamId: String?) {
        guard let teamId else { return }

        hypotheticalWinners[matchupId] = teamId

        if let current = matchupsById[matchupId],
           let nextMatchupId = current.nextMatchupId {
            clearFutureHypotheticals(startingAt: nextMatchupId)
        }
    }

    private func clearFutureHypotheticals(startingAt matchupId: String) {
        hypotheticalWinners.removeValue(forKey: matchupId)

        guard let matchup = matchupsById[matchupId],
              let nextMatchupId = matchup.nextMatchupId else {
            return
        }

        clearFutureHypotheticals(startingAt: nextMatchupId)
    }

    private func attachListeners() {
        guard listeners.isEmpty else { return }

        let gameRef = db.collection("bracket_games").document(gameRefId)

        listeners.append(
            gameRef.addSnapshotListener { snapshot, error in
                if let error {
                    self.errorMessage = "Failed to load bracket: \(error.localizedDescription)"
                    return
                }
                let data = snapshot?.data() ?? [:]
                self.meta = BMCBracketGameMeta(id: snapshot?.documentID ?? self.gameRefId, data: data)
            }
        )

        listeners.append(
            gameRef.collection("teams").addSnapshotListener { snapshot, error in
                if let error {
                    self.errorMessage = "Failed to load teams: \(error.localizedDescription)"
                    return
                }
                let docs = snapshot?.documents ?? []
                var map: [String: BMCBracketTeam] = [:]
                for doc in docs {
                    let team = BMCBracketTeam(id: doc.documentID, data: doc.data())
                    map[team.id] = team
                }
                self.teamsById = map
            }
        )

        listeners.append(
            gameRef.collection("matchups").addSnapshotListener { snapshot, error in
                if let error {
                    self.errorMessage = "Failed to load matchups: \(error.localizedDescription)"
                    return
                }
                let docs = snapshot?.documents ?? []
                let loaded = docs
                    .compactMap { BMCBracketMatchup(id: $0.documentID, data: $0.data()) }
                    .sorted {
                        if $0.round != $1.round { return $0.round < $1.round }
                        return $0.gameNumber < $1.gameNumber
                    }

                self.matchups = loaded

                let resolvedIds = Set(loaded.filter { $0.winnerTeamId != nil }.map { $0.id })
                self.hypotheticalWinners = self.hypotheticalWinners.filter { !resolvedIds.contains($0.key) }
            }
        )

        listeners.append(
            gameRef.collection("picks").addSnapshotListener { snapshot, error in
                if let error {
                    self.errorMessage = "Failed to load picks: \(error.localizedDescription)"
                    return
                }
                let docs = snapshot?.documents ?? []
                let loaded = docs.compactMap { BMCBracketPicksDoc(id: $0.documentID, data: $0.data()) }
                self.pickDocs = loaded

                Task {
                    let names = await directory.fetchDisplayNames(playerIds: loaded.map { $0.playerId })
                    await MainActor.run {
                        self.displayNames = names
                    }
                }
            }
        )
    }

    private func detachListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
}
