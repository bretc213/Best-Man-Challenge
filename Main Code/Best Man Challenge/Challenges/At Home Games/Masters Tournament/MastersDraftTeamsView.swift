import SwiftUI
import FirebaseFirestore

struct MastersDraftTeamsView: View {
    let gameRefId: String

    @State private var rosters: [MastersRoster] = []
    @State private var golfersById: [String: MastersGolfer] = [:]
    @State private var expanded: Set<String> = []
    @State private var errorMessage: String? = nil

    private let db = Firestore.firestore()

    var body: some View {
        ThemedScreen {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if rosters.isEmpty {
                    ContentUnavailableView(
                        "No teams yet",
                        systemImage: "person.3",
                        description: Text("Once the draft starts, each player roster will appear here.")
                    )
                    .padding(.vertical, 24)
                } else {
                    ForEach(sortedRosters) { roster in
                        DisclosureGroup(isExpanded: binding(for: roster.playerId)) {
                            ForEach(roster.picks, id: \.overallPick) { pick in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(pick.golferName)
                                            .font(.subheadline.weight(.semibold))

                                        if let golfer = golfersById[pick.golferId] {
                                            Text(detailLine(for: golfer))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if let golfer = golfersById[pick.golferId] {
                                        Text("\(golfer.leaderboardPoints) pts")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        } label: {
                            HStack {
                                Text(roster.displayName ?? roster.playerId)
                                    .font(.headline)
                                Spacer()
                                Text("\(roster.totalPoints) pts")
                                    .font(.headline)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Teams")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { Task { await load() } }
        }
    }

    private var sortedRosters: [MastersRoster] {
        rosters.sorted {
            if $0.totalPoints != $1.totalPoints { return $0.totalPoints > $1.totalPoints }
            return ($0.displayName ?? $0.playerId) < ($1.displayName ?? $1.playerId)
        }
    }

    private func binding(for playerId: String) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(playerId) },
            set: { isOpen in
                if isOpen {
                    expanded.insert(playerId)
                } else {
                    expanded.remove(playerId)
                }
            }
        )
    }

    private func detailLine(for golfer: MastersGolfer) -> String {
        var parts: [String] = []

        if !golfer.oddsText.isEmpty {
            parts.append(golfer.oddsText)
        }

        if let position = golfer.position {
            parts.append("Pos \(position)")
        }

        if let score = golfer.scoreToPar {
            let scoreText = score > 0 ? "+\(score)" : "\(score)"
            parts.append(scoreText)
        }

        if !golfer.status.isEmpty {
            parts.append(golfer.status.capitalized.replacingOccurrences(of: "_", with: " "))
        }

        return parts.joined(separator: " • ")
    }

    private func load() async {
        do {
            let ref = db.collection("masters_drafts").document(gameRefId)
            let rostersSnap = try await ref.collection("rosters").getDocuments()
            let golfersSnap = try await ref.collection("golfers").getDocuments()

            let loadedRosters = rostersSnap.documents.map {
                MastersRoster(id: $0.documentID, data: $0.data())
            }

            var golferMap: [String: MastersGolfer] = [:]
            for doc in golfersSnap.documents {
                let golfer = MastersGolfer(id: doc.documentID, data: doc.data())
                golferMap[golfer.id] = golfer
            }

            await MainActor.run {
                self.rosters = loadedRosters
                self.golfersById = golferMap
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load teams: \(error.localizedDescription)"
            }
        }
    }
}
