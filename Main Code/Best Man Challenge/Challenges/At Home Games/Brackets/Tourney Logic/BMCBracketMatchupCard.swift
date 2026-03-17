
//  BMCBracketMatchupCard.swift
//  Best Man Challenge
//
//  Updated UI:
//  - Removes the checkmark so names have more room
//  - Shows the seed in a small badge
//  - Increases logo size slightly
//  - Lets team names use up to 2 lines
//  - Tweaks spacing to feel more like ESPN / CBS bracket chips
//

import SwiftUI

struct BMCBracketMatchupCard: View {
    enum Tint {
        case none
        case green
        case red
    }

    let matchup: BMCBracketMatchup
    let teamsById: [String: BMCBracketTeam]

    let userPickTeamId: String?
    let isLocked: Bool

    let homeDisplayTeamId: String?
    let awayDisplayTeamId: String?
    let homeTint: Tint
    let awayTint: Tint

    let onSelectHome: (() -> Void)?
    let onSelectAway: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    .frame(minWidth: 28)

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
        let team = teamId.flatMap { teamsById[$0] }
        let teamName = team?.name ?? "TBD"
        let seed = team?.seed

        let bg: Color = {
            switch tint {
            case .green: return Color.green.opacity(0.25)
            case .red: return Color.red.opacity(0.22)
            case .none: return Color.black.opacity(0.10)
            }
        }()

        let stroke: Color = {
            if isSelected {
                return Color.accent.opacity(0.95)
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
            HStack(alignment: .center, spacing: 10) {
                teamLogo(for: team)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if let seed {
                            seedBadge(seed)
                        }

                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .opacity(0.7)
                        }
                    }

                    Text(teamName)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .background(bg)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(stroke, lineWidth: isSelected ? 2.2 : 1.6)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .opacity(canTap ? 1.0 : 0.96)
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!canTap)
    }

    @ViewBuilder
    private func teamLogo(for team: BMCBracketTeam?) -> some View {
        if let team,
           let logo = team.logoAsset,
           !logo.isEmpty {
            Image(logo)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 28, height: 28)
        }
    }

    @ViewBuilder
    private func seedBadge(_ seed: Int) -> some View {
        Text("#\(seed)")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.10))
            .clipShape(Capsule())
    }
}
