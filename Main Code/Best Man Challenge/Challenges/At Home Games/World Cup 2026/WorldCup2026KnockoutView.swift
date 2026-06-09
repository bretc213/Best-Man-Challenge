//
//  WorldCup2026KnockoutView.swift
//  Best Man Challenge
//
//  Phase 1: Shows which teams qualified from each group (auto-populated as admin sets results).
//  Phase 2 (future): Full R32 bracket picks.

import SwiftUI

struct WorldCup2026KnockoutView: View {
    @ObservedObject var picksStore: WorldCup2026PicksStore
    @ObservedObject var resultsStore: WorldCup2026ResultsStore

    var body: some View {
        List {
            // Status
            Section {
                HStack {
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusColor)
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // Group qualifiers
            ForEach(WCGroup.allCases) { group in
                let result = resultsStore.results.result(for: group)
                let t1 = result.teamId(forSlot: .first)
                let t2 = result.teamId(forSlot: .second)
                let t3 = result.teamId(forSlot: .third)

                Section(header: Text("Group \(group.rawValue)")) {
                    QualifierRow(
                        slot: "1st",
                        teamId: t1,
                        label: picksStore.teamName(t1),
                        flag: picksStore.teamFlag(t1),
                        advances: true
                    )
                    QualifierRow(
                        slot: "2nd",
                        teamId: t2,
                        label: picksStore.teamName(t2),
                        flag: picksStore.teamFlag(t2),
                        advances: true
                    )
                    QualifierRow(
                        slot: "3rd",
                        teamId: t3,
                        label: picksStore.teamName(t3),
                        flag: picksStore.teamFlag(t3),
                        advances: false   // may advance as best 3rd — admin decides
                    )
                    QualifierRow(
                        slot: "4th",
                        teamId: result.teamId(forSlot: .fourth),
                        label: picksStore.teamName(result.teamId(forSlot: .fourth)),
                        flag: picksStore.teamFlag(result.teamId(forSlot: .fourth)),
                        advances: false
                    )
                }
            }

            // Phase 2 teaser
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Knockout Picks — Coming in Phase 2", systemImage: "trophy.fill")
                        .font(.footnote.bold())
                        .foregroundStyle(.blue)
                    Text("Once the group stage is complete and locked, you'll be able to fill out your full 32-team knockout bracket here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Knockout Round")
    }

    // MARK: - Status helpers

    private var statusIcon: String {
        switch resultsStore.results.status {
        case .open:      return "clock"
        case .locked:    return "lock.fill"
        case .finalized: return "checkmark.seal.fill"
        }
    }

    private var statusColor: Color {
        switch resultsStore.results.status {
        case .open:      return .orange
        case .locked:    return .red
        case .finalized: return .blue
        }
    }

    private var statusMessage: String {
        switch resultsStore.results.status {
        case .open:
            let filled = WCGroup.allCases.filter { g in
                let r = resultsStore.results.result(for: g)
                return r.teamId(forSlot: .first) != nil
            }.count
            if filled == 0 {
                return "Group results will appear as the admin enters them."
            } else {
                return "\(filled) of 12 groups have results entered."
            }
        case .locked:
            return "Group stage locked. Knockout bracket being generated."
        case .finalized:
            return "Tournament finalized."
        }
    }
}

// MARK: - Qualifier Row

private struct QualifierRow: View {
    let slot: String
    let teamId: String?
    let label: String
    let flag: String?
    let advances: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Position badge
            Text(slot)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)

            if let flag {
                Text(flag)
                    .font(.title3)
            }

            Text(teamId != nil ? label : "TBD")
                .foregroundStyle(teamId != nil ? .primary : .secondary)

            Spacer()

            if teamId != nil {
                if advances {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else if slot == "3rd" {
                    Text("May advance")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}
