import SwiftUI

struct NFLBracketLeaderboardView: View {
    @ObservedObject var scoresStore: NFLPlayoffsScoresStore
    let session: SessionStore

    @State private var group: NFLPlayoffsScoresStore.Group = .groomsmen

    private var filteredSorted: [BracketScoreRow] {
        let filtered = scoresStore.scores.filter {
            scoresStore.groupForPlayerId($0.linkedPlayerId) == group
        }
        return filtered.sorted {
            if $0.points != $1.points { return $0.points > $1.points }
            return $0.displayName < $1.displayName
        }
    }

    private var ranked: [(row: BracketScoreRow, rank: Int)] {
        filteredSorted.enumerated().map { ($0.element, $0.offset + 1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Leaderboard")
                .font(.title2.bold())

            Picker("Group", selection: $group) {
                Text("Groomsmen").tag(NFLPlayoffsScoresStore.Group.groomsmen)
                Text("Admins").tag(NFLPlayoffsScoresStore.Group.admin)
            }
            .pickerStyle(.segmented)

            Text(group == .groomsmen
                 ? "Groomsmen totals across all rounds"
                 : "Admin bracket totals across all rounds")
            .font(.footnote)
            .foregroundStyle(.secondary)

            if let err = scoresStore.errorMessage {
                Text("Couldn’t load: \(err)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if scoresStore.isLoading {
                ProgressView("Loading scores...")
                    .padding(.top, 8)
            }

            List {
                ForEach(ranked, id: \.row.id) { entry in
                    let isMe = (session.profile?.linkedPlayerId == entry.row.linkedPlayerId)

                    HStack {
                        Text("\(entry.rank)")
                            .frame(width: 26, alignment: .leading)

                        Text(entry.row.displayName)
                            .fontWeight(isMe ? .bold : .regular)

                        Spacer()

                        Text("\(entry.row.points)")
                            .fontWeight(isMe ? .bold : .regular)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .listRowBackground(Color.clear)
                }

                if ranked.isEmpty {
                    Text(group == .admin
                         ? "No admin picks yet."
                         : "No picks yet.")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
        }
        .padding(.top, 8)
        .onAppear {
            scoresStore.startListening()
        }

    }
}
