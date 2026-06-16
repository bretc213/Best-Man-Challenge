//
//  MemoryGameView.swift
//  Best Man Challenge
//
//  Round 4 of the Halfway Point Challenge.
//
//  RULES:
//   6×4 grid (24 cards = 12 pairs) using groomsmen face photos from Assets.
//   Tap first card → flip it. Tap second card → flip it.
//   Match → pair stays revealed.
//   No match → 1 strike, both cards flip back after a brief pause.
//   12 strikes → board resets (new shuffle).
//   Clear all 12 pairs → round complete, +6 pts.
//

import SwiftUI

// MARK: - Player images (12 of 16, matching asset names)

private let playerAssets: [String] = [
    "anthonyc", "bretc", "dannyo", "isaiahs",
    "jakeo", "joeg", "joelr", "kylel",
    "matthewc", "matthewp", "mitchz", "nohlanh"
]

private let maxStrikes = 12
private let columns = 6
private let rows = 4

// MARK: - Card model

private struct MemCard: Identifiable {
    let id: UUID = UUID()
    let playerId: String  // asset name
    var isFaceUp: Bool = false
    var isMatched: Bool = false
}

// MARK: - View

struct MemoryGameView: View {
    let challenge: WeeklyChallenge
    @ObservedObject var store: HalfwayChallengeStore

    @State private var cards: [MemCard] = []
    @State private var strikes: Int = 0
    @State private var firstFlipped: UUID? = nil
    @State private var isLocked: Bool = false     // locked while mis-match animation plays
    @State private var matchedIds: Set<String> = []
    @State private var isComplete = false

    private let gridCols = Array(repeating: GridItem(.flexible(), spacing: 8), count: columns)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Status bar
                statusBar

                // Card grid
                LazyVGrid(columns: gridCols, spacing: 8) {
                    ForEach(cards) { card in
                        cardCell(card)
                    }
                }

                if isComplete {
                    completionCard
                }
            }
            .padding()
        }
        .navigationTitle("🧠 Memory")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { setup() }
    }

    // MARK: - Setup / restore

    private func setup() {
        isComplete = store.completedRounds.contains("round4")
        strikes = store.memStrikes
        matchedIds = Set(store.memMatched)

        if store.memBoard.isEmpty {
            // New game — create and shuffle board
            let board = (playerAssets + playerAssets).shuffled()
            cards = board.map { MemCard(playerId: $0) }
            let boardIds = cards.map(\.playerId)
            Task { await store.saveMemoryState(board: boardIds, matched: [], strikes: 0) }
        } else {
            // Restore board (same card order, matched cards stay face up)
            cards = store.memBoard.map { id in
                var card = MemCard(playerId: id)
                card.isMatched = matchedIds.contains(id)  // note: by playerId (two per player)
                return card
            }
            // Correctly restore matched state by UUID tracking via index
            restoreMatchedByPlayerIds()
        }
    }

    /// Mark already-matched pairs as matched in the cards array.
    private func restoreMatchedByPlayerIds() {
        // Count how many times each playerId should be matched (0, 1, or 2)
        var matchCounts: [String: Int] = [:]
        for id in matchedIds { matchCounts[id, default: 0] += 1 }

        // matched means the pair was found — mark both copies as matched
        for i in cards.indices {
            let pid = cards[i].playerId
            let timesMatched = matchCounts[pid] ?? 0
            if timesMatched >= 1 {
                cards[i].isMatched = true
            }
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pairs found")
                    .font(.caption).foregroundStyle(.secondary)
                Text("\(matchedIds.count) / \(playerAssets.count)")
                    .font(.headline)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Strikes")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text("\(strikes) / \(maxStrikes)")
                        .font(.headline)
                        .foregroundStyle(strikes >= maxStrikes - 2 ? .red : .primary)
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(strikes >= maxStrikes - 2 ? .red : .secondary)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Card cell

    private func cardCell(_ card: MemCard) -> some View {
        let isFaceUp = card.isFaceUp || card.isMatched

        return Button {
            tap(card: card)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(card.isMatched ? Color.green.opacity(0.2) : Color.secondary.opacity(0.15))
                    .aspectRatio(2/3, contentMode: .fit)

                if isFaceUp {
                    Image(card.playerId)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(card.isMatched ? Color.green : Color.clear, lineWidth: 2)
                        )
                } else {
                    Image("HomeLogo")
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                        .opacity(0.4)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(card.isMatched || card.isFaceUp || isLocked || isComplete)
        .rotation3DEffect(
            .degrees(isFaceUp ? 0 : 180),
            axis: (x: 0, y: 1, z: 0)
        )
        .animation(.easeInOut(duration: 0.3), value: isFaceUp)
    }

    // MARK: - Game logic

    private func tap(card: MemCard) {
        guard !card.isMatched, !card.isFaceUp, !isLocked else { return }

        // Flip card face up
        flipCard(id: card.id, faceUp: true)

        if let firstId = firstFlipped {
            // Second card tapped
            isLocked = true
            firstFlipped = nil

            let firstCard = cards.first { $0.id == firstId }!
            let secondCard = card

            if firstCard.playerId == secondCard.playerId && firstCard.id != secondCard.id {
                // Match!
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    matchPair(first: firstId, second: secondCard.id, playerId: firstCard.playerId)
                }
            } else {
                // No match — strike
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    flipCard(id: firstId, faceUp: false)
                    flipCard(id: secondCard.id, faceUp: false)
                    recordStrike()
                    isLocked = false
                }
            }
        } else {
            // First card tapped
            firstFlipped = card.id
        }
    }

    private func flipCard(id: UUID, faceUp: Bool) {
        if let i = cards.firstIndex(where: { $0.id == id }) {
            withAnimation { cards[i].isFaceUp = faceUp }
        }
    }

    private func matchPair(first: UUID, second: UUID, playerId: String) {
        if let i = cards.firstIndex(where: { $0.id == first }) { cards[i].isMatched = true }
        if let i = cards.firstIndex(where: { $0.id == second }) { cards[i].isMatched = true }
        matchedIds.insert(playerId)
        isLocked = false

        Task { await store.saveMemoryState(board: store.memBoard, matched: Array(matchedIds), strikes: strikes) }

        if matchedIds.count == playerAssets.count {
            withAnimation { isComplete = true }
            Task { await store.completeRound("round4") }
        }
    }

    private func recordStrike() {
        strikes += 1

        if strikes >= maxStrikes {
            // Reset board
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                resetBoard()
            }
        } else {
            Task { await store.saveMemoryState(board: store.memBoard, matched: Array(matchedIds), strikes: strikes) }
        }
    }

    private func resetBoard() {
        strikes = 0
        matchedIds = []
        firstFlipped = nil
        isLocked = false
        let newBoard = (playerAssets + playerAssets).shuffled()
        cards = newBoard.map { MemCard(playerId: $0) }
        Task { await store.saveMemoryState(board: newBoard, matched: [], strikes: 0) }
    }

    // MARK: - Completion

    private var completionCard: some View {
        VStack(spacing: 10) {
            Text("🧠 Memory cleared!")
                .font(.title.bold())
            Text("All 12 pairs matched. +6 pts earned.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
