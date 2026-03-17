import SwiftUI

struct MLBFuturesStandingsView: View {
    @ObservedObject var store: MLBFuturesStore

    var body: some View {
        List {

            if let adminState = store.adminState {

                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)

                        Text("Last updated: \(formatted(adminState.updatedAt.dateValue()))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }

            Section {
                ForEach(Array(store.leaderboard.enumerated()), id: \.element.id) { index, row in

                    VStack(alignment: .leading, spacing: 6) {

                        HStack {
                            Text("#\(index + 1)")
                                .font(.headline)

                            Text(row.displayName)
                                .font(.headline)

                            Spacer()

                            Text("\(row.totalPoints) pts")
                                .font(.headline)
                        }

                        Text(
                            "Div \(row.divisionPoints) • " +
                            "Seeds \(row.seedingPoints) • " +
                            "DS \(row.dsPoints) • " +
                            "CS \(row.csPoints) • " +
                            "WS \(row.wsPoints) • " +
                            "Champ \(row.championPoints)"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Standings")
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
