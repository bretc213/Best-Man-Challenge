//
//  AdminLedgerAdjustView.swift
//  Best Man Challenge
//
//  Admin tool: manually view/adjust point_awards ledger entries.
//  Pick a player + event -> shows their entry (base + bonus).
//  Editing saves the award doc AND adjusts players.total_points by the delta.
//

import SwiftUI
import FirebaseFirestore

struct AdminLedgerAdjustView: View {
    @EnvironmentObject var session: SessionStore

    @StateObject private var playersStore = PlayersStore()

    // Event list derived from all point_awards docs
    struct EventOption: Identifiable, Hashable {
        let id: String        // challengeId
        let title: String
    }

    @State private var events: [EventOption] = []
    @State private var isLoadingEvents = false

    // Selection
    @State private var selectedPlayerId: String = ""
    @State private var selectedEventId: String = ""

    // Loaded entry
    @State private var loadedDocId: String? = nil
    @State private var entryMissing = false
    @State private var isLoadingEntry = false

    // Editable fields
    @State private var basePointsText: String = ""
    @State private var bonusPointsText: String = ""
    @State private var originalPoints: Double = 0

    @State private var isSaving = false
    @State private var statusMessage: String? = nil

    private let db = Firestore.firestore()

    var body: some View {
        ThemedScreen {
            VStack(alignment: .leading, spacing: 12) {
                header()

                List {
                    Section("Select") {
                        Picker("Player", selection: $selectedPlayerId) {
                            Text("— Choose Player —").tag("")
                            ForEach(sortedPlayers) { p in
                                Text(p.displayName).tag(p.id)
                            }
                        }

                        Picker("Event", selection: $selectedEventId) {
                            Text("— Choose Event —").tag("")
                            ForEach(events) { e in
                                Text(e.title).tag(e.id)
                            }
                        }

                        if isLoadingEvents {
                            ProgressView("Loading events…")
                        }
                    }

                    if isLoadingEntry {
                        Section { ProgressView("Loading entry…") }
                    } else if entryMissing {
                        missingEntrySection()
                    } else if loadedDocId != nil {
                        entrySection()
                    }

                    if let msg = statusMessage {
                        Section {
                            Text(msg)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Ledger Adjust")
        .task {
            playersStore.startListening()
            await loadEvents()
        }
        .onChange(of: selectedPlayerId) { _, _ in Task { await loadEntry() } }
        .onChange(of: selectedEventId) { _, _ in Task { await loadEntry() } }
    }

    // MARK: - Sections

    private func header() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ledger Adjust").font(.title2).bold()
            Text("Manually view and adjust point_awards. Saving updates the ledger entry and the player's leaderboard total.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func entrySection() -> some View {
        Section("Ledger Entry") {
            HStack {
                Text("Base")
                Spacer()
                TextField("Base", text: $basePointsText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
            }
            HStack {
                Text("Bonus")
                Spacer()
                TextField("Bonus", text: $bonusPointsText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
            }
            HStack {
                Text("New Total").bold()
                Spacer()
                Text(formatPoints(editedTotal)).bold()
            }
            HStack {
                Text("Current Saved Total")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatPoints(originalPoints))
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await save(creating: false) }
            } label: {
                Label(isSaving ? "Saving…" : "Save Adjustment",
                      systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isOwnerAccount() || isSaving || editedTotal == nil)
        }
    }

    @ViewBuilder
    private func missingEntrySection() -> some View {
        Section("Ledger Entry") {
            Text("Error: This player has no points here and should have points")
                .font(.subheadline).bold()
                .foregroundStyle(.red)

            HStack {
                Text("Base")
                Spacer()
                TextField("0", text: $basePointsText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
            }
            HStack {
                Text("Bonus")
                Spacer()
                TextField("0", text: $bonusPointsText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
            }

            Button {
                Task { await save(creating: true) }
            } label: {
                Label(isSaving ? "Creating…" : "Create Entry",
                      systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isOwnerAccount() || isSaving || editedTotal == nil)
        }
    }

    // MARK: - Derived

    private var sortedPlayers: [FirestorePlayer] {
        playersStore.players.sorted { $0.displayName < $1.displayName }
    }

    private var editedTotal: Double? {
        guard
            let base = Double(basePointsText.trimmingCharacters(in: .whitespaces)),
            let bonus = Double(bonusPointsText.trimmingCharacters(in: .whitespaces))
        else { return nil }
        return base + bonus
    }

    // MARK: - Loading

    /// Builds the event dropdown from every distinct challengeId in point_awards.
    private func loadEvents() async {
        isLoadingEvents = true
        defer { isLoadingEvents = false }

        do {
            let snap = try await db.collection("point_awards").getDocuments()
            var titles: [String: String] = [:]
            for doc in snap.documents {
                let data = doc.data()
                guard let cid = data["challengeId"] as? String else { continue }
                if titles[cid] == nil {
                    titles[cid] = (data["challengeTitle"] as? String) ?? cid
                }
            }
            events = titles
                .map { EventOption(id: $0.key, title: $0.value) }
                .sorted { $0.title < $1.title }
        } catch {
            statusMessage = "Couldn't load events: \(error.localizedDescription)"
        }
    }

    private func loadEntry() async {
        statusMessage = nil
        loadedDocId = nil
        entryMissing = false

        guard !selectedPlayerId.isEmpty, !selectedEventId.isEmpty else { return }

        isLoadingEntry = true
        defer { isLoadingEntry = false }

        do {
            // Query by fields (not doc id) so any id scheme is found.
            let snap = try await db.collection("point_awards")
                .whereField("challengeId", isEqualTo: selectedEventId)
                .whereField("playerId", isEqualTo: selectedPlayerId)
                .getDocuments()

            if let doc = snap.documents.first {
                let data = doc.data()
                loadedDocId = doc.documentID
                originalPoints = (data["points"] as? NSNumber)?.doubleValue ?? 0
                let base = (data["basePoints"] as? NSNumber)?.doubleValue ?? 0
                let bonus = (data["bonusPoints"] as? NSNumber)?.doubleValue ?? 0
                basePointsText = formatPoints(base)
                bonusPointsText = formatPoints(bonus)
                entryMissing = false
            } else {
                entryMissing = true
                originalPoints = 0
                basePointsText = "0"
                bonusPointsText = "0"
            }
        } catch {
            statusMessage = "Couldn't load entry: \(error.localizedDescription)"
        }
    }

    // MARK: - Saving

    private func save(creating: Bool) async {
        guard isOwnerAccount() else {
            statusMessage = "Only owners can adjust the ledger."
            return
        }
        guard
            let base = Double(basePointsText.trimmingCharacters(in: .whitespaces)),
            let bonus = Double(bonusPointsText.trimmingCharacters(in: .whitespaces))
        else {
            statusMessage = "Enter valid numbers for base and bonus."
            return
        }

        let newTotal = base + bonus
        let delta = newTotal - originalPoints

        isSaving = true
        defer { isSaving = false }

        do {
            let docId = creating
                ? "\(selectedEventId)_\(selectedPlayerId)"
                : (loadedDocId ?? "\(selectedEventId)_\(selectedPlayerId)")

            let awardRef = db.collection("point_awards").document(docId)
            let playerRef = db.collection("players").document(selectedPlayerId)
            let eventTitle = events.first(where: { $0.id == selectedEventId })?.title ?? selectedEventId

            let batch = db.batch()

            var fields: [String: Any] = [
                "playerId": selectedPlayerId,
                "challengeId": selectedEventId,
                "challengeTitle": eventTitle,
                "points": newTotal,
                "basePoints": base,
                "bonusPoints": bonus,
                "adjustedAt": FieldValue.serverTimestamp(),
                "adjustedBy": "admin_ledger_adjust"
            ]
            if creating {
                fields["createdAt"] = FieldValue.serverTimestamp()
                fields["note"] = "(manually added)"
            }

            batch.setData(fields, forDocument: awardRef, merge: true)

            if delta != 0 {
                batch.setData([
                    "total_points": FieldValue.increment(delta),
                    "updated_at": FieldValue.serverTimestamp()
                ], forDocument: playerRef, merge: true)
            }

            try await batch.commit()

            loadedDocId = docId
            entryMissing = false
            originalPoints = newTotal
            statusMessage = creating
                ? "✅ Entry created (\(formatPoints(newTotal)) pts). Leaderboard updated."
                : "✅ Saved. Total changed by \(formatPoints(delta)) pts. Leaderboard updated."
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    private func isOwnerAccount() -> Bool {
        let role = session.profile?.role ?? ""
        return role == "owner" || role == "commish"
    }

    private func formatPoints(_ v: Double?) -> String {
        guard let v else { return "—" }
        return v == v.rounded()
            ? String(Int(v))
            : String(format: "%.1f", v)
    }
}
