//
//  WorldCup2026GroupPicksView.swift
//  Best Man Challenge
//
//  Lets each player rank all 4 teams in every group (1st–4th).
//  Scoring reminder: +2 correct, +1 off-by-1, 0 off-by-2, -1 off-by-3.

import SwiftUI
import FirebaseAuth

struct WorldCup2026GroupPicksView: View {
    @ObservedObject var store: WorldCup2026PicksStore
    let session: SessionStore

    var body: some View {
        List {
            // Status banner
            Section {
                statusBanner
            }

            // Progress
            Section {
                let filled = store.filledSlotsCount(entry: store.myEntry)
                HStack {
                    Text("Slots filled")
                    Spacer()
                    Text("\(filled) / 48")
                        .fontWeight(.semibold)
                        .foregroundStyle(filled == 48 ? .green : .primary)
                }
            }

            // One section per group
            ForEach(WCGroup.allCases) { group in
                let teams = store.teamsByGroup[group] ?? []
                Section(header: Text("Group \(group.rawValue)")) {
                    ForEach(WCGroupSlot.allCases) { slot in
                        GroupSlotRow(
                            slot: slot,
                            teams: teams,
                            currentTeamId: store.myEntry?.pick(group: group, slot: slot),
                            takenIds: otherSlotPicks(group: group, excluding: slot),
                            locked: store.isLocked,
                            onSelect: { teamId in
                                Task { try? await store.setGroupPick(group: group, slot: slot, teamId: teamId) }
                            },
                            onClear: {
                                Task { try? await store.clearGroupPick(group: group, slot: slot) }
                            }
                        )
                    }
                }
            }

            // Scoring key
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scoring per team:")
                        .font(.footnote.bold())
                    Text("✅ Correct position → +2 pts")
                        .font(.footnote)
                    Text("1️⃣ Off by 1 spot → +1 pt")
                        .font(.footnote)
                    Text("2️⃣ Off by 2 spots → 0 pts")
                        .font(.footnote)
                    Text("❌ Off by 3 spots → -1 pt")
                        .font(.footnote)
                    Text("Max score: 96 pts (12 groups × 4 teams × 2)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Group Stage Picks")
    }

    // MARK: - Helpers

    @ViewBuilder
    private var statusBanner: some View {
        switch store.tournamentStatus {
        case .open:
            if let locksAt = store.locksAt {
                Label("Locks \(locksAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else {
                Label("Picks are open", systemImage: "lock.open")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        case .locked:
            Label("Picks are locked", systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(.red)
        case .finalized:
            Label("Tournament finalized", systemImage: "checkmark.seal.fill")
                .font(.footnote)
                .foregroundStyle(.blue)
        }
    }

    /// Returns all teamIds already picked for other slots in this group.
    private func otherSlotPicks(group: WCGroup, excluding slot: WCGroupSlot) -> [String] {
        WCGroupSlot.allCases
            .filter { $0 != slot }
            .compactMap { store.myEntry?.pick(group: group, slot: $0) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Group Slot Row

private struct GroupSlotRow: View {
    let slot: WCGroupSlot
    let teams: [WCTeam]
    let currentTeamId: String?
    let takenIds: [String]      // teams picked in other slots — excluded from this menu
    let locked: Bool
    let onSelect: (String) -> Void
    let onClear: () -> Void

    /// Only teams not already used in another slot
    private var availableTeams: [WCTeam] {
        teams.filter { !takenIds.contains($0.id) }
    }

    private var hasPick: Bool {
        currentTeamId?.isEmpty == false
    }

    var body: some View {
        HStack(spacing: 10) {
            // Rank badge
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(rankColor.opacity(0.15))
                Text(slot.rawValue)
                    .font(.caption.bold())
                    .foregroundStyle(rankColor)
            }
            .frame(width: 36, height: 26)

            Spacer()

            // Clear button — only visible when a pick exists and not locked
            if hasPick && !locked {
                Button {
                    onClear()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red.opacity(0.8))
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            // Team picker menu
            Menu {
                ForEach(availableTeams) { team in
                    Button {
                        onSelect(team.id)
                    } label: {
                        Text("\(team.flag ?? "") \(team.name)")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if let flag = flagForCurrentPick {
                        Text(flag).font(.title3)
                    }
                    Text(displayLabel)
                        .fontWeight(hasPick ? .semibold : .regular)
                        .foregroundStyle(hasPick ? Color.primary : Color.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
            }
            .disabled(locked)
        }
        .padding(.vertical, 2)
    }

    private var rankColor: Color {
        switch slot {
        case .first:  return .yellow
        case .second: return .gray
        case .third:  return .orange
        case .fourth: return .red
        }
    }

    private var displayLabel: String {
        guard let id = currentTeamId, !id.isEmpty else { return "Pick team…" }
        return teams.first(where: { $0.id == id })?.abbr ?? id
    }

    private var flagForCurrentPick: String? {
        guard let id = currentTeamId, !id.isEmpty else { return nil }
        return teams.first(where: { $0.id == id })?.flag
    }
}
