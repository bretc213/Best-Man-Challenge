//
//  VegasOddsView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 5/24/25.
//

import SwiftUI

struct VegasOddsView: View {
    @Binding var allSlips: [BetSlip] // kept for compatibility (Firestore is the source of truth now)

    @StateObject private var playersStore = PlayersStore()
    @StateObject private var balanceStore = UserBalanceStore()
    @StateObject private var betsStore = BetsStore()

    @State private var selectedChallengeTitle: String = "Backyard Games"
    @State private var selectedPlayerIds: Set<String> = []

    @State private var lastSlip: BetSlip? = nil
    @State private var showAllSlips: Bool = false
    @State private var showPreSlip: Bool = false
    @State private var navigateToSlip: Bool = false
    @State private var pendingSlip: BetSlip? = nil

    // Better error messages (loading issues)
    @State private var showLoadErrorAlert = false
    @State private var loadErrorMessage = ""

    private let allChallenges: [String] = [
        "Backyard Games",
        "Drinking Games",
        "Golf",
        "Board Game/Video Games",
        "Scavenger Hunt",
        "Beach Day",
        "Weekly Challenges"
    ]

    private let fakeOdds: [String] = ["+100", "-300", "+200", "+400", "+600", "+800", "-200", "-150", "+500", "+300", "+250", "-110"]
    private let maxSelections: Int = 3
    private let betPerPick: Int = 100

    // MARK: - Computed

    private var selectedChallengeId: String {
        makeId(from: selectedChallengeTitle)
    }

    private var betAlreadyPlaced: Bool {
        betsStore.betAlreadyPlaced
    }

    private var selectedPlayers: [FirestorePlayer] {
        playersStore.players.filter { selectedPlayerIds.contains($0.id) }
    }

    private var selectedDisplayNames: [String] {
        selectedPlayers.map { $0.displayName }
    }

    private var selectedOdds: [String] {
        selectedPlayers.map { fakeOddsForPlayer(playerId: $0.id) }
    }

    private var totalBetAmount: Int {
        selectedPlayerIds.count * betPerPick
    }

    private var canViewSlip: Bool {
        selectedPlayerIds.count == maxSelections
        && !betAlreadyPlaced
        && balanceStore.eventBalance >= totalBetAmount
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {

                HStack(spacing: 12) {
                    Button("View All Bet Slips") {
                        showAllSlips = true
                    }
                    .sheet(isPresented: $showAllSlips) {
                        // Firestore-backed bet history
                        BetsHistoryView(playersStore: playersStore)
                    }

                    Spacer()

                    Button("Reset My Balance") {
                        AdminTools.resetMyBalance(to: 300) { err in
                            if let err = err {
                                loadErrorMessage = "Reset failed: \(err.localizedDescription)"
                                showLoadErrorAlert = true
                            }
                        }
                    }
                    .font(.footnote.bold())
                    .foregroundColor(.secondary)
                }

                infoBar

                Text("Select Challenge")
                    .font(.headline)

                Picker("Select Challenge", selection: $selectedChallengeTitle) {
                    ForEach(allChallenges, id: \.self) { challenge in
                        Text(challenge).tag(challenge)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedChallengeTitle) { _ in
                    selectedPlayerIds.removeAll()
                    betsStore.setChallengeId(selectedChallengeId)
                }

                Text("Select up to 3 Players ($100 each)")
                    .font(.headline)

                playersList

                statusText

                Button("View Bet Slip") {
                    let slip = BetSlip(
                        challenge: selectedChallengeTitle,
                        selectedPlayers: selectedDisplayNames,
                        odds: selectedOdds,
                        betAmount: totalBetAmount,
                        toWin: 0,
                        timestamp: Date()
                    )
                    pendingSlip = slip
                    showPreSlip = true
                }
                .disabled(!canViewSlip)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canViewSlip ? Color.blue : Color.gray)
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
            .navigationTitle("Vegas Odds")
            .sheet(isPresented: $showPreSlip) {
                if let slip = pendingSlip {
                    PreBetSlipView(
                        challengeId: selectedChallengeId,
                        challengeTitle: slip.challenge,
                        playerDisplayNames: slip.selectedPlayers,
                        playerIds: Array(selectedPlayerIds),
                        odds: slip.odds,
                        betAmount: slip.betAmount,
                        cancelAction: {
                            showPreSlip = false
                        },
                        onConfirmed: {
                            // optional local append for compatibility/debug
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
            balanceStore.startListening()
            betsStore.setChallengeId(selectedChallengeId)
            betsStore.startListening()
        }
        .onChange(of: playersStore.errorMessage) { msg in
            if let msg {
                loadErrorMessage = "Players couldn’t load: \(msg)"
                showLoadErrorAlert = true
            }
        }
        .onChange(of: balanceStore.errorMessage) { msg in
            if let msg {
                loadErrorMessage = "Your balance couldn’t load: \(msg)"
                showLoadErrorAlert = true
            }
        }
        .onChange(of: betsStore.errorMessage) { msg in
            if let msg {
                loadErrorMessage = "Couldn’t check existing bets: \(msg)"
                showLoadErrorAlert = true
            }
        }
    }

    // MARK: - Subviews

    private var infoBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Your balance:")
                    .foregroundColor(.secondary)
                Spacer()
                Text("$\(balanceStore.eventBalance)")
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
                Text("Challenge:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(selectedChallengeTitle)
                    .bold()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(10)
    }

    private var playersList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(playersStore.players) { player in
                    let isSelected = selectedPlayerIds.contains(player.id)
                    let odds = fakeOddsForPlayer(playerId: player.id)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(player.displayName)

                            Text(odds)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button {
                            toggleSelection(for: player.id)
                        } label: {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected ? .green : .blue)
                                .font(.system(size: 22))
                        }
                        .disabled(!isSelected && (selectedPlayerIds.count >= maxSelections || betAlreadyPlaced))
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 6)
                }
            }
            .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private var statusText: some View {
        if betAlreadyPlaced {
            Text("You’ve already placed a bet on this challenge.")
                .font(.caption)
                .foregroundColor(.red)
        } else if selectedPlayerIds.count == maxSelections && balanceStore.eventBalance < totalBetAmount {
            Text("Not enough balance. You have $\(balanceStore.eventBalance) and need $\(totalBetAmount).")
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    private func toggleSelection(for playerId: String) {
        if selectedPlayerIds.contains(playerId) {
            selectedPlayerIds.remove(playerId)
        } else if selectedPlayerIds.count < maxSelections && !betAlreadyPlaced {
            selectedPlayerIds.insert(playerId)
        }
    }

    private func makeId(from title: String) -> String {
        title
            .lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "--", with: "-")
    }

    private func fakeOddsForPlayer(playerId: String) -> String {
        let hash = abs(playerId.hashValue)
        return fakeOdds[hash % fakeOdds.count]
    }
}

#Preview {
    VegasOddsView(allSlips: .constant([]))
}
