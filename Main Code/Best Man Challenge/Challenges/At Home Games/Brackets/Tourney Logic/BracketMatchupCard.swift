//
//  BracketMatchupCard.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/31/26.
//


import SwiftUI

struct BracketMatchupCard: View {
    enum Tint {
        case none
        case green
        case red
    }

    let matchup: TourneyMatchup
    let teamsById: [String: TourneyTeam]

    // Current selection for THIS matchup (user's pick)
    let userPickTeamId: String?
    let isLocked: Bool

    // Derived display (projection / winners)
    let homeDisplayTeamId: String?
    let awayDisplayTeamId: String?
    let homeTint: Tint
    let awayTint: Tint

    // NEW: tap handlers (nil means not selectable)
    let onSelectHome: (() -> Void)?
    let onSelectAway: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Round \(matchup.round) • Game \(matchup.gameNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                teamChip(
                    teamId: homeDisplayTeamId,
                    tint: homeTint,
                    isSelected: (userPickTeamId != nil && userPickTeamId == homeDisplayTeamId),
                    onTap: onSelectHome
                )

                Text("vs")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                teamChip(
                    teamId: awayDisplayTeamId,
                    tint: awayTint,
                    isSelected: (userPickTeamId != nil && userPickTeamId == awayDisplayTeamId),
                    onTap: onSelectAway
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func teamChip(
        teamId: String?,
        tint: Tint,
        isSelected: Bool,
        onTap: (() -> Void)?
    ) -> some View {
        let teamName = teamId.flatMap { teamsById[$0]?.name } ?? "TBD"

        let bg: Color = {
            switch tint {
            case .green: return Color.green.opacity(0.25)
            case .red: return Color.red.opacity(0.22)
            case .none: return Color.black.opacity(0.10)
            }
        }()

        let stroke: Color = {
            if isSelected {
                return Color.accent.opacity(0.90)
            }
            switch tint {
            case .green: return Color.green.opacity(0.85)
            case .red: return Color.red.opacity(0.85)
            case .none: return Color.white.opacity(0.10)
            }
        }()

        let canTap = (!isLocked && teamId != nil && onTap != nil)

        Button {
            if canTap { onTap?() }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 22, height: 22)

                Text(teamName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accent)
                        .opacity(0.95)
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .opacity(0.55)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(bg)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(stroke, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .opacity(canTap ? 1.0 : 0.92)
        }
        .buttonStyle(.plain)
        .disabled(!canTap)
    }
}
