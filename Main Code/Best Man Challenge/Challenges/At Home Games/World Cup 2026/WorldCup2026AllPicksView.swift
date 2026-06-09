//
//  WorldCup2026AllPicksView.swift
//  Best Man Challenge
//
//  Shows the picks of all players.
//  - Before lock: each player can only see their own picks.
//  - After lock: everyone can tap any player's name and see their full picks.

import SwiftUI

struct WorldCup2026AllPicksView: View {
    @ObservedObject var picksStore: WorldCup2026PicksStore
    @ObservedObject var resultsStore: WorldCup2026ResultsStore
    let session: SessionStore

    @State private var selectedEntry: WCEntry? = nil

    private var isLocked: Bool { picksStore.isLocked }

    private var myLinkedId: String {
        session.profile?.linkedPlayerId ?? ""
    }

    var body: some View {
        List {
            Section {
                if isLocked {
                    Label("Picks are locked — tap any player to see their selections.", systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Picks unlock for viewing once the tournament is locked by the admin.", systemImage: "eye.slash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section(header: Text("Players")) {
                ForEach(picksStore.allEntries) { entry in
                    let isMe = entry.linkedPlayerId == myLinkedId

                    if isLocked || isMe {
                        Button {
                            selectedEntry = entry
                        } label: {
                            HStack {
                                Text(entry.displayName)
                                    .fontWeight(isMe ? .bold : .regular)
                                if isMe {
                                    Text("(You)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                let filled = picksStore.filledSlotsCount(entry: entry)
                                Text("\(filled)/48")
                                    .font(.caption)
                                    .foregroundStyle(filled == 48 ? .green : .secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack {
                            Text(entry.displayName)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "lock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("All Picks")
        .sheet(item: $selectedEntry) { entry in
            PlayerPickDetailView(
                entry: entry,
                picksStore: picksStore,
                resultsStore: resultsStore
            )
        }
    }
}

// MARK: - Player Pick Detail

struct PlayerPickDetailView: View {
    let entry: WCEntry
    @ObservedObject var picksStore: WorldCup2026PicksStore
    @ObservedObject var resultsStore: WorldCup2026ResultsStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                // Summary header
                Section {
                    HStack {
                        Text("Slots filled")
                        Spacer()
                        let filled = picksStore.filledSlotsCount(entry: entry)
                        Text("\(filled) / 48")
                            .fontWeight(.semibold)
                    }
                }

                ForEach(WCGroup.allCases) { group in
                    Section(header: Text("Group \(group.rawValue)")) {
                        ForEach(WCGroupSlot.allCases) { slot in
                            let pickedId = entry.pick(group: group, slot: slot)
                            let actual = resultsStore.results.result(for: group).teamId(forSlot: slot)
                            let hasResult = actual != nil

                            HStack(spacing: 10) {
                                // Rank label
                                Text(slot.rawValue)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .leading)

                                // Flag + team
                                if let id = pickedId, !id.isEmpty {
                                    if let flag = picksStore.teamFlag(id) {
                                        Text(flag)
                                    }
                                    Text(picksStore.teamName(id))
                                } else {
                                    Text("—")
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                // Score indicator (only if result known)
                                if hasResult, let pickedId, !pickedId.isEmpty,
                                   let actualRank = resultsStore.results.result(for: group).actualRank(teamId: pickedId) {
                                    let predictedRank = slot.rank
                                    let pts = WCScoreRow.positionPoints(predictedRank: predictedRank, actualRank: actualRank)
                                    scoreChip(pts)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(entry.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func scoreChip(_ pts: Int) -> some View {
        let color: Color = pts > 0 ? .green : (pts < 0 ? .red : .secondary)
        let label = pts > 0 ? "+\(pts)" : "\(pts)"
        Text(label)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
