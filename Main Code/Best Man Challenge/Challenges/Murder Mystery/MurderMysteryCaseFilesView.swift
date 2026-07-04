//
//  MurderMysteryCaseFilesView.swift
//  Best Man Challenge
//
//  "Dead in the Dust" — evidence drops feed
//

import SwiftUI

struct MurderMysteryCaseFilesView: View {
    @ObservedObject var store: MurderMysteryStore
    @State private var expandedID: String?

    /// All drops, newest first; locked ones stay in the list as placeholders.
    private var sortedDrops: [Drop] {
        MurderMysteryData.drops.sorted {
            ($0.week, $0.isMidweek ? 1 : 0) > ($1.week, $1.isMidweek ? 1 : 0)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(sortedDrops) { drop in
                    if drop.week <= store.currentWeek {
                        unlockedCard(drop)
                    } else {
                        lockedCard(drop)
                    }
                }
            }
            .padding(16)
        }
        .background(Color.background)
    }

    // MARK: - Unlocked

    private func unlockedCard(_ drop: Drop) -> some View {
        let isExpanded = expandedID == drop.id
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(drop.isMidweek ? "WEEK \(drop.week) · MID-WEEK" : "WEEK \(drop.week) · MAJOR DROP")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.accent)
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(drop.title)
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
            Text(drop.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(isExpanded ? nil : 3)
            if isExpanded, let clue = drop.clueNote {
                Text(clue)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accent)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.accent.opacity(0.12)))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.1)))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.snappy) {
                expandedID = isExpanded ? nil : drop.id
            }
        }
    }

    // MARK: - Locked

    private func lockedCard(_ drop: Drop) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(drop.isMidweek ? "Week \(drop.week) — Mid-Week Drop" : "Week \(drop.week) — Major Drop")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Unlocks Week \(drop.week)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
        .opacity(0.6)
    }
}
