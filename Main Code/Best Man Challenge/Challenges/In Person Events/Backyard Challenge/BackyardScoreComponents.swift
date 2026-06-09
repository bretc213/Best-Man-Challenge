import SwiftUI

struct BackyardScoreRow: View {
    let rank: Int
    let row: BackyardStandingRow
    let showThru: Bool
    var rawLabel: String = "Score"

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.headline)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.displayName)
                        .font(.headline)

                    if row.playerId == "bret" {
                        Text("Host")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                if showThru, let thru = row.thru {
                    Text("Thru \(thru)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if row.playerId == "bret" {
                    Text("No tournament award")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(scoreText)
                    .font(rawLabel == "BYPoints" ? .title3 : .headline)
                    .fontWeight(rawLabel == "BYPoints" ? .bold : .regular)

                if shouldShowSubtext {
                    Text(subtext)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var shouldShowSubtext: Bool {
        if rawLabel == "Golf" { return false }
        if rawLabel == "BYPoints" { return !subtext.isEmpty }
        return true
    }

    private var subtext: String {
        if rawLabel == "BYPoints" {
            switch rank {
            case 1: return "+5 BM Points"
            case 2: return "+3 BM Points"
            case 3: return "+1 BM Point"
            default: return ""
            }
        }

        return "\(row.points) BY pts"
    }

    private var scoreText: String {
        if rawLabel == "BYPoints" {
            return "\(row.points)"
        }

        if rawLabel == "Golf" {
            let score = Int(row.rawScore)
            if score == 0 { return "E" }
            if score > 0 { return "+\(score)" }
            return "\(score)"
        }

        if rawLabel == "Place" {
            if row.rawScore <= 0 { return "--" }
            return "\(Int(row.rawScore))"
        }

        if row.rawScore.rounded() == row.rawScore {
            return "\(Int(row.rawScore))"
        } else {
            return String(format: "%.1f", row.rawScore)
        }
    }
}

struct BackyardLeaderboardList: View {
    let rows: [BackyardStandingRow]
    let showThru: Bool
    var rawLabel: String = "Score"

    var body: some View {
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
            BackyardScoreRow(
                rank: index + 1,
                row: row,
                showThru: showThru,
                rawLabel: rawLabel
            )
        }
    }
}

struct BackyardPriorityDeclarationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Priority Declaration")
                .font(.headline)

            Text("Players are responsible for keeping the flow moving.")
                .font(.subheadline)

            Text("Priority order: QB54 → Cornhole → Ladder Ball")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("Find your opponent, play immediately when your match is ready, and report the score.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
