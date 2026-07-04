//
//  VegasOddsAdminView.swift
//  Best Man Challenge
//

import SwiftUI
import FirebaseFirestore

// MARK: - Admin Tab

struct VegasOddsAdminView: View {
    @EnvironmentObject var session: SessionStore

    @StateObject private var eventsStore  = VegasOddsEventsStore()
    @StateObject private var playersStore = PlayersStore()

    @State private var selectedEventId: String? = nil

    // Create event form
    @State private var newEventName  = ""
    @State private var newBetPerPick = 100
    @State private var newMaxPicks   = 3
    @State private var isCreating    = false

    // Lifecycle
    @State private var isRunning     = false
    @State private var statusMessage: String? = nil

    // Odds sheet
    @State private var showOddsSheet = false

    private var selectedEvent: VegasOddsEvent? {
        let id = selectedEventId ?? eventsStore.events.first?.id
        return eventsStore.events.first(where: { $0.id == id })
    }

    var body: some View {
        List {
            createSection
            manageSection
            statusSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Admin")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showOddsSheet) {
            if let event = selectedEvent {
                VegasOddsSetOddsSheet(event: event)
            }
        }
        .onAppear {
            eventsStore.startListening()
            playersStore.startListening()
        }
        .onChange(of: eventsStore.events) { events in
            if selectedEventId == nil { selectedEventId = events.first?.id }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var createSection: some View {
        Section("Create New Event") {
            TextField("Event name (e.g. Cornhole)", text: $newEventName)
                .autocorrectionDisabled()
            HStack {
                Text("$ per pick")
                Spacer()
                Stepper("\(newBetPerPick)", value: $newBetPerPick, in: 25...500, step: 25)
            }
            HStack {
                Text("# of picks")
                Spacer()
                Stepper("\(newMaxPicks)", value: $newMaxPicks, in: 1...5)
            }
            Button {
                Task { await createEventTapped() }
            } label: {
                Label(isCreating ? "Creating…" : "Create Event", systemImage: "plus.circle.fill")
            }
            .disabled(!isOwnerAccount() || isCreating || newEventName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    @ViewBuilder
    private var manageSection: some View {
        if !eventsStore.events.isEmpty {
            Section {
                eventPicker
                setOddsButton
                lockButton
                finalizeButton
                recomputeButton
            } header: {
                Text("Manage Event")
            } footer: {
                Text("Lock → closes betting. Finalize → settles slips & updates standings.")
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let msg = statusMessage {
            Section("Status") {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Row helpers

    private var eventPicker: some View {
        Picker("Select Event", selection: Binding(
            get: { selectedEventId ?? eventsStore.events.first?.id },
            set: { selectedEventId = $0 }
        )) {
            ForEach(eventsStore.events, id: \.id) { e in
                Text("\(e.name) — \(e.status)").tag(Optional(e.id))
            }
        }
    }

    private var setOddsButton: some View {
        Button { showOddsSheet = true } label: {
            Label("Set Player Odds", systemImage: "slider.horizontal.3")
        }
        .disabled(selectedEvent == nil)
    }

    private var lockButton: some View {
        Button {
            Task { await lockEventTapped() }
        } label: {
            let isOpen = selectedEvent?.status == "open"
            Label("Lock Event (stop betting)", systemImage: "lock.fill")
                .foregroundColor(isOpen ? .orange : .secondary)
        }
        .disabled(!isOwnerAccount() || isRunning || selectedEvent?.status != "open")
    }

    private var finalizeButton: some View {
        Button {
            Task { await finalizeTapped() }
        } label: {
            Label("Finalize Event (settle bets)", systemImage: "checkmark.seal")
        }
        .buttonStyle(.borderedProminent)
        .disabled(!isOwnerAccount() || isRunning || selectedEvent?.status != "locked")
    }

    private var recomputeButton: some View {
        Button {
            Task { await recomputeTapped() }
        } label: {
            Label("Recompute All Totals", systemImage: "arrow.clockwise")
        }
        .buttonStyle(.bordered)
        .disabled(!isOwnerAccount() || isRunning)
    }

    // MARK: - Auth

    private func isOwnerAccount() -> Bool {
        let role = session.profile?.role ?? ""
        return role == "owner" || role == "commish"
    }

    // MARK: - Actions

    private func createEventTapped() async {
        let name = newEventName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isCreating = true
        statusMessage = "Creating \"\(name)\"…"
        do {
            let db  = Firestore.firestore()
            let ref = db.collection("vegas_odds_events").document()
            try await ref.setData([
                "name":       name,
                "status":     "open",
                "betPerPick": newBetPerPick,
                "maxPicks":   newMaxPicks,
                "createdAt":  FieldValue.serverTimestamp(),
                "updatedAt":  FieldValue.serverTimestamp()
            ])
            statusMessage = "✅ \"\(name)\" created. Head to Sportsbook to bet."
            selectedEventId = ref.documentID
            newEventName = ""
        } catch {
            statusMessage = "❌ Create failed: \(error.localizedDescription)"
        }
        isCreating = false
    }

    private func lockEventTapped() async {
        guard let eventId = selectedEventId ?? eventsStore.events.first?.id else { return }
        isRunning = true
        statusMessage = "Locking…"
        do {
            try await Firestore.firestore()
                .collection("vegas_odds_events")
                .document(eventId)
                .updateData(["status": "locked", "updatedAt": FieldValue.serverTimestamp()])
            statusMessage = "🔒 Betting is closed."
        } catch {
            statusMessage = "❌ Lock failed: \(error.localizedDescription)"
        }
        isRunning = false
    }

    private func finalizeTapped() async {
        guard let eventId = selectedEventId ?? eventsStore.events.first?.id else { return }
        isRunning = true
        statusMessage = "Finalizing…"
        do {
            try await VegasOddsFinalizer().finalizeEvent(eventId: eventId)
            statusMessage = "✅ Finalized. Slips settled and standings updated."
        } catch {
            statusMessage = "❌ Finalize failed: \(error.localizedDescription)"
        }
        isRunning = false
    }

    private func recomputeTapped() async {
        isRunning = true
        statusMessage = "Recomputing totals…"
        do {
            try await VegasOddsFinalizer().recomputeAllTotalsFromLedger()
            statusMessage = "✅ Totals recomputed."
        } catch {
            statusMessage = "❌ Recompute failed: \(error.localizedDescription)"
        }
        isRunning = false
    }
}

// MARK: - Set Odds Sheet

struct VegasOddsSetOddsSheet: View {
    let event: VegasOddsEvent

    @StateObject private var playersStore = PlayersStore()
    @StateObject private var linesStore   = VegasOddsLinesStore()

    /// playerId → probability (0.0 – 1.0)
    @State private var probabilities: [String: Double] = [:]

    @State private var isSaving   = false
    @State private var saveStatus: String? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Set each player's chance of finishing Top 3. American odds update automatically.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Player Odds") {
                    ForEach(playersStore.players.sorted(by: { $0.displayName < $1.displayName })) { player in
                        let prob = Binding(
                            get: { probabilities[player.id] ?? 0.25 },
                            set: { probabilities[player.id] = $0 }
                        )
                        VStack(spacing: 6) {
                            HStack {
                                Text(player.displayName)
                                    .font(.subheadline)
                                Spacer()
                                Text(impliedAmericanOdds(prob.wrappedValue))
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundColor(.blue)
                                Text("(\(Int(prob.wrappedValue * 100))%)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: prob, in: 0.05...0.95, step: 0.01)
                                .tint(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                }

                if let status = saveStatus {
                    Section {
                        Text(status)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Set Odds — \(event.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Saving…" : "Save") {
                        Task { await saveOdds() }
                    }
                    .disabled(isSaving || probabilities.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            playersStore.startListening()
            linesStore.startListening(eventId: event.id)
        }
        .onChange(of: linesStore.linesByPlayerId) { lines in
            // Pre-fill from existing Firestore odds once loaded
            for (playerId, line) in lines {
                if probabilities[playerId] == nil {
                    probabilities[playerId] = line.top3Probability
                }
            }
        }
        // Default un-set players to 0.25 once players load
        .onChange(of: playersStore.players) { players in
            for p in players where probabilities[p.id] == nil {
                probabilities[p.id] = 0.25
            }
        }
    }

    // MARK: - Helpers

    /// Convert probability to a fair American odds string.
    private func impliedAmericanOdds(_ prob: Double) -> String {
        let p = max(0.01, min(0.99, prob))
        let american = OddsMath.americanOdds(fromProbability: p)
        return OddsMath.formatAmerican(american)
    }

    // MARK: - Save

    private func saveOdds() async {
        guard !isSaving else { return }
        isSaving = true
        saveStatus = "Saving odds…"

        let db = Firestore.firestore()
        let batch = db.batch()

        for (playerId, prob) in probabilities {
            let ref = db
                .collection("vegas_odds_events")
                .document(event.id)
                .collection("odds")
                .document(playerId)
            batch.setData([
                "playerId":          playerId,
                "top3Probability":   prob,
                "updatedAt":         FieldValue.serverTimestamp()
            ], forDocument: ref, merge: true)
        }

        do {
            try await batch.commit()
            saveStatus = "✅ Odds saved."
            try? await Task.sleep(nanoseconds: 800_000_000)
            dismiss()
        } catch {
            saveStatus = "❌ Save failed: \(error.localizedDescription)"
        }
        isSaving = false
    }
}
