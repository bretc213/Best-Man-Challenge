//
//  RideTheBusView.swift
//  Best Man Challenge
//
//  Round 1 of the Halfway Point Challenge.
//
//  RULES:
//   Answer all 4 questions in sequence without a mistake → round complete.
//   Wrong answer → back to Q1, NEW card drawn (deck keeps depleting).
//   Deck reshuffles only when empty.
//   Cards drawn in the current run are shown for reference (Q2 uses Q1 card, Q3 uses Q1+Q2, etc.)
//

import SwiftUI

// MARK: - Questions

private enum RTBQuestion: Int, CaseIterable {
    case redOrBlack      = 0
    case higherOrLower   = 1
    case insideOrOutside = 2
    case suit            = 3

    var prompt: String {
        switch self {
        case .redOrBlack:      return "Red or Black?"
        case .higherOrLower:   return "Higher or Lower?"
        case .insideOrOutside: return "Inside or Outside?"
        case .suit:            return "What Suit?"
        }
    }

    var stepLabel: String {
        switch self {
        case .redOrBlack:      return "Q1"
        case .higherOrLower:   return "Q2"
        case .insideOrOutside: return "Q3"
        case .suit:            return "Q4"
        }
    }
}

// MARK: - View

struct RideTheBusView: View {
    let challenge: WeeklyChallenge
    @ObservedObject var store: HalfwayChallengeStore

    @State private var deck: CardDeck = .fresh()
    @State private var currentQ: RTBQuestion = .redOrBlack
    @State private var runCards: [PlayingCard] = []     // cards drawn in this run
    @State private var revealedCard: PlayingCard?        // card just drawn for current Q
    @State private var resultCorrect: Bool?              // nil = awaiting guess
    @State private var isComplete = false
    @State private var isAnimating = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Progress steps
                stepsRow

                // Reference cards from this run
                if !runCards.isEmpty {
                    referenceCardsRow
                }

                // Current question card
                questionCard

                // Result overlay
                if let correct = resultCorrect {
                    resultBanner(correct: correct)
                }

                // Complete celebration
                if isComplete {
                    completionCard
                }
            }
            .padding()
        }
        .navigationTitle("🚌 Ride the Bus")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { setupFromStore() }
    }

    // MARK: - Setup from persisted state

    private func setupFromStore() {
        if !store.rtbDeckCodes.isEmpty {
            deck = CardDeck.from(codes: store.rtbDeckCodes)
        }
        currentQ = RTBQuestion(rawValue: store.rtbQuestion) ?? .redOrBlack
        runCards = store.rtbRunCards.compactMap { PlayingCard.from(code: $0) }
        isComplete = store.completedRounds.contains("round1")
    }

    // MARK: - Steps row

    private var stepsRow: some View {
        HStack(spacing: 8) {
            ForEach(RTBQuestion.allCases, id: \.rawValue) { q in
                let isDone = q.rawValue < currentQ.rawValue || isComplete
                let isCurrent = q == currentQ && !isComplete

                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(isDone ? Color.green.opacity(0.2) :
                                  isCurrent ? Color.accentColor.opacity(0.2) :
                                  Color.secondary.opacity(0.1))
                            .frame(width: 36, height: 36)
                        if isDone {
                            Image(systemName: "checkmark").foregroundStyle(.green).font(.caption.bold())
                        } else {
                            Text(q.stepLabel).font(.caption2.bold())
                                .foregroundStyle(isCurrent ? Color.accentColor : Color.secondary)
                        }
                    }
                    Text(["R/B","Hi/Lo","In/Out","Suit"][q.rawValue])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Reference cards

    private var referenceCardsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your cards this run:")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(Array(runCards.enumerated()), id: \.offset) { idx, card in
                    miniCardView(card, label: "Q\(idx + 1)")
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Question card

    @ViewBuilder
    private var questionCard: some View {
        if isComplete { EmptyView() }
        else {
            VStack(spacing: 16) {
                Text(currentQ.prompt)
                    .font(.title2.bold())

                // Hint text
                hintText

                // Revealed card (shown after guess)
                if let card = revealedCard {
                    bigCardView(card)
                        .transition(.scale.combined(with: .opacity))
                }

                // Answer buttons
                if resultCorrect == nil {
                    answerButtons
                }
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private var hintText: some View {
        switch currentQ {
        case .redOrBlack:
            Text("Ace is high (14), 2 is low").font(.caption).foregroundStyle(.secondary)
        case .higherOrLower:
            if let q1 = runCards.first {
                Text("Your Q1 card: \(q1.displayFull)").font(.caption).foregroundStyle(.secondary)
            }
        case .insideOrOutside:
            if runCards.count >= 2 {
                let lo = min(runCards[0].value, runCards[1].value)
                let hi = max(runCards[0].value, runCards[1].value)
                Text("Range: \(runCards[0].displayValue)–\(runCards[1].displayValue) → inside means \(lo+1)–\(hi-1)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .suit:
            Text("Pick the exact suit of the next card").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var answerButtons: some View {
        switch currentQ {
        case .redOrBlack:
            HStack(spacing: 12) {
                answerButton("Red ♥♦", color: .red)   { guess(redOrBlack: true) }
                answerButton("Black ♠♣", color: .white) { guess(redOrBlack: false) }
            }
        case .higherOrLower:
            HStack(spacing: 12) {
                answerButton("Higher ↑", color: .accentColor) { guess(higher: true) }
                answerButton("Lower ↓",  color: .orange)      { guess(higher: false) }
            }
        case .insideOrOutside:
            HStack(spacing: 12) {
                answerButton("Inside",  color: .green)  { guess(inside: true) }
                answerButton("Outside", color: .purple) { guess(inside: false) }
            }
        case .suit:
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(CardSuit.allCases, id: \.rawValue) { suit in
                    answerButton("\(suit.symbol) \(suit.rawValue == "S" ? "Spades" : suit.rawValue == "H" ? "Hearts" : suit.rawValue == "D" ? "Diamonds" : "Clubs")",
                                 color: suit.isRed ? .red : .white) {
                        guess(suit: suit)
                    }
                }
            }
        }
    }

    private func answerButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isAnimating)
    }

    // MARK: - Result banner

    private func resultBanner(correct: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(correct ? .green : .red)
            Text(correct ? "Correct! Next question →" : "Wrong — back to Q1!")
                .font(.headline)
                .foregroundStyle(correct ? .green : .red)
        }
        .padding()
        .background((correct ? Color.green : Color.red).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                if correct {
                    advanceQuestion()
                } else {
                    restartRun()
                }
            }
        }
    }

    // MARK: - Completion

    private var completionCard: some View {
        VStack(spacing: 12) {
            Text("🚌 You rode the bus!")
                .font(.title.bold())
            Text("All 4 questions correct in a row. +6 pts earned.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Card views

    private func bigCardView(_ card: PlayingCard) -> some View {
        VStack(spacing: 4) {
            Text(card.displayValue)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(card.suit.color)
            Text(card.suit.symbol)
                .font(.system(size: 32))
                .foregroundStyle(card.suit.color)
        }
        .frame(width: 100, height: 130)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
    }

    private func miniCardView(_ card: PlayingCard, label: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            VStack(spacing: 2) {
                Text(card.displayValue).font(.headline).foregroundStyle(card.suit.color)
                Text(card.suit.symbol).font(.caption).foregroundStyle(card.suit.color)
            }
            .frame(width: 44, height: 56)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
        }
    }

    // MARK: - Game logic

    private mutating func drawCard() -> PlayingCard {
        if deck.isEmpty { deck = .fresh() }
        return deck.draw() ?? { deck = .fresh(); return deck.draw()! }()
    }

    private func guess(redOrBlack isRed: Bool) {
        let card = nextCard()
        revealedCard = card
        let correct = card.suit.isRed == isRed
        resolve(card: card, correct: correct)
    }

    private func guess(higher: Bool) {
        guard let q1 = runCards.first else { return }
        let card = nextCard()
        revealedCard = card
        let correct: Bool
        if card.value == q1.value {
            correct = false  // identical = auto fail
        } else {
            correct = higher ? (card.value > q1.value) : (card.value < q1.value)
        }
        resolve(card: card, correct: correct)
    }

    private func guess(inside: Bool) {
        guard runCards.count >= 2 else { return }
        let lo = min(runCards[0].value, runCards[1].value)
        let hi = max(runCards[0].value, runCards[1].value)
        let card = nextCard()
        revealedCard = card
        let correct: Bool
        if card.value == lo || card.value == hi {
            correct = false  // boundary = auto fail
        } else if inside {
            correct = card.value > lo && card.value < hi
        } else {
            correct = card.value < lo || card.value > hi
        }
        resolve(card: card, correct: correct)
    }

    private func guess(suit: CardSuit) {
        let card = nextCard()
        revealedCard = card
        resolve(card: card, correct: card.suit == suit)
    }

    private func nextCard() -> PlayingCard {
        if deck.isEmpty { deck = .fresh() }
        return deck.draw() ?? PlayingCard(suit: .spades, value: 14)
    }

    private func resolve(card: PlayingCard, correct: Bool) {
        isAnimating = true
        withAnimation { resultCorrect = correct }

        // Persist deck state immediately after draw
        Task {
            await store.saveRTBState(
                deckCodes: deck.codes,
                question: currentQ.rawValue,
                runCards: (runCards + [card]).map(\.code)
            )
        }
    }

    private func advanceQuestion() {
        runCards.append(revealedCard!)
        revealedCard = nil
        resultCorrect = nil
        isAnimating = false

        if currentQ == .suit {
            // All 4 done!
            withAnimation { isComplete = true }
            Task { await store.completeRound("round1") }
        } else {
            currentQ = RTBQuestion(rawValue: currentQ.rawValue + 1)!
            Task {
                await store.saveRTBState(
                    deckCodes: deck.codes,
                    question: currentQ.rawValue,
                    runCards: runCards.map(\.code)
                )
            }
        }
    }

    private func restartRun() {
        // Card was already drawn and depleted — just clear the run
        runCards = []
        revealedCard = nil
        resultCorrect = nil
        currentQ = .redOrBlack
        isAnimating = false

        Task {
            await store.saveRTBState(
                deckCodes: deck.codes,
                question: 0,
                runCards: []
            )
        }
    }
}
