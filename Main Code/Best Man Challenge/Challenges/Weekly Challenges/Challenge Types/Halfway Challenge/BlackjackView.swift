//
//  BlackjackView.swift
//  Best Man Challenge
//
//  Round 2 of the Halfway Point Challenge.
//
//  RULES:
//   Beat the dealer 100 times (cumulative wins, with streak multiplier).
//   Standard rules: dealer hits on ≤16, stands on ≥17. Ace = 11 or 1.
//   Streak multiplier: each consecutive win increases multiplier by 1 (max 3×).
//   Lose or push → streak resets to 0, multiplier back to 1×.
//   100 wins → round complete, +6 pts.
//

import SwiftUI

// MARK: - Game state

private enum BJGameState {
    case idle           // between hands, show Deal button
    case playerTurn     // player's turn
    case dealerTurn     // dealer playing out (auto)
    case result(won: Bool, message: String)
}

// MARK: - View

struct BlackjackView: View {
    let challenge: WeeklyChallenge
    @ObservedObject var store: HalfwayChallengeStore

    @State private var playerHand: [PlayingCard] = []
    @State private var dealerHand: [PlayingCard] = []
    @State private var deck: CardDeck = .fresh()
    @State private var gameState: BJGameState = .idle
    @State private var wins: Int = 0
    @State private var streak: Int = 0          // consecutive wins this session
    @State private var isComplete = false
    @State private var isDealerRevealed = false  // hide dealer hole card until dealer turn

    private let winsNeeded = 100
    private var multiplier: Int { streak + 1 }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Win progress
                winsProgress

                // Dealer hand
                handSection(title: "Dealer", cards: dealerHand, hideHole: !isDealerRevealed)

                // Player hand
                handSection(title: "You", cards: playerHand, hideHole: false)

                // Action area
                actionArea

                if isComplete {
                    completionCard
                }
            }
            .padding()
        }
        .navigationTitle("🃏 Blackjack")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { setup() }
    }

    // MARK: - Setup

    private func setup() {
        wins = store.bjWins
        isComplete = store.completedRounds.contains("round2")
    }

    // MARK: - Wins progress

    private var winsProgress: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Wins")
                    .font(.headline)
                Spacer()
                Text("\(wins) / \(winsNeeded)")
                    .font(.headline)
                    .foregroundStyle(wins >= winsNeeded ? .green : .primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.2)).frame(height: 10)
                    RoundedRectangle(cornerRadius: 6).fill(Color.green)
                        .frame(width: geo.size.width * CGFloat(min(wins, winsNeeded)) / CGFloat(winsNeeded), height: 10)
                        .animation(.easeInOut, value: wins)
                }
            }
            .frame(height: 10)

            // Streak / multiplier indicator
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(streak > 0 ? .orange : .secondary)
                    .font(.subheadline)
                Text(streak == 0 ? "No streak" : "\(streak) win streak")
                    .font(.subheadline)
                    .foregroundStyle(streak > 0 ? .orange : .secondary)
                Spacer()
                if multiplier > 1 {
                    Text("\(multiplier)× multiplier")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Hand display

    private func handSection(title: String, cards: [PlayingCard], hideHole: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if !cards.isEmpty {
                    let total = hideHole ? handValue([cards[0]]) : handValue(cards)
                    Text(hideHole ? "\(total) + ?" : "\(total)")
                        .font(.subheadline.bold())
                        .foregroundStyle(handValue(cards) > 21 ? .red : .primary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { idx, card in
                        if hideHole && idx == 1 {
                            // Hidden hole card
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 60, height: 80)
                                .overlay(Text("?").font(.title.bold()).foregroundStyle(.white))
                        } else {
                            cardView(card)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func cardView(_ card: PlayingCard) -> some View {
        VStack(spacing: 4) {
            Text(card.displayValue).font(.title2.bold()).foregroundStyle(card.suit.color)
            Text(card.suit.symbol).font(.title3).foregroundStyle(card.suit.color)
        }
        .frame(width: 60, height: 80)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
    }

    // MARK: - Action area

    @ViewBuilder
    private var actionArea: some View {
        switch gameState {
        case .idle:
            Button { deal() } label: {
                Text(wins == 0 ? "Deal First Hand" : "Deal Next Hand")
                    .font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isComplete)

        case .playerTurn:
            HStack(spacing: 12) {
                Button { hit() } label: {
                    Text("Hit").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button { stand() } label: {
                    Text("Stand").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }

        case .dealerTurn:
            ProgressView("Dealer playing…").padding()

        case .result(let won, let message):
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: won ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(won ? .green : .red)
                        .font(.title2)
                    Text(message)
                        .font(.headline)
                        .foregroundStyle(won ? .green : .red)
                }

                Button { resetHand() } label: {
                    Text("Next Hand →").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background((won ? Color.green : Color.red).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Completion

    private var completionCard: some View {
        VStack(spacing: 10) {
            Text("🃏 House busted — you win!")
                .font(.title.bold())
            Text("100 wins banked. +6 pts earned.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Game logic

    private func deal() {
        if deck.count < 10 { deck = .fresh() }
        playerHand = [deck.draw()!, deck.draw()!]
        dealerHand = [deck.draw()!, deck.draw()!]
        isDealerRevealed = false

        // Check for player blackjack
        if handValue(playerHand) == 21 {
            resolveHand()
        } else {
            gameState = .playerTurn
        }
    }

    private func hit() {
        playerHand.append(deck.draw()!)
        if handValue(playerHand) > 21 {
            resolveHand()
        }
    }

    private func stand() {
        isDealerRevealed = true
        gameState = .dealerTurn

        // Dealer plays out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            dealerPlay()
        }
    }

    private func dealerPlay() {
        while handValue(dealerHand) < 17 {
            dealerHand.append(deck.draw()!)
        }
        resolveHand()
    }

    private func resolveHand() {
        isDealerRevealed = true
        let playerTotal = handValue(playerHand)
        let dealerTotal = handValue(dealerHand)
        let curMult = multiplier   // capture before streak changes

        enum Outcome { case win, loss, push }

        let outcome: Outcome
        let message: String

        if playerTotal > 21 {
            outcome = .loss
            message = "Bust! Dealer wins. Streak reset."
        } else if dealerTotal > 21 {
            outcome = .win
            message = "Dealer busts! You win!" + (curMult > 1 ? " +\(curMult)× wins!" : "")
        } else if playerTotal == dealerTotal {
            outcome = .push
            message = "Push — no wins, streak holds."
        } else if playerTotal > dealerTotal {
            outcome = .win
            message = "\(playerTotal) beats \(dealerTotal)." + (curMult > 1 ? " +\(curMult)× wins!" : "")
        } else {
            outcome = .loss
            message = "Dealer wins. \(dealerTotal) beats \(playerTotal). Streak reset."
        }

        switch outcome {
        case .win:
            wins += curMult
            streak += 1
            Task { await store.saveBlackjackWins(wins) }
            if wins >= winsNeeded {
                withAnimation { isComplete = true }
                Task { await store.completeRound("round2") }
            }
        case .loss:
            streak = 0
        case .push:
            break   // streak unchanged, no wins awarded
        }

        withAnimation { gameState = .result(won: outcome == .win, message: message) }
    }

    private func resetHand() {
        playerHand = []
        dealerHand = []
        isDealerRevealed = false
        gameState = .idle
    }

    // MARK: - Hand value

    private func handValue(_ cards: [PlayingCard]) -> Int {
        var total = 0
        var aces = 0
        for card in cards {
            if card.value == 14 {
                total += 11
                aces += 1
            } else if card.value >= 10 {
                total += 10
            } else {
                total += card.value
            }
        }
        while total > 21 && aces > 0 {
            total -= 10
            aces -= 1
        }
        return total
    }
}
