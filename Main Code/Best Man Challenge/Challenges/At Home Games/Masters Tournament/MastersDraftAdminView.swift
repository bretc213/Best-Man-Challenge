import SwiftUI
import FirebaseFirestore

struct MastersDraftAdminView: View {
    @EnvironmentObject var session: SessionStore
    let gameRefId: String

    @State private var meta: MastersDraftMeta? = nil
    @State private var golfers: [MastersGolfer] = []
    @State private var editablePosition: [String: String] = [:]
    @State private var editableScore: [String: String] = [:]
    @State private var editableStatus: [String: String] = [:]
    @State private var isSaving = false
    @State private var isRecomputing = false
    @State private var isFinalizing = false
    @State private var errorMessage: String? = nil
    @State private var alertMessage = ""
    @State private var showAlert = false

    private let db = Firestore.firestore()
    private let service = MastersDraftService()
    private let statusOptions = ["available", "drafted", "active", "finished", "cut", "missed_cut", "wd", "dq"]

    var body: some View {
        ThemedScreen {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                adminToolsSection
                golfersSection
            }
            .listStyle(.plain)
            .navigationTitle("Admin")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { Task { await load() } }
            .alert("The Masters", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var isOwner: Bool {
        (session.profile?.role ?? "") == "owner"
    }

    @ViewBuilder
    private var adminToolsSection: some View {
        Section {
            Text("Enter the live golf leaderboard manually, then recompute the challenge standings. Finalize when the event is over.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(isSaving ? "Saving leaderboard..." : "Save leaderboard edits") {
                Task { await saveLeaderboardEdits() }
            }
            .disabled(!isOwner || isSaving || isRecomputing || isFinalizing)

            Button(isRecomputing ? "Recomputing..." : "Recompute Standings") {
                Task { await recomputeStandings() }
            }
            .disabled(!isOwner || isSaving || isRecomputing || isFinalizing)

            Button(isFinalizing ? "Finalizing..." : "Finalize Masters Points") {
                Task { await finalizeChallenge() }
            }
            .disabled(!isOwner || isSaving || isRecomputing || isFinalizing || (meta?.isFinalized ?? false))
        } header: {
            Text("Admin Tools")
        }
    }

    @ViewBuilder
    private var golfersSection: some View {
        Section("Golfers") {
            ForEach(sortedGolfers) { golfer in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(golfer.name)
                                .font(.headline)

                            if !golfer.oddsText.isEmpty {
                                Text(golfer.oddsText)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text("\(golfer.leaderboardPoints) pts")
                            .font(.subheadline.weight(.semibold))
                    }

                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Position")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField("--", text: Binding(
                                get: { editablePosition[golfer.id] ?? golfer.position.map(String.init) ?? "" },
                                set: { editablePosition[golfer.id] = $0 }
                            ))
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 88)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Score")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField("E / -8", text: Binding(
                                get: { editableScore[golfer.id] ?? golfer.scoreToPar.map(String.init) ?? "" },
                                set: { editableScore[golfer.id] = $0 }
                            ))
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 88)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Status")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Picker("Status", selection: Binding(
                                get: { editableStatus[golfer.id] ?? golfer.status },
                                set: { editableStatus[golfer.id] = $0 }
                            )) {
                                ForEach(statusOptions, id: \.self) { option in
                                    Text(option.replacingOccurrences(of: "_", with: " ").capitalized).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var sortedGolfers: [MastersGolfer] {
        golfers.sorted {
            let lp = $0.position ?? 9999
            let rp = $1.position ?? 9999
            if lp != rp { return lp < rp }
            if $0.oddsSort != $1.oddsSort { return $0.oddsSort < $1.oddsSort }
            return $0.name < $1.name
        }
    }

    private func load() async {
        do {
            let ref = db.collection("masters_drafts").document(gameRefId)
            let metaSnap = try await ref.getDocument()
            let golfersSnap = try await ref.collection("golfers").getDocuments()
            let loaded = golfersSnap.documents.map { MastersGolfer(id: $0.documentID, data: $0.data()) }

            await MainActor.run {
                self.meta = MastersDraftMeta(id: metaSnap.documentID, data: metaSnap.data() ?? [:])
                self.golfers = loaded
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load admin view: \(error.localizedDescription)"
            }
        }
    }

    private func saveLeaderboardEdits() async {
        guard isOwner else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let ref = db.collection("masters_drafts").document(gameRefId)
            let batch = db.batch()

            for golfer in golfers {
                let docRef = ref.collection("golfers").document(golfer.id)
                var payload: [String: Any] = [
                    "status": editableStatus[golfer.id] ?? golfer.status,
                    "updatedAt": FieldValue.serverTimestamp()
                ]

                if let rawPos = editablePosition[golfer.id],
                   !rawPos.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let pos = Int(rawPos) {
                    payload["position"] = pos
                }

                if let rawScore = editableScore[golfer.id],
                   !rawScore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let score = Int(rawScore) {
                    payload["scoreToPar"] = score
                }

                batch.setData(payload, forDocument: docRef, merge: true)
            }

            batch.setData([
                "lastUpdated": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: ref, merge: true)

            try await batch.commit()
            await load()

            await MainActor.run {
                alertMessage = "Leaderboard edits saved."
                showAlert = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to save leaderboard edits: \(error.localizedDescription)"
            }
        }
    }

    private func recomputeStandings() async {
        guard isOwner else { return }
        isRecomputing = true
        errorMessage = nil
        defer { isRecomputing = false }

        do {
            try await service.recomputeStandings(gameRefId: gameRefId)
            await load()

            await MainActor.run {
                alertMessage = "Standings recomputed."
                showAlert = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to recompute standings: \(error.localizedDescription)"
            }
        }
    }

    private func finalizeChallenge() async {
        guard isOwner else { return }
        isFinalizing = true
        errorMessage = nil
        defer { isFinalizing = false }

        do {
            let finalizedBy = session.profile?.displayName ?? "Admin"
            try await service.finalizeChallenge(gameRefId: gameRefId, finalizedBy: finalizedBy)
            await load()

            await MainActor.run {
                alertMessage = "Masters points finalized."
                showAlert = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to finalize challenge: \(error.localizedDescription)"
            }
        }
    }
}
