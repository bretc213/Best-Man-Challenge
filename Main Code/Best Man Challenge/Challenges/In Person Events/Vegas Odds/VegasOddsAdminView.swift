//
//  VegasOddsAdminView.swift
//  Best Man Challenge
//

import SwiftUI

/// Minimal in-app finalizer for Vegas Odds.
///
/// Requirements:
/// - Firestore must have standings at:
///     vegas_odds_events/{eventId}/results/final { standings: [playerId] }
/// - Odds must exist at:
///     vegas_odds_events/{eventId}/odds/{playerId} { top3Probability: Double }
struct VegasOddsAdminView: View {
    @EnvironmentObject var session: SessionStore

    @ObservedObject var eventsStore: VegasOddsEventsStore

    @State private var selectedEventId: String? = nil
    @State private var isRunning = false
    @State private var statusMessage: String? = nil

    var body: some View {
        ThemedScreen {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Vegas Odds Admin")
                        .font(.title2).bold()
                    Text("Finalize results and settle bets. Owners only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                List {
                    Section("Event") {
                        Picker("Select Event", selection: Binding(
                            get: { selectedEventId ?? eventsStore.events.first?.id },
                            set: { selectedEventId = $0 }
                        )) {
                            ForEach(eventsStore.events, id: \.id) { e in
                                Text("\(e.name) — \(e.status)").tag(Optional(e.id))
                            }
                        }
                    }

                    Section {
                        Button {
                            Task { await finalizeTapped() }
                        } label: {
                            Label("Finalize Selected Event", systemImage: "checkmark.seal")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isOwnerAccount() || isRunning || selectedEventId == nil)

                        Button {
                            Task { await recomputeTapped() }
                        } label: {
                            Label("Recompute Vegas Winnings (ledger)", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!isOwnerAccount() || isRunning)
                    } footer: {
                        Text("Finalizing settles every bet slip for the event and updates players.vegas_winnings.")
                    }

                    if let msg = statusMessage {
                        Section("Status") {
                            Text(msg)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .onAppear {
            if selectedEventId == nil {
                selectedEventId = eventsStore.events.first?.id
            }
        }
    }

    private func isOwnerAccount() -> Bool {
        let role = session.profile?.role ?? ""
        return role == "owner" || role == "commish"
    }

    private func finalizeTapped() async {
        guard let eventId = selectedEventId else { return }
        isRunning = true
        statusMessage = "Finalizing \(eventId)..."

        do {
            let finalizer = VegasOddsFinalizer()
            try await finalizer.finalizeEvent(eventId: eventId)
            statusMessage = "✅ Finalized \(eventId)."
        } catch {
            statusMessage = "❌ Finalize failed: \(error.localizedDescription)"
        }

        isRunning = false
    }

    private func recomputeTapped() async {
        isRunning = true
        statusMessage = "Recomputing totals from ledger..."

        do {
            let finalizer = VegasOddsFinalizer()
            try await finalizer.recomputeAllTotalsFromLedger()
            statusMessage = "✅ Totals recomputed."
        } catch {
            statusMessage = "❌ Recompute failed: \(error.localizedDescription)"
        }

        isRunning = false
    }
}
