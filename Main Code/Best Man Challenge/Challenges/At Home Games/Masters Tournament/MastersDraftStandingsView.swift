import SwiftUI
import FirebaseFirestore

struct MastersDraftStandingsView: View {
    let gameRefId: String

    @State private var standings: [MastersStanding] = []
    @State private var meta: MastersDraftMeta? = nil
    @State private var errorMessage: String? = nil

    private let db = Firestore.firestore()

    var body: some View {
        ThemedScreen {
            List {
                if let lastUpdated = meta?.lastUpdated {
                    Section {
                        Text("Last updated \(dateString(lastUpdated))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if standings.isEmpty {
                    ContentUnavailableView(
                        "No standings yet",
                        systemImage: "list.number",
                        description: Text("Once the admin enters the live golf leaderboard and recomputes, standings will appear here.")
                    )
                    .padding(.vertical, 24)
                } else {
                    ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                        HStack(alignment: .top) {
                            Text("#\(index + 1)")
                                .font(.headline)
                                .frame(width: 44, alignment: .leading)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(standing.displayName ?? standing.playerId)
                                    .font(.headline)
                                Text("\(standing.points) pts")
                                    .font(.subheadline.weight(.semibold))
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Standings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { Task { await load() } }
        }
    }

    private func load() async {
        do {
            let ref = db.collection("masters_drafts").document(gameRefId)
            let metaSnap = try await ref.getDocument()
            let standingsSnap = try await ref.collection("standings").getDocuments()

            let rows = standingsSnap.documents
                .map { MastersStanding(id: $0.documentID, data: $0.data()) }
                .sorted {
                    if $0.points != $1.points { return $0.points > $1.points }
                    return ($0.displayName ?? $0.playerId) < ($1.displayName ?? $1.playerId)
                }

            await MainActor.run {
                self.meta = MastersDraftMeta(id: metaSnap.documentID, data: metaSnap.data() ?? [:])
                self.standings = rows
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load standings: \(error.localizedDescription)"
            }
        }
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
