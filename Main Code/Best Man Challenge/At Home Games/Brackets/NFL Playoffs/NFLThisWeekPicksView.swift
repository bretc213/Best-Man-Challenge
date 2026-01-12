//
//  NFLThisWeekPicksView.swift
//  Best Man Challenge
//

import SwiftUI
import FirebaseAuth

struct NFLThisWeekPicksView: View {
    @EnvironmentObject var session: SessionStore
    @ObservedObject var store: NFLPlayoffsPicksStore

    @Binding var selectedRound: BracketRound

    private let rounds: [BracketRound] = [.wildcard, .divisional, .conference, .superBowl]

    // ✅ Hardcoded display names for teams that might not appear in matchups
    // Add more if you want perfect names for every team independent of matchups.
    private let teamNameOverrides: [String: String] = [
        "DEN": "Denver Broncos",
        "SEA": "Seattle Seahawks"
    ]

    // ✅ Your 2026 playoff field (edit IDs to match your matchup team ids)
    private let afcPlayoffTeamIds: [String] = ["DEN", "NE", "JAX", "PIT", "HOU", "BUF", "LAC"]
    private let nfcPlayoffTeamIds: [String] = ["SEA", "CHI", "PHI", "CAR", "LAR", "SF", "GB"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            header

            Picker("Round", selection: $selectedRound) {
                ForEach(rounds, id: \.self) { r in
                    Text(roundTitle(r)).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedRound) { _, newValue in
                store.setRound(newValue.rawValue)
            }

            

            if store.isLoading {
                ProgressView("Loading games...")
                    .padding(.top, 12)

            } else if let err = store.errorMessage {
                Text("Couldn’t load: \(err)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

            } else if store.matchups.isEmpty {
                Text("No games found for this round.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

            } else {
                ScrollView {
                    VStack(spacing: 12) {

                        // ✅ Champs card INSIDE the scroll (top), only in Wild Card
                        if selectedRound == .wildcard {
                            championshipPicksCard
                        }

                        // Matchup cards
                        ForEach(store.matchups, id: \.id) { matchup in
                            MatchupPickCard(
                                matchup: matchup,
                                selectedTeamId: store.myPicks[matchup.id],
                                onPick: { teamId in
                                    Task { await pick(matchup: matchup, teamId: teamId) }
                                }
                            )
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }
            }
        }
        .padding(.top, 12)
        .padding(.horizontal)
        .onChange(of: store.myChamps["afc"] ?? "") { _, _ in enforceSuperBowlValidity() }
        .onChange(of: store.myChamps["nfc"] ?? "") { _, _ in enforceSuperBowlValidity() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NFL Playoffs Picks")
                .font(.title2.bold())

            Text("Pick each game before kickoff. Picks lock at game time and reveal to everyone at lock.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Individual Games - 2 pts each\nChampionship Game - 4 pts each\nSuper Bowl - 8 pts each")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Championship Picks (AFC/NFC lists + SB constrained)

    private var championshipPicksCard: some View {
        let lockAt = earliestKickoffForRound() ?? .distantFuture
        let locked = Date() >= lockAt

        let afcOptions = teamOptions(for: afcPlayoffTeamIds)
        let nfcOptions = teamOptions(for: nfcPlayoffTeamIds)

        let currentAfc = store.myChamps["afc"] ?? ""
        let currentNfc = store.myChamps["nfc"] ?? ""
        let sbOptions = superBowlOptions(afc: currentAfc, nfc: currentNfc)

        let afcBinding = Binding<String>(
            get: { store.myChamps["afc"] ?? "" },
            set: { newValue in Task { await saveChamp(key: "afc", teamId: newValue, lockAt: lockAt) } }
        )

        let nfcBinding = Binding<String>(
            get: { store.myChamps["nfc"] ?? "" },
            set: { newValue in Task { await saveChamp(key: "nfc", teamId: newValue, lockAt: lockAt) } }
        )

        let sbBinding = Binding<String>(
            get: { store.myChamps["superBowl"] ?? "" },
            set: { newValue in Task { await saveChamp(key: "superBowl", teamId: newValue, lockAt: lockAt) } }
        )

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Championship Picks")
                    .font(.headline)

                Spacer()

                if locked {
                    Text("LOCKED")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.20))
                        .foregroundStyle(Color.red)
                        .clipShape(Capsule())
                } else {
                    Text("Locks at first kickoff")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            champMenuRow(title: "AFC Champ", selection: afcBinding, options: afcOptions, disabled: locked)
            champMenuRow(title: "NFC Champ", selection: nfcBinding, options: nfcOptions, disabled: locked)

            champMenuRow(
                title: "Super Bowl Champ",
                selection: sbBinding,
                options: sbOptions,
                disabled: locked || sbOptions.isEmpty
            )

            Text("Super Bowl can only be one of your AFC/NFC champs.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
        .opacity(locked ? 0.95 : 1.0)
    }

    // MARK: - Name resolution

    private func displayName(for teamId: String) -> String {
        if teamId.isEmpty { return "Select" }

        if let name = teamNameOverrides[teamId] { return name }

        // fallback to matchup names if present
        for m in store.matchups {
            if m.away.id == teamId { return m.away.name }
            if m.home.id == teamId { return m.home.name }
        }
        return teamId
    }

    // MARK: - Options builders

    private func teamOptions(for ids: [String]) -> [(id: String, name: String)] {
        ids.map { (id: $0, name: displayName(for: $0)) }
    }

    private func superBowlOptions(afc: String, nfc: String) -> [(id: String, name: String)] {
        guard !afc.isEmpty, !nfc.isEmpty else { return [] }
        return [
            (id: afc, name: displayName(for: afc)),
            (id: nfc, name: displayName(for: nfc))
        ]
    }

    private func champMenuRow(
        title: String,
        selection: Binding<String>,
        options: [(id: String, name: String)],
        disabled: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(title, selection: selection) {
                Text(options.isEmpty ? "Pick AFC + NFC first" : "Select").tag("")
                ForEach(options, id: \.id) { opt in
                    Text(opt.name).tag(opt.id)
                }
            }
            .pickerStyle(.menu)
            .disabled(disabled)
        }
    }

    private func earliestKickoffForRound() -> Date? {
        store.matchups.map(\.lockAt).min()
    }

    // If SB pick isn't one of the two champs, clear it.
    private func enforceSuperBowlValidity() {
        let afc = store.myChamps["afc"] ?? ""
        let nfc = store.myChamps["nfc"] ?? ""
        let sb  = store.myChamps["superBowl"] ?? ""

        guard !sb.isEmpty else { return }
        if sb != afc && sb != nfc {
            Task { await saveChamp(key: "superBowl", teamId: "", lockAt: .distantFuture) }
        }
    }

    // MARK: - Firestore writes (current store API)

    @MainActor
    private func saveChamp(key: String, teamId: String, lockAt: Date) async {
        let uid = Auth.auth().currentUser?.uid ?? ""
        guard !uid.isEmpty else { return }
        guard Date() < lockAt else { return }

        let role = session.profile?.role ?? ""
        let linked = session.profile?.linkedPlayerId
        let name = session.profile?.displayName ?? "Unknown"

        do {
            try await store.setChamp(
                uid: uid,
                displayName: name,
                role: role,
                linkedPlayerId: (linked?.isEmpty == false) ? linked : nil,
                key: key,
                teamId: teamId
            )
        } catch {
            // optional toast later
        }
    }

    @MainActor
    private func pick(matchup: BracketMatchup, teamId: String) async {
        let uid = Auth.auth().currentUser?.uid ?? ""
        guard !uid.isEmpty else { return }

        let role = session.profile?.role ?? ""
        let linked = session.profile?.linkedPlayerId
        let name = session.profile?.displayName ?? "Unknown"

        do {
            try await store.setPick(
                uid: uid,
                displayName: name,
                role: role,
                linkedPlayerId: (linked?.isEmpty == false) ? linked : nil,
                matchup: matchup,
                teamId: teamId
            )
        } catch {
            // optional toast later
        }
    }

    private func roundTitle(_ r: BracketRound) -> String {
        switch r {
        case .wildcard: return "Wild Card"
        case .divisional: return "Divisional"
        case .conference: return "Conference"
        case .superBowl: return "Super Bowl"
        }
    }
}

// MARK: - Matchup Card (logo-only, All Picks style)

private struct MatchupPickCard: View {
    let matchup: BracketMatchup
    let selectedTeamId: String?
    let onPick: (String) -> Void

    private var isLocked: Bool { Date() >= matchup.lockAt }
    private var winnerId: String? { matchup.winnerTeamId }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(matchupTimeString(matchup.startsAt))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if isLocked {
                    Text("LOCKED")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.20))
                        .foregroundStyle(Color.red)
                        .clipShape(Capsule())
                } else {
                    Text("Locks at kickoff")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                teamLogoButton(team: matchup.away)
                Text("@").foregroundStyle(.secondary)
                teamLogoButton(team: matchup.home)
            }

            if let tv = matchup.tv, !tv.isEmpty {
                Text(tv)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
        .opacity(isLocked ? 0.95 : 1.0)
    }

    private func teamLogoButton(team: MatchupTeam) -> some View {
        let isSelected = selectedTeamId == team.id

        let hasWinner = (winnerId != nil)
        let selectedIsCorrect = (hasWinner && isSelected && selectedTeamId == winnerId)
        let selectedIsWrong = (hasWinner && isSelected && selectedTeamId != winnerId)

        let bg: Color = {
            if selectedIsCorrect { return Color.green.opacity(0.28) }
            if selectedIsWrong { return Color.red.opacity(0.28) }
            if isSelected { return Color.accent.opacity(0.18) }
            return Color.white.opacity(0.08)
        }()

        let ringOpacity: Double = {
            if selectedIsCorrect || selectedIsWrong { return 0.55 }
            if isSelected { return 0.35 }
            return 0.18
        }()

        return Button {
            guard !isLocked else { return }
            onPick(team.id)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(bg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(ringOpacity), lineWidth: 1)
                    )

                Group {
                    if let asset = team.logoAsset, !asset.isEmpty {
                        Image(asset)
                            .resizable()
                            .scaledToFit()
                            .padding(14)
                    } else {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.accent)
                    }
                }

                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.accent : .secondary)
                            .padding(10)
                    }
                    Spacer()
                }
            }
            .frame(width: 120, height: 92)
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .accessibilityLabel(Text("Pick \(team.name)"))
    }

    private func matchupTimeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
