//
//  WorldCup2026KnockoutPicksView.swift
//  Best Man Challenge
//
//  Phase 2 player UI: pick the winner of every knockout match.
//  Picks are hidden from other players while the phase is unlocked;
//  once the admin locks Phase 2, all picks become visible.
//  Owners/execs can always browse any player's picks, even when unlocked.

import SwiftUI

struct WorldCup2026KnockoutPicksView: View {
    @ObservedObject var picksStore: WorldCup2026PicksStore
    @ObservedObject var knockoutStore: WorldCup2026KnockoutStore
    @ObservedObject var resultsStore: WorldCup2026ResultsStore
    let session: SessionStore

    /// When exec taps a player name, this overrides the displayed entry.
    @State private var viewingEntry: WCEntry? = nil

    private var isExec: Bool {
        let role = (session.profile?.role ?? "").lowercased()
        return ["owner", "commish", "ref", "admin", "exec"].contains(role)
    }

    private var myLinkedId: String { session.profile?.linkedPlayerId ?? "" }

    /// The entry whose picks are displayed in the bracket.
    private var displayedEntry: WCEntry? {
        viewingEntry ?? picksStore.myEntry
    }

    var body: some View {
        List {
            // Status banner
            Section {
                KOStatusBanner(
                    knockoutResults: knockoutStore.results,
                    picksCount: pickedCount,
                    totalMatches: knockoutStore.matches.count,
                    viewingName: viewingEntry?.displayName
                )
            }

            // Exec-only: player picker — visible at all times regardless of lock state
            if isExec {
                Section(header: Text("View Player Picks")) {
                    ForEach(picksStore.allEntries, id: \.id) { entry in
                        KOPlayerPickerRow(
                            entry: entry,
                            isMe: entry.linkedPlayerId == myLinkedId,
                            isViewing: viewingEntry?.id == entry.id,
                            koPickCount: entry.knockoutPicks.values.filter { !$0.isEmpty }.count,
                            totalMatches: knockoutStore.matches.count
                        ) {
                            viewingEntry = (viewingEntry?.id == entry.id) ? nil : entry
                        }
                    }
                    if picksStore.allEntries.isEmpty {
                        Text("No entries yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Round-by-round matchup sections
            ForEach(knockoutStore.matchesByRound()) { group in
                Section(header: KORoundHeader(round: group.round)) {
                    ForEach(group.matches, id: \.id) { match in
                        KOMatchPickRow(
                            match: match,
                            team1Id: knockoutStore.resolvedTeam1IdForPlayer(for: match, phase1Results: resultsStore.results, playerPicks: displayedEntry?.knockoutPicks ?? [:]),
                            team2Id: knockoutStore.resolvedTeam2IdForPlayer(for: match, phase1Results: resultsStore.results, playerPicks: displayedEntry?.knockoutPicks ?? [:]),
                            teams: picksStore.teams,
                            myPickId: displayedEntry?.knockoutPicks[match.id],
                            actualWinnerId: knockoutStore.results.winnerId(for: match.id),
                            isLocked: knockoutStore.results.knockoutIsLocked || isViewingOtherPlayer,
                            onPick: { teamId in
                                guard !isViewingOtherPlayer else { return }
                                Task { try? await picksStore.setKnockoutPick(matchId: match.id, teamId: teamId) }
                            },
                            onClear: {
                                guard !isViewingOtherPlayer else { return }
                                Task { try? await picksStore.setKnockoutPick(matchId: match.id, teamId: "") }
                            }
                        )
                    }
                }
            }

            if knockoutStore.matches.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Bracket Not Yet Available", systemImage: "clock")
                            .font(.footnote.bold())
                            .foregroundStyle(.orange)
                        Text("The admin will seed the knockout bracket once all 32 teams are confirmed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(navTitle)
    }

    // MARK: - Helpers

    private var isViewingOtherPlayer: Bool {
        viewingEntry != nil && viewingEntry?.linkedPlayerId != myLinkedId
    }

    private var navTitle: String {
        if let name = viewingEntry?.displayName, isViewingOtherPlayer {
            return "\(name)'s Picks"
        }
        return "Knockout Bracket"
    }

    private var pickedCount: Int {
        guard let entry = displayedEntry else { return 0 }
        return knockoutStore.matches.filter { match in
            let pick = entry.knockoutPicks[match.id] ?? ""
            return !pick.isEmpty
        }.count
    }
}

// MARK: - Player Picker Row (exec-only)

private struct KOPlayerPickerRow: View {
    let entry: WCEntry
    let isMe: Bool
    let isViewing: Bool
    let koPickCount: Int
    let totalMatches: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(entry.displayName)
                    .fontWeight(isMe ? .semibold : .regular)
                if isMe {
                    Text("(You)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(koPickCount)/\(totalMatches)")
                    .font(.caption)
                    .foregroundStyle(koPickCount == totalMatches ? Color.green : Color.secondary)
                if isViewing {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Status Banner

private struct KOStatusBanner: View {
    let knockoutResults: WCKnockoutResults
    let picksCount: Int
    let totalMatches: Int
    let viewingName: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.footnote.bold())
                if totalMatches > 0 {
                    if let name = viewingName {
                        Text("Viewing \(name)'s picks — \(picksCount)/\(totalMatches) submitted")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(picksCount) / \(totalMatches) matches picked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var icon: String {
        switch knockoutResults.knockoutStatus {
        case .open:      return "lock.open"
        case .locked:    return "lock.fill"
        case .finalized: return "checkmark.seal.fill"
        }
    }

    private var iconColor: Color {
        switch knockoutResults.knockoutStatus {
        case .open:      return .green
        case .locked:    return .red
        case .finalized: return .blue
        }
    }

    private var statusText: String {
        switch knockoutResults.knockoutStatus {
        case .open:      return "Phase 2 open — picks are private until locked"
        case .locked:    return "Phase 2 locked — picks visible to all"
        case .finalized: return "Phase 2 finalized"
        }
    }
}

// MARK: - Round Header

private struct KORoundHeader: View {
    let round: WCKORound

    var body: some View {
        HStack {
            Text(round.displayName)
                .fontWeight(.semibold)
            Spacer()
            Text("+\(round.points) pts")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Match Pick Row

private struct KOMatchPickRow: View {
    let match: WCKOMatch
    let team1Id: String?
    let team2Id: String?
    let teams: [WCTeam]
    let myPickId: String?
    let actualWinnerId: String?
    let isLocked: Bool
    let onPick: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("M\(match.fifaMatchNumber)")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)

            KOTeamButton(
                teamId: team1Id,
                slot: match.team1Slot,
                teams: teams,
                isMyPick: myPickId == team1Id && team1Id != nil,
                isActualWinner: actualWinnerId != nil && actualWinnerId == team1Id,
                isWrongPick: myPickId == team1Id && actualWinnerId != nil && actualWinnerId != team1Id,
                disabled: isLocked || team1Id == nil
            ) {
                if let id = team1Id { onPick(id) }
            }

            Text("vs")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            KOTeamButton(
                teamId: team2Id,
                slot: match.team2Slot,
                teams: teams,
                isMyPick: myPickId == team2Id && team2Id != nil,
                isActualWinner: actualWinnerId != nil && actualWinnerId == team2Id,
                isWrongPick: myPickId == team2Id && actualWinnerId != nil && actualWinnerId != team2Id,
                disabled: isLocked || team2Id == nil
            ) {
                if let id = team2Id { onPick(id) }
            }

            if let pick = myPickId, !pick.isEmpty, !isLocked {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Team Button

private struct KOTeamButton: View {
    let teamId: String?
    let slot: String
    let teams: [WCTeam]
    let isMyPick: Bool
    let isActualWinner: Bool
    let isWrongPick: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let id = teamId, let flag = teams.first(where: { $0.id == id })?.flag {
                    Text(flag).font(.body)
                }
                Text(displayLabel)
                    .font(.footnote)
                    .fontWeight(isMyPick ? .bold : .regular)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: isMyPick ? 2 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled && !isMyPick ? 0.6 : 1.0)
    }

    private var displayLabel: String {
        if let id = teamId {
            return teams.first(where: { $0.id == id })?.abbr ?? id
        }
        return slot
    }

    private var background: Color {
        if isActualWinner { return Color.green.opacity(0.15) }
        if isWrongPick    { return Color.red.opacity(0.10) }
        if isMyPick       { return Color.accentColor.opacity(0.15) }
        return Color(.secondarySystemFill)
    }

    private var foreground: Color {
        if isActualWinner { return .green }
        if isWrongPick    { return .red }
        if isMyPick       { return .accentColor }
        return .primary
    }

    private var borderColor: Color {
        if isActualWinner { return .green }
        if isWrongPick    { return .red }
        if isMyPick       { return .accentColor }
        return Color.gray.opacity(0.3)
    }
}
