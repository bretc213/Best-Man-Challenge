//
//  VegasOddsView.swift
//  Best Man Challenge
//
//  NOTE
//  - Keeps the existing flow that drives your casino-ticket UI
//    (PreBetSlipView + BetSlipView + BetSlip model).
//  - Uses Firestore-driven events + probability-based odds.
//  - Entire screen scrolls (no nested ScrollView).
//

import SwiftUI
import FirebaseAuth

struct VegasOddsView: View {
    @Binding var allSlips: [BetSlip] // kept for compatibility

    // ✅ Allows VegasOddsHomeView to call `VegasOddsView()` with no binding.
    init() { self._allSlips = .constant([]) }
    init(allSlips: Binding<[BetSlip]>) { self._allSlips = allSlips }

    @StateObject private var playersStore = PlayersStore()
    @StateObject private var eventsStore = VegasOddsEventsStore()
    @StateObject private var linesStore = VegasOddsLinesStore()
    @StateObject private var myBetStore = VegasOddsMyBetStore()
    @StateObject private var bankrollStore = VegasOddsBankrollStore()
    @StateObject private var currentUserStore = VegasOddsCurrentUserStore()

    @State private var selectedEventId: String? = nil
    @State private var selectedPlayerIds: Set<String> = []

    @State private var lastSlip: BetSlip? = nil
    @State private var showAllSlips: Bool = false
    @State private var showPreSlip: Bool = false
    @State private var navigateToSlip: Bool = false
    @State private var pendingSlip: BetSlip? = nil

    @State private var showLoadErrorAlert = false
    @State private var loadErrorMessage = ""

    private var selectedEvent: VegasOddsEvent? {
        guard let id = selectedEventId else { return nil }
        return eventsStore.events.first(where: { $0.id == id })
    }

    /// Firebase Auth UID (not the same as player.id in many setups)
    private var bettorUid: String {
        Auth.auth().currentUser?.uid ?? ""
    }

    private var maxSelections: Int { selectedEvent?.maxPicks ?? 3 }
    private var betPerPick: Int { selectedEvent?.betPerPick ?? 100 }
    private var totalBetAmount: Int { selectedPlayerIds.count * betPerPick }

    private var betAlreadyPlaced: Bool { myBetStore.betAlreadyPlaced }

    private var selectedPlayers: [FirestorePlayer] {
        playersStore.players.filter { selectedPlayerIds.contains($0.id) }
    }

    private var selectedDisplayNames: [String] {
        selectedPlayers.map { $0.displayName }
    }

    private var selectedOdds: [String] {
        selectedPlayers.map { linesStore.oddsString(for: $0.id) ?? "+100" }
    }

    private var canPreviewSlip: Bool {
        guard let event = selectedEvent else { return false }
        return selectedPlayerIds.count == event.maxPicks && !betAlreadyPlaced
    }

    // MARK: - Self-bet protection (the important part)

    /// Tries to read a UID-like field off FirestorePlayer without assuming it exists at compile time.
    /// This avoids "no member 'userId'" type compile errors.
    private func authUidFromPlayer(_ p: FirestorePlayer) -> String? {
        let m = Mirror(reflecting: p)
        // common field names
        for key in ["uid", "userId", "authUid", "firebaseUid", "linkedUserId"] {
            if let v = m.descendant(key) as? String, !v.isEmpty {
                return v
            }
        }
        return nil
    }

    /// The player document id that represents the signed-in user (if we can infer it).
    ///
    /// Works for both patterns:
    /// - players/{uid} (player.id == auth uid)
    /// - players/{playerId} with a stored uid field (player.uid / player.userId / etc)
    private var myPlayerId: String? {
        currentUserStore.linkedPlayerId
    }

    // MARK: - Parlay math

    /// Profit (not total collect) for the current selection using parlay decimal odds.
    private var computedParlayToWin: Int {
        guard betPerPick > 0 else { return 0 }
        let pickIds = Array(selectedPlayerIds)
        let dec = parlayDecimalOdds(for: pickIds)

        // Parlay stake is ONE pick cost ($100), not $300
        let stake = Double(betPerPick)

        let profit = max(0, (stake * dec) - stake)
        return Int(round(profit))
    }

    private func parlayDecimalOdds(for pickIds: [String]) -> Double {
        // If any line missing, treat as +100 (decimal 2.0)
        let decimals: [Double] = pickIds.map { pid in
            if let d = linesStore.decimalOdds(for: pid) { return d }
            return 2.0
        }
        return decimals.reduce(1.0, *)
    }

    private var mySavedSlip: BetSlip? {
        guard let bet = myBetStore.myBet else { return nil }
        let wager = bet.betPerPick * max(bet.picks.count, 1)

        let dec = parlayDecimalOdds(for: bet.picks)

        // Parlay is always based on ONE pick cost
        let stake = Double(bet.betPerPick)

        let profit = max(0, (stake * dec) - stake)
        let toWin = Int(round(profit))

        let names = bet.pickDisplayNames.isEmpty ? bet.picks : bet.pickDisplayNames
        let odds = bet.oddsStrings.isEmpty ? Array(repeating: "+100", count: names.count) : bet.oddsStrings

        return BetSlip(
            challenge: bet.eventName.isEmpty ? (selectedEvent?.name ?? "Vegas Odds") : bet.eventName,
            selectedPlayers: names,
            odds: odds,
            betAmount: wager,
            toWin: toWin,
            timestamp: bet.createdAt ?? Date()
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // Top row actions
                    HStack(spacing: 12) {
                        Button("View All Bet Slips") {
                            showAllSlips = true
                        }
                        .sheet(isPresented: $showAllSlips) {
                            VegasOddsLeaderboardView()
                        }

                        Spacer()

                        NavigationLink {
                            VegasOddsAdminView(eventsStore: eventsStore)
                        } label: {
                            Text("Admin")
                                .font(.footnote.bold())
                                .foregroundColor(.secondary)
                        }
                    }

                    infoBar

                    Text("Select Event")
                        .font(.headline)

                    Picker("Select Event", selection: Binding(
                        get: { selectedEventId ?? eventsStore.events.first?.id },
                        set: { newValue in
                            selectedEventId = newValue
                            selectedPlayerIds.removeAll()
                            if let id = newValue {
                                linesStore.startListening(eventId: id)
                                myBetStore.startListening(eventId: id)
                                bankrollStore.startListening(eventId: id)
                            }
                        }
                    )) {
                        ForEach(eventsStore.events, id: \.id) { e in
                            Text(e.name).tag(Optional(e.id))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    Text("Select \(maxSelections) Players ($\(betPerPick) each)")
                        .font(.headline)

                    playersList

                    statusText

                    Button(betAlreadyPlaced ? "View My Bet Slip" : "View Bet Slip") {
                        if betAlreadyPlaced {
                            if let slip = mySavedSlip {
                                lastSlip = slip
                                navigateToSlip = true
                            }
                            return
                        }

                        guard let event = selectedEvent else { return }

                        let slip = BetSlip(
                            challenge: event.name,
                            selectedPlayers: selectedDisplayNames,
                            odds: selectedOdds,
                            betAmount: totalBetAmount,
                            toWin: computedParlayToWin,
                            timestamp: Date()
                        )

                        pendingSlip = slip
                        showPreSlip = true
                    }
                    .disabled(betAlreadyPlaced ? (mySavedSlip == nil) : (!canPreviewSlip))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background((betAlreadyPlaced ? (mySavedSlip != nil) : canPreviewSlip) ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)

                    NavigationLink(
                        destination: Group {
                            if let slip = lastSlip {
                                BetSlipView(slip: slip)
                            }
                        },
                        isActive: $navigateToSlip
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
                .padding()
            }
            .navigationTitle("Vegas Odds")
            .sheet(isPresented: $showPreSlip) {
                if let slip = pendingSlip, let _ = selectedEvent, let eventId = selectedEventId {
                    PreBetSlipView(
                        challengeId: eventId,
                        challengeTitle: slip.challenge,
                        playerDisplayNames: slip.selectedPlayers,
                        playerIds: Array(selectedPlayerIds),
                        odds: slip.odds,
                        betAmount: slip.betAmount,
                        cancelAction: {
                            showPreSlip = false
                        },
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
            // NOTE: sub-listeners (lines/bets/bankroll) are started in
            // onChange(of: eventsStore.events) below, once data actually arrives.
        }
        .onChange(of: eventsStore.events) { events in
            // Auto-select first event the first time events load, then start sub-listeners.
            // This is the only reliable place to do it — onAppear fires before Firestore
            // returns data, so eventsStore.events is always empty there.
            guard selectedEventId == nil, let firstId = events.first?.id else { return }
            selectedEventId = firstId
            linesStore.startListening(eventId: firstId)
            myBetStore.startListening(eventId: firstId)
            bankrollStore.startListening(eventId: firstId)
        }
        .onChange(of: eventsStore.errorMessage) { msg in
            if let msg {
                loadErrorMessage = "Events couldn’t load: \(msg)"
                showLoadErrorAlert = true
            }
        }
        .onChange(of: playersStore.errorMessage) { msg in
            if let msg {
                loadErrorMessage = "Players couldn’t load: \(msg)"
                showLoadErrorAlert = true
            }
        }
        .onChange(of: linesStore.errorMessage) { msg in
            if let msg {
                loadErrorMessage = "Odds couldn’t load: \(msg)"
                showLoadErrorAlert = true
            }
        }
        .onChange(of: myBetStore.errorMessage) { msg in
            if let msg {
                loadErrorMessage = "Bet status error: \(msg)"
                showLoadErrorAlert = true
            }
        }
        .onChange(of: bankrollStore.errorMessage) { msg in
            if let msg {
                loadErrorMessage = "Bankroll error: \(msg)"
                showLoadErrorAlert = true
            }
        }
    }

    // MARK: - Subviews

    private var infoBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Bankroll:")
                    .foregroundColor(.secondary)
                Spacer()
                Text("$\(bankrollStore.balance ?? 300)")
                    .bold()
            }

            HStack {
                Text("Pick cost:")
                    .foregroundColor(.secondary)
                Spacer()
                Text("$\(betPerPick) each")
                    .bold()
            }

            HStack {
                Text("Total wager:")
                    .foregroundColor(.secondary)
                Spacer()
                Text("$\(totalBetAmount)")
                    .bold()
            }

            HStack {
                Text("Event:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(selectedEvent?.name ?? "—")
                    .bold()
            }

            if !selectedPlayerIds.isEmpty {
                Divider().opacity(0.2)
                HStack {
                    Text("Parlay to win:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("$\(computedParlayToWin)")
                        .bold()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(10)
    }

    private var playersList: some View {
        LazyVStack(alignment: .leading, spacing: 10) {

            let sortedPlayers = playersStore.players.sorted { a, b in
                let pa = linesStore.linesByPlayerId[a.id]?.top3Probability ?? 0
                let pb = linesStore.linesByPlayerId[b.id]?.top3Probability ?? 0
                return pa > pb
            }

            ForEach(sortedPlayers) { player in
                let isSelected = selectedPlayerIds.contains(player.id)
                let odds = linesStore.oddsString(for: player.id) ?? "+100"
                let isSelf = (player.id == myPlayerId)

                Button {
                    toggleSelection(for: player.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(player.displayName + (isSelf ? " (you)" : ""))
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
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(Color.gray.opacity(isSelf ? 0.06 : 0.12))
                    .cornerRadius(10)
                    .opacity(isSelf ? 0.55 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(isSelf || (!isSelected && (selectedPlayerIds.count >= maxSelections || betAlreadyPlaced)))
            }
        }
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var statusText: some View {
        let selfId = myPlayerId ?? ""

        if betAlreadyPlaced {
            Text("You’ve already placed a bet on this event.")
                .font(.caption)
                .foregroundColor(.red)
        } else if let me = myPlayerId, selectedPlayerIds.contains(me) {
            Text("You can’t bet on yourself.")
                .font(.caption)
                .foregroundColor(.red)
        }
    }

    // MARK: - Helpers

    private func toggleSelection(for playerId: String) {
        if let me = myPlayerId, playerId == me { return } // ✅ cannot bet on yourself

        if selectedPlayerIds.contains(playerId) {
            selectedPlayerIds.remove(playerId)
        } else if selectedPlayerIds.count < maxSelections && !betAlreadyPlaced {
            selectedPlayerIds.insert(playerId)
        }
    }
}

#Preview {
    VegasOddsView(allSlips: .constant([]))
}
