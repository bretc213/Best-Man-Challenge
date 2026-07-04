//
//  VegasOddsView.swift
//  Best Man Challenge
//
//  Sportsbook tab — event picker, player selection, finalized slip display.
//

import SwiftUI
import FirebaseAuth

struct VegasOddsView: View {
    @Binding var allSlips: [BetSlip]

    init() { self._allSlips = .constant([]) }
    init(allSlips: Binding<[BetSlip]>) { self._allSlips = allSlips }

    @StateObject private var playersStore      = PlayersStore()
    @StateObject private var eventsStore       = VegasOddsEventsStore()
    @StateObject private var linesStore        = VegasOddsLinesStore()
    @StateObject private var myBetStore        = VegasOddsMyBetStore()
    @StateObject private var bankrollStore     = VegasOddsBankrollStore()
    @StateObject private var currentUserStore  = VegasOddsCurrentUserStore()

    @State private var selectedEventId: String? = nil
    @State private var selectedPlayerIds: Set<String> = []

    @State private var lastSlip: BetSlip? = nil
    @State private var showPreSlip      = false
    @State private var navigateToSlip   = false
    @State private var pendingSlip: BetSlip? = nil

    @State private var showLoadErrorAlert = false
    @State private var loadErrorMessage   = ""

    // MARK: - Derived state

    private var selectedEvent: VegasOddsEvent? {
        guard let id = selectedEventId else { return nil }
        return eventsStore.events.first(where: { $0.id == id })
    }

    private var maxSelections: Int { selectedEvent?.maxPicks  ?? 3 }
    private var betPerPick:    Int { selectedEvent?.betPerPick ?? 100 }
    private var totalBetAmount: Int { selectedPlayerIds.count * betPerPick }
    private var betAlreadyPlaced: Bool { myBetStore.betAlreadyPlaced }
    private var myPlayerId: String? { currentUserStore.linkedPlayerId }

    private var isFinalized: Bool { selectedEvent?.status == "finalized" }
    private var isOpen:      Bool { selectedEvent?.status == "open" }

    private var selectedPlayers:      [FirestorePlayer] { playersStore.players.filter { selectedPlayerIds.contains($0.id) } }
    private var selectedDisplayNames: [String]          { selectedPlayers.map { $0.displayName } }
    private var selectedOdds:         [String]          { selectedPlayers.map { linesStore.oddsString(for: $0.id) ?? "+100" } }

    private var canPreviewSlip: Bool {
        guard let event = selectedEvent else { return false }
        return selectedPlayerIds.count == event.maxPicks
            && !betAlreadyPlaced
            && event.status == "open"
    }

    // MARK: - Auto-event selection

    /// Returns the id of the most relevant event to open on load:
    /// prefers the open event whose startsAt is nearest (future first, then past),
    /// then locked, then the list's first element.
    private func autoSelectEventId(from events: [VegasOddsEvent]) -> String? {
        let now = Date()

        let open = events.filter { $0.status == "open" }
        if !open.isEmpty {
            let sorted = open.sorted { a, b in
                let da = (a.startsAt ?? .distantFuture).timeIntervalSince(now)
                let db = (b.startsAt ?? .distantFuture).timeIntervalSince(now)
                if da >= 0 && db >= 0 { return da < db }   // both future → nearest first
                if da < 0  && db < 0  { return da > db }   // both past   → most recent first
                return da >= 0                              // future beats past
            }
            return sorted.first?.id
        }

        if let locked = events.first(where: { $0.status == "locked" }) { return locked.id }
        return events.first?.id
    }

    // MARK: - Parlay math

    private func parlayDecimalOdds(for pickIds: [String]) -> Double {
        pickIds.map { linesStore.decimalOdds(for: $0) ?? 2.0 }.reduce(1.0, *)
    }

    private var computedParlayBonus: Int {
        guard betPerPick > 0, !selectedPlayerIds.isEmpty else { return 0 }
        let dec = parlayDecimalOdds(for: Array(selectedPlayerIds))
        return Int(round(max(0, Double(betPerPick) * dec - Double(betPerPick))))
    }

    private var mySavedSlip: BetSlip? {
        guard let bet = myBetStore.myBet else { return nil }
        let wager  = bet.betPerPick * max(bet.picks.count, 1)
        let dec    = parlayDecimalOdds(for: bet.picks)
        let toWin  = Int(round(max(0, Double(bet.betPerPick) * dec - Double(bet.betPerPick))))
        let names  = bet.pickDisplayNames.isEmpty ? bet.picks : bet.pickDisplayNames
        let odds   = bet.oddsStrings.isEmpty ? Array(repeating: "+100", count: names.count) : bet.oddsStrings
        return BetSlip(
            challenge:       bet.eventName.isEmpty ? (selectedEvent?.name ?? "Vegas Odds") : bet.eventName,
            selectedPlayers: names,
            odds:            odds,
            betAmount:       wager,
            toWin:           toWin,
            timestamp:       bet.createdAt ?? Date()
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if eventsStore.events.isEmpty {
                    ProgressView("Loading…").frame(maxWidth: .infinity, minHeight: 200)

                } else {

                    // Event picker — only shown when multiple events exist
                    if eventsStore.events.count > 1 {
                        eventPicker
                    }

                    if let event = selectedEvent {

                        if isFinalized {
                            // ─── Finalized: show settled slip ───
                            eventStatusBadge(event.status)
                            VegasOddsSettledSlipView(
                                bet: myBetStore.myBet,
                                eventName: event.name,
                                betPerPick: event.betPerPick
                            )

                        } else {
                            // ─── Open / Locked: normal betting UI ───
                            eventStatusBadge(event.status)
                            infoBar
                            Text("Pick \(maxSelections) Players  •  $\(betPerPick) each")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            playersList
                            statusText
                            betButton
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Sportsbook")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPreSlip) {
            if let slip = pendingSlip, let eventId = selectedEventId {
                PreBetSlipView(
                    challengeId: eventId,
                    challengeTitle: slip.challenge,
                    playerDisplayNames: slip.selectedPlayers,
                    playerIds: Array(selectedPlayerIds),
                    odds: slip.odds,
                    betAmount: slip.betAmount,
                    cancelAction: { showPreSlip = false },
                    onConfirmed: {
                        allSlips.append(slip)
                        lastSlip = slip
                        selectedPlayerIds.removeAll()
                        showPreSlip = false
                        navigateToSlip = true
                    }
                )
            }
        }
        .background {
            NavigationLink(
                destination: Group { if let slip = lastSlip { BetSlipView(slip: slip) } },
                isActive: $navigateToSlip
            ) { EmptyView() }
        }
        .alert("Heads up", isPresented: $showLoadErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(loadErrorMessage)
        }
        .onAppear {
            playersStore.startListening()
            eventsStore.startListening()
            currentUserStore.startListening()
        }
        .onChange(of: eventsStore.events) { events in
            // Auto-select on first load only
            guard selectedEventId == nil, let firstId = autoSelectEventId(from: events) else { return }
            selectedEventId = firstId
            startSubListeners(for: firstId)
        }
        .onChange(of: eventsStore.errorMessage)   { if let m = $0 { showError("Events: \(m)") } }
        .onChange(of: playersStore.errorMessage)  { if let m = $0 { showError("Players: \(m)") } }
        .onChange(of: linesStore.errorMessage)    { if let m = $0 { showError("Odds: \(m)") } }
        .onChange(of: myBetStore.errorMessage)    { if let m = $0 { showError("Bet status: \(m)") } }
        .onChange(of: bankrollStore.errorMessage) { if let m = $0 { showError("Bankroll: \(m)") } }
    }

    // MARK: - Subviews

    private var eventPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("EVENT")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            Picker("Select Event", selection: Binding(
                get: { selectedEventId ?? eventsStore.events.first?.id },
                set: { newValue in
                    selectedEventId = newValue
                    selectedPlayerIds.removeAll()
                    if let id = newValue { startSubListeners(for: id) }
                }
            )) {
                ForEach(eventsStore.events, id: \.id) { e in
                    Text(e.name).tag(Optional(e.id))
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func eventStatusBadge(_ status: String) -> some View {
        HStack {
            Spacer()
            switch status {
            case "locked":
                Label("Betting Locked", systemImage: "lock.fill")
                    .font(.caption.bold()).foregroundColor(.orange)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color.orange.opacity(0.15)).cornerRadius(8)
            case "finalized":
                Label("Event Finalized", systemImage: "checkmark.seal.fill")
                    .font(.caption.bold()).foregroundColor(.green)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color.green.opacity(0.15)).cornerRadius(8)
            default:
                Label("Open for Bets", systemImage: "circle.fill")
                    .font(.caption.bold()).foregroundColor(.blue)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Color.blue.opacity(0.12)).cornerRadius(8)
            }
            Spacer()
        }
    }

    private var infoBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Bankroll").foregroundColor(.secondary)
                Spacer()
                Text("$\(bankrollStore.balance ?? 300)").bold()
            }
            HStack {
                Text("Pick cost").foregroundColor(.secondary)
                Spacer()
                Text("$\(betPerPick) each").bold()
            }
            HStack {
                Text("Total wager").foregroundColor(.secondary)
                Spacer()
                Text("$\(totalBetAmount)").bold()
            }
            if !selectedPlayerIds.isEmpty {
                Divider().opacity(0.3)
                HStack {
                    Text("Parlay bonus (if all hit)").foregroundColor(.secondary)
                    Spacer()
                    Text("+$\(computedParlayBonus)").bold().foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.12))
        .cornerRadius(12)
    }

    private var playersList: some View {
        LazyVStack(spacing: 8) {
            let sorted = playersStore.players.sorted {
                (linesStore.linesByPlayerId[$0.id]?.top3Probability ?? 0)
                > (linesStore.linesByPlayerId[$1.id]?.top3Probability ?? 0)
            }
            ForEach(sorted) { player in
                let isSelected = selectedPlayerIds.contains(player.id)
                let odds   = linesStore.oddsString(for: player.id) ?? "+100"
                let isSelf = player.id == myPlayerId

                Button { toggleSelection(for: player.id) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(player.displayName + (isSelf ? " (you)" : ""))
                                .font(.subheadline)
                                .foregroundColor(isSelf ? .gray : .primary)
                            Text(odds)
                                .font(.caption)
                                .foregroundColor(isSelf ? .gray : .secondary)
                        }
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelf ? .gray : (isSelected ? .green : .blue))
                            .font(.system(size: 22))
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 10).padding(.horizontal, 12)
                    .background(isSelected ? Color.blue.opacity(0.10) : Color.gray.opacity(isSelf ? 0.05 : 0.10))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.blue.opacity(0.35) : Color.clear, lineWidth: 1.5))
                    .opacity(isSelf ? 0.5 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(isSelf || (!isSelected && (selectedPlayerIds.count >= maxSelections || betAlreadyPlaced || !isOpen)))
            }
        }
    }

    @ViewBuilder
    private var statusText: some View {
        if betAlreadyPlaced {
            Text("You've already placed a bet on this event.")
                .font(.caption).foregroundColor(.orange)
                .frame(maxWidth: .infinity, alignment: .center)
        } else if let me = myPlayerId, selectedPlayerIds.contains(me) {
            Text("You can't bet on yourself.")
                .font(.caption).foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .center)
        } else if selectedEvent?.status == "locked" {
            Text("Betting is closed for this event.")
                .font(.caption).foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var betButton: some View {
        Button(betAlreadyPlaced ? "View My Bet Slip" : "Place Bet") {
            if betAlreadyPlaced {
                if let slip = mySavedSlip { lastSlip = slip; navigateToSlip = true }
                return
            }
            guard let event = selectedEvent else { return }
            let slip = BetSlip(
                challenge: event.name,
                selectedPlayers: selectedDisplayNames,
                odds: selectedOdds,
                betAmount: totalBetAmount,
                toWin: computedParlayBonus,
                timestamp: Date()
            )
            pendingSlip = slip
            showPreSlip = true
        }
        .disabled(betAlreadyPlaced ? mySavedSlip == nil : !canPreviewSlip)
        .frame(maxWidth: .infinity)
        .padding()
        .background((betAlreadyPlaced ? mySavedSlip != nil : canPreviewSlip) ? Color.blue : Color.gray)
        .foregroundColor(.white)
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func startSubListeners(for eventId: String) {
        linesStore.startListening(eventId: eventId)
        myBetStore.startListening(eventId: eventId)
        bankrollStore.startListening(eventId: eventId)
    }

    private func toggleSelection(for playerId: String) {
        if let me = myPlayerId, playerId == me { return }
        if selectedPlayerIds.contains(playerId) {
            selectedPlayerIds.remove(playerId)
        } else if selectedPlayerIds.count < maxSelections && !betAlreadyPlaced {
            selectedPlayerIds.insert(playerId)
        }
    }

    private func showError(_ msg: String) {
        loadErrorMessage = msg
        showLoadErrorAlert = true
    }
}

#Preview {
    NavigationStack {
        VegasOddsView()
    }
}
