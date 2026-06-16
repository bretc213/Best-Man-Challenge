//
//  YahtzeeLiteView.swift
//  Best Man Challenge
//
//  Round 3 of the Halfway Point Challenge.
//
//  RULES:
//   Complete all 6 lower-section Yahtzee categories (any order):
//     1. Three of a Kind
//     2. Four of a Kind
//     3. Full House
//     4. Small Straight (4 sequential values)
//     5. Large Straight (5 sequential values)
//     6. Yahtzee (all 5 same)
//   3 rolls per turn. Hold any dice between rolls.
//   Don't hit the category in 3 rolls → try again (no penalty).
//   Complete all 6 → round done, +6 pts.
//

import SwiftUI

// MARK: - Categories

private struct YahtzeeCategory: Identifiable {
    let id: String
    let name: String
    let description: String
    let emoji: String

    func isAchieved(by dice: [Int]) -> Bool {
        let counts = Dictionary(grouping: dice, by: { $0 }).mapValues(\.count)
        let sorted = dice.sorted()
        switch id {
        case "three_kind":
            return counts.values.contains(where: { $0 >= 3 })
        case "four_kind":
            return counts.values.contains(where: { $0 >= 4 })
        case "full_house":
            return counts.values.contains(3) && counts.values.contains(2)
        case "small_straight":
            let unique = Set(sorted)
            let sequences = [[1,2,3,4],[2,3,4,5],[3,4,5,6]]
            return sequences.contains { seq in seq.allSatisfy { unique.contains($0) } }
        case "large_straight":
            let unique = Set(sorted)
            return unique == Set([1,2,3,4,5]) || unique == Set([2,3,4,5,6])
        case "yahtzee":
            return Set(dice).count == 1
        default:
            return false
        }
    }
}

private let allCategories: [YahtzeeCategory] = [
    YahtzeeCategory(id: "three_kind",     name: "Three of a Kind",  description: "3+ dice same value",           emoji: "3️⃣"),
    YahtzeeCategory(id: "four_kind",      name: "Four of a Kind",   description: "4+ dice same value",           emoji: "4️⃣"),
    YahtzeeCategory(id: "full_house",     name: "Full House",       description: "3 of one + 2 of another",      emoji: "🏠"),
    YahtzeeCategory(id: "small_straight", name: "Small Straight",   description: "Any 4 sequential values",      emoji: "↗️"),
    YahtzeeCategory(id: "large_straight", name: "Large Straight",   description: "All 5 sequential values",      emoji: "🚀"),
    YahtzeeCategory(id: "yahtzee",        name: "Yahtzee!",         description: "All 5 dice the same",          emoji: "⭐")
]

// MARK: - View

struct YahtzeeLiteView: View {
    let challenge: WeeklyChallenge
    @ObservedObject var store: HalfwayChallengeStore

    @State private var dice: [Int] = [1, 1, 1, 1, 1]
    @State private var held: [Bool] = Array(repeating: false, count: 5)
    @State private var rollsLeft: Int = 3
    @State private var completedIds: Set<String> = []
    @State private var isComplete = false
    @State private var justScored: String? = nil  // category ID just completed
    @State private var isRolling = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Categories checklist
                categoriesGrid

                // Dice
                diceSection

                // Roll button
                rollButton

                // Current roll feedback
                if !isRolling, rollsLeft < 3 {
                    currentRollFeedback
                }

                if isComplete {
                    completionCard
                }
            }
            .padding()
        }
        .navigationTitle("🎲 Yahtzee Lite")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { setup() }
    }

    // MARK: - Setup

    private func setup() {
        completedIds = Set(store.yhComplete)
        isComplete = store.completedRounds.contains("round3")
    }

    // MARK: - Categories grid

    private var categoriesGrid: some View {
        VStack(spacing: 8) {
            Text("Complete all 6 categories")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(allCategories) { cat in
                    let done = completedIds.contains(cat.id)
                    let justDone = justScored == cat.id

                    HStack(spacing: 8) {
                        Text(cat.emoji)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cat.name).font(.caption.bold())
                            Text(cat.description).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if done {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                    .padding(10)
                    .background(justDone ? Color.green.opacity(0.2) :
                                done ? Color.green.opacity(0.08) :
                                Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(done ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Dice section

    private var diceSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Dice")
                    .font(.headline)
                Spacer()
                Text("\(rollsLeft) roll\(rollsLeft == 1 ? "" : "s") left")
                    .font(.caption)
                    .foregroundStyle(rollsLeft == 0 ? .red : .secondary)
            }

            HStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { i in
                    dieView(index: i)
                }
            }

            if rollsLeft < 3 && rollsLeft > 0 {
                Text("Tap dice to hold/release before rolling")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func dieView(index i: Int) -> some View {
        let isHeld = held[i]
        return Button {
            guard rollsLeft < 3 else { return }  // can't hold before first roll
            held[i].toggle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHeld ? Color.yellow.opacity(0.25) : Color(.systemBackground))
                    .frame(width: 54, height: 54)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isHeld ? Color.yellow : Color.secondary.opacity(0.2), lineWidth: 2)
                    )
                Text(dieFace(dice[i]))
                    .font(.system(size: 28))
            }
        }
        .buttonStyle(.plain)
        .disabled(rollsLeft == 3 || isRolling)
    }

    private func dieFace(_ value: Int) -> String {
        ["⚀","⚁","⚂","⚃","⚄","⚅"][value - 1]
    }

    // MARK: - Roll button

    private var rollButton: some View {
        VStack(spacing: 8) {
            Button {
                rollDice()
            } label: {
                Text(rollsLeft == 3 ? "Roll Dice" : "Roll Again")
                    .font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(rollsLeft == 0 || isRolling || isComplete)

            if rollsLeft == 0 {
                Button {
                    newTurn()
                } label: {
                    Text("Try Again →")
                        .font(.subheadline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
    }

    // MARK: - Current roll feedback

    private var currentRollFeedback: some View {
        let achieved = allCategories.filter { cat in
            !completedIds.contains(cat.id) && cat.isAchieved(by: dice)
        }

        return Group {
            if achieved.isEmpty {
                Text("No new categories completed yet — keep rolling or try again.")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 6) {
                    Text("You can complete:")
                        .font(.caption.bold())
                    ForEach(achieved) { cat in
                        Button {
                            score(category: cat)
                        } label: {
                            Label(cat.name, systemImage: "checkmark.circle")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Completion

    private var completionCard: some View {
        VStack(spacing: 10) {
            Text("🎲 Yahtzee Complete!")
                .font(.title.bold())
            Text("All 6 categories filled. +6 pts earned.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Game logic

    private func rollDice() {
        guard rollsLeft > 0 else { return }
        isRolling = true
        justScored = nil

        withAnimation(.easeInOut(duration: 0.3)) {
            for i in 0..<5 where !held[i] {
                dice[i] = Int.random(in: 1...6)
            }
            rollsLeft -= 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isRolling = false
        }
    }

    private func score(category: YahtzeeCategory) {
        completedIds.insert(category.id)
        justScored = category.id
        Task { await store.saveYahtzeeComplete(Array(completedIds)) }

        if completedIds.count == allCategories.count {
            withAnimation { isComplete = true }
            Task { await store.completeRound("round3") }
        } else {
            newTurn()
        }
    }

    private func newTurn() {
        dice = [Int.random(in: 1...6), Int.random(in: 1...6),
                Int.random(in: 1...6), Int.random(in: 1...6), Int.random(in: 1...6)]
        held = Array(repeating: false, count: 5)
        rollsLeft = 3
        justScored = nil
    }
}
