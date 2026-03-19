import SwiftUI

struct MLBFuturesAllPicksView: View {
    @ObservedObject var store: MLBFuturesStore
    @State private var expandedPlayerId: String?

    var body: some View {
        Group {
            if !store.allPicksAreVisible {
                ContentUnavailableView(
                    "All Picks Locked",
                    systemImage: "lock.fill",
                    description: Text(lockMessage)
                )
                .padding(.horizontal)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        if store.picks.isEmpty {
                            ContentUnavailableView(
                                "No Picks Yet",
                                systemImage: "person.3",
                                description: Text("Player picks will appear here once submitted.")
                            )
                            .padding(.top, 40)
                        } else {
                            ForEach(store.picks.sorted(by: { $0.displayName < $1.displayName }), id: \.userId) { pick in
                                VStack(spacing: 0) {
                                    Button {
                                        withAnimation(.easeInOut) {
                                            if expandedPlayerId == pick.userId {
                                                expandedPlayerId = nil
                                            } else {
                                                expandedPlayerId = pick.userId
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(pick.displayName)
                                                .font(.headline)

                                            Spacer()

                                            Image(systemName: expandedPlayerId == pick.userId ? "chevron.up" : "chevron.down")
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding()
                                    }
                                    .buttonStyle(.plain)

                                    if expandedPlayerId == pick.userId {
                                        VStack(alignment: .leading, spacing: 20) {
                                            divisionView(title: "AL East", teams: pick.alEast)
                                            divisionView(title: "AL Central", teams: pick.alCentral)
                                            divisionView(title: "AL West", teams: pick.alWest)

                                            divisionView(title: "NL East", teams: pick.nlEast)
                                            divisionView(title: "NL Central", teams: pick.nlCentral)
                                            divisionView(title: "NL West", teams: pick.nlWest)

                                            numberedListView(title: "AL Seeds", teams: pick.alSeeds)
                                            numberedListView(title: "NL Seeds", teams: pick.nlSeeds)

                                            bulletedListView(title: "ALDS", teams: pick.aldsTeams)
                                            bulletedListView(title: "NLDS", teams: pick.nldsTeams)

                                            bulletedListView(title: "ALCS", teams: pick.alcsTeams)
                                            bulletedListView(title: "NLCS", teams: pick.nlcsTeams)

                                            bulletedListView(title: "World Series", teams: pick.worldSeriesTeams)

                                            championView(teamId: pick.worldSeriesWinner)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color(.secondarySystemBackground))
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.top)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("All Picks")
    }

    private var lockMessage: String {
        if let locksAt = store.locksAtDate {
            return "Everyone's picks unlock at \(formatted(locksAt))."
        }
        return "Everyone's picks will unlock once the challenge locks."
    }

    @ViewBuilder
    private func divisionView(title: String, teams: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            ForEach(Array(teams.enumerated()), id: \.offset) { index, teamId in
                Text("\(index + 1). \(MLBFuturesConstants.teamName(teamId))")
            }
        }
    }

    @ViewBuilder
    private func numberedListView(title: String, teams: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            ForEach(Array(teams.enumerated()), id: \.offset) { index, teamId in
                Text("\(index + 1). \(MLBFuturesConstants.teamName(teamId))")
            }
        }
    }

    @ViewBuilder
    private func bulletedListView(title: String, teams: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            ForEach(teams, id: \.self) { teamId in
                Text("• \(MLBFuturesConstants.teamName(teamId))")
            }
        }
    }

    @ViewBuilder
    private func championView(teamId: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Champion")
                .font(.headline)

            Text("🏆 \(MLBFuturesConstants.teamName(teamId))")
                .font(.body.weight(.semibold))
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
