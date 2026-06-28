//
//  WorldCup2026AdminView.swift
//  Best Man Challenge

import SwiftUI
import FirebaseAuth

struct WorldCup2026AdminView: View {
    @ObservedObject var picksStore: WorldCup2026PicksStore
    @ObservedObject var resultsStore: WorldCup2026ResultsStore
    @ObservedObject var scoresStore: WorldCup2026ScoresStore
    @ObservedObject var knockoutStore: WorldCup2026KnockoutStore
    let session: SessionStore

    @State private var isBusy = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    private let challengeId = "world_cup_2026"
    private let multiplier: Double = 1.0

    var body: some View {
        List {
            setupSection
            tournamentControlSection
            groupResultsSections
            phase2SetupSection
            phase2LockSection
            phase2ResultsSections
            liveScoresSection
        }
        .navigationTitle("Admin — World Cup 2026")
        .alert("World Cup 2026", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Setup / Seed

    @ViewBuilder
    private var setupSection: some View {
        Section(header: Text("Setup")) {
            let teamCount = picksStore.teams.count
            HStack {
                Text("Teams loaded")
                Spacer()
                Text("\(teamCount) / 48")
                    .fontWeight(.semibold)
                    .foregroundStyle(teamCount == 48 ? Color.green : Color.orange)
            }

            if teamCount == 0 {
                Text("No teams found in Firestore. Run the seeder below to populate all 48 teams before picks can be made.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            WorldCup2026SeedButton()
        }
    }

    // MARK: - Tournament Control

    @ViewBuilder
    private var tournamentControlSection: some View {
        Section(header: Text("Tournament Control")) {
            HStack {
                Text("Current Status")
                Spacer()
                WCStatusBadge(status: resultsStore.results.status)
            }
            tournamentActionButtons
            Text("Lock closes picks. Finalize awards overall challenge points and freezes standings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var tournamentActionButtons: some View {
        switch resultsStore.results.status {
        case .open:
            Button {
                Task { await changeStatus(.locked) }
            } label: {
                Label("Lock Tournament (Close Picks)", systemImage: "lock.fill")
                    .foregroundStyle(.red)
            }
            .disabled(isBusy)

        case .locked:
            Button {
                Task { await changeStatus(.open) }
            } label: {
                Label("Re-Open Tournament (Allow Edits)", systemImage: "lock.open.fill")
                    .foregroundStyle(.green)
            }
            .disabled(isBusy)

            Button {
                Task { await finalizeChallenge() }
            } label: {
                Label(isBusy ? "Finalizing…" : "Finalize & Award Points", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.blue)
            }
            .disabled(isBusy || resultsStore.results.isFinalized)

        case .finalized:
            WCFinalizedRow(
                finalizedAt: resultsStore.results.finalizedAt,
                finalizedBy: resultsStore.results.finalizedBy
            )
        }
    }

    // MARK: - Group Results

    @ViewBuilder
    private var groupResultsSections: some View {
        ForEach(WCGroup.allCases) { group in
            Section(header: Text("Group \(group.rawValue) — Results")) {
                ForEach(WCGroupSlot.allCases) { slot in
                    AdminGroupSlotRow(
                        slot: slot,
                        teams: picksStore.teamsByGroup[group] ?? [],
                        selectedId: resultsStore.results.result(for: group).teamId(forSlot: slot),
                        disabledIds: otherResultIds(group: group, excluding: slot),
                        locked: resultsStore.results.isFinalized
                    ) { teamId in
                        Task {
                            try? await resultsStore.setGroupResult(group: group, slot: slot, teamId: teamId)
                        }
                    } onClear: {
                        Task {
                            try? await resultsStore.setGroupResult(group: group, slot: slot, teamId: "")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Phase 2: Setup

    private var phase2SetupSection: some View {
        let matchCount = knockoutStore.matches.count
        return Section(header: Text("Phase 2 — Setup")) {
            HStack {
                Text("Bracket matches loaded")
                Spacer()
                Text("\(matchCount) / 31")
                    .fontWeight(.semibold)
                    .foregroundStyle(matchCount == 31 ? Color.green : Color.orange)
            }
            WorldCup2026KnockoutSeedButton()
            WorldCup2026Set3rdPlaceButton()
        }
    }

    // MARK: - Phase 2: Lock Control

    private var phase2LockSection: some View {
        Section(header: Text("Phase 2 — Lock Control")) {
            HStack {
                Text("Phase 2 Status")
                Spacer()
                KOStatusBadge(status: knockoutStore.results.knockoutStatus)
            }

            // Open → Lock button
            if knockoutStore.results.knockoutStatus == .open {
                Button {
                    Task { try? await knockoutStore.setKnockoutStatus(.locked) }
                } label: {
                    Label("Lock Phase 2 (Reveal Picks)", systemImage: "lock.fill")
                        .foregroundStyle(.red)
                }
            }

            // Locked → Re-open + Finalize buttons
            if knockoutStore.results.knockoutStatus == .locked {
                Button {
                    Task { try? await knockoutStore.setKnockoutStatus(.open) }
                } label: {
                    Label("Re-Open Phase 2 (Hide Picks)", systemImage: "lock.open.fill")
                        .foregroundStyle(.green)
                }
                Button {
                    Task { try? await knockoutStore.setKnockoutStatus(.finalized) }
                } label: {
                    Label("Finalize Phase 2", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.blue)
                }
            }

            // Finalized state
            if knockoutStore.results.knockoutStatus == .finalized {
                HStack {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue)
                    Text("Phase 2 Finalized").fontWeight(.semibold)
                }
            }

            Text("Unlock lets players submit picks (private). Lock reveals all picks and closes submissions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Phase 2: Match Results

    @ViewBuilder
    private var phase2ResultsSections: some View {
        ForEach(knockoutStore.matchesByRound()) { group in
            Section(header: Text("Phase 2 — \(group.round.displayName) Results")) {
                ForEach(group.matches, id: \.id) { match in
                    KOAdminMatchRow(
                        match: match,
                        team1Id: knockoutStore.resolvedTeam1Id(for: match, phase1Results: resultsStore.results),
                        team2Id: knockoutStore.resolvedTeam2Id(for: match, phase1Results: resultsStore.results),
                        teams: picksStore.teams,
                        winnerId: knockoutStore.results.winnerId(for: match.id),
                        locked: knockoutStore.results.knockoutStatus == .finalized,
                        onSelect: { winnerId in
                            Task { try? await knockoutStore.setMatchResult(matchId: match.id, winnerId: winnerId) }
                        },
                        onClear: {
                            Task { try? await knockoutStore.clearMatchResult(matchId: match.id) }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Live Scores Preview

    @ViewBuilder
    private var liveScoresSection: some View {
        Section(header: Text("Live Scores Preview")) {
            ForEach(scoresStore.playerRows.prefix(10)) { row in
                AdminScoreRow(displayName: row.displayName, total: row.total)
            }
            if scoresStore.playerRows.count > 10 {
                Text("+ \(scoresStore.playerRows.count - 10) more — see Leaderboard tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func otherResultIds(group: WCGroup, excluding slot: WCGroupSlot) -> [String] {
        WCGroupSlot.allCases
            .filter { $0 != slot }
            .compactMap { resultsStore.results.result(for: group).teamId(forSlot: $0) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Actions

    private func changeStatus(_ status: WCTournamentStatus) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await resultsStore.setStatus(status)
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func finalizeChallenge() async {
        guard !resultsStore.results.isFinalized else {
            alertMessage = "Already finalized."
            showAlert = true
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let scoresByPlayer: [String: Double] = Dictionary(
                uniqueKeysWithValues: scoresStore.playerRows.map { ($0.linkedPlayerId, Double($0.total)) }
            )
            let finalizer = ChallengePointsFinalizer()
            try await finalizer.finalizeChallenge(
                challengeId: challengeId,
                scoresByPlayer: scoresByPlayer,
                multiplier: multiplier,
                higherIsBetter: true
            )
            let by = session.profile?.displayName ?? "Admin"
            try await resultsStore.finalizeResults(scoreRows: scoresStore.playerRows, finalizedBy: by)
            alertMessage = "Finalized! Points awarded to all players."
            showAlert = true
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}

// MARK: - Small extracted views (keeps type-checker happy)

private struct WCStatusBadge: View {
    let status: WCTournamentStatus

    var body: some View {
        Label(status.displayName, systemImage: iconName)
            .font(.caption.bold())
            .foregroundStyle(badgeColor)
    }

    private var iconName: String {
        switch status {
        case .open:      return "lock.open"
        case .locked:    return "lock.fill"
        case .finalized: return "checkmark.seal.fill"
        }
    }

    private var badgeColor: Color {
        switch status {
        case .open:      return .green
        case .locked:    return .red
        case .finalized: return .blue
        }
    }
}

private struct WCFinalizedRow: View {
    let finalizedAt: Date?
    let finalizedBy: String?

    var body: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Finalized").fontWeight(.semibold)
                if let at = finalizedAt {
                    Text(at.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let by = finalizedBy, !by.isEmpty {
                    Text("By \(by)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct AdminScoreRow: View {
    let displayName: String
    let total: Int

    var body: some View {
        HStack {
            Text(displayName)
            Spacer()
            Text("\(total) pts")
                .fontWeight(.semibold)
                .foregroundStyle(total >= 0 ? Color.primary : Color.red)
        }
    }
}

// MARK: - Phase 2 Admin Helpers

private struct KOStatusBadge: View {
    let status: WCKnockoutStatus

    var body: some View {
        Label(status.displayName, systemImage: icon)
            .font(.caption.bold())
            .foregroundStyle(color)
    }

    private var icon: String {
        switch status {
        case .open:      return "lock.open"
        case .locked:    return "lock.fill"
        case .finalized: return "checkmark.seal.fill"
        }
    }

    private var color: Color {
        switch status {
        case .open:      return .green
        case .locked:    return .red
        case .finalized: return .blue
        }
    }
}

private struct KOAdminMatchRow: View {
    let match: WCKOMatch
    let team1Id: String?
    let team2Id: String?
    let teams: [WCTeam]
    let winnerId: String?
    let locked: Bool
    let onSelect: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        HStack {
            Text("M\(match.fifaMatchNumber)")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(teamLabel(id: team1Id, slot: match.team1Slot))
                    .font(.footnote)
                Text("vs \(teamLabel(id: team2Id, slot: match.team2Slot))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Winner picker menu
            Menu {
                if let id = team1Id {
                    Button { onSelect(id) } label: {
                        HStack {
                            if let flag = teams.first(where: { $0.id == id })?.flag { Text(flag) }
                            Text(teams.first(where: { $0.id == id })?.name ?? id)
                        }
                    }
                }
                if let id = team2Id {
                    Button { onSelect(id) } label: {
                        HStack {
                            if let flag = teams.first(where: { $0.id == id })?.flag { Text(flag) }
                            Text(teams.first(where: { $0.id == id })?.name ?? id)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if let wid = winnerId, !wid.isEmpty,
                       let flag = teams.first(where: { $0.id == wid })?.flag {
                        Text(flag)
                    }
                    Text(winnerLabel)
                        .font(.footnote)
                        .fontWeight(winnerId != nil ? .semibold : .regular)
                        .foregroundStyle(winnerId != nil ? .primary : .secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(locked || (team1Id == nil && team2Id == nil))

            if let w = winnerId, !w.isEmpty, !locked {
                Button(action: onClear) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var winnerLabel: String {
        guard let wid = winnerId, !wid.isEmpty else { return "Set winner…" }
        return teams.first(where: { $0.id == wid })?.name ?? wid
    }

    private func teamLabel(id: String?, slot: String) -> String {
        if let id, let team = teams.first(where: { $0.id == id }) {
            return "\(team.flag ?? "") \(team.name)"
        }
        return slot   // show "3rd-ABCDF" etc. when TBD
    }
}

// MARK: - Admin Group Slot Row

private struct AdminGroupSlotRow: View {
    let slot: WCGroupSlot
    let teams: [WCTeam]
    let selectedId: String?
    let disabledIds: [String]
    let locked: Bool
    let onSelect: (String) -> Void
    let onClear: (() -> Void)?

    var body: some View {
        HStack {
            Text(slot.rawValue)
                .font(.footnote.bold())
                .foregroundStyle(slotColor)
                .frame(width: 32, alignment: .leading)
            Spacer()
            Menu {
                ForEach(teams) { team in
                    Button { onSelect(team.id) } label: {
                        HStack {
                            if let flag = team.flag { Text(flag) }
                            Text(team.name)
                        }
                    }
                    .disabled(disabledIds.contains(team.id))
                }
            } label: {
                menuLabel
            }
            .disabled(locked)

            if let id = selectedId, !id.isEmpty, !locked {
                Button {
                    onClear?()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var menuLabel: some View {
        HStack(spacing: 6) {
            if let id = selectedId, !id.isEmpty,
               let flag = teams.first(where: { $0.id == id })?.flag {
                Text(flag)
            }
            Text(displayText)
                .fontWeight(selectedId != nil ? .semibold : .regular)
                .foregroundStyle(selectedId != nil ? Color.primary : Color.secondary)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(Color.secondary)
        }
    }

    private var displayText: String {
        guard let id = selectedId, !id.isEmpty else { return "Set result…" }
        return teams.first(where: { $0.id == id })?.name ?? id
    }

    private var slotColor: Color {
        switch slot {
        case .first:  return .yellow
        case .second: return .gray
        case .third:  return .orange
        case .fourth: return .red
        }
    }
}
