//
//  MastermindView.swift
//  Best Man Challenge
//
//  Round 5 of the Halfway Point Challenge.
//
//  RULES:
//   5 pegs, 7 colors, no repeated colors in the secret code.
//   After each guess: aggregate feedback only (no position hints):
//     ⚫ exact  = right color, right position
//     ⚪ misplaced = right color, wrong position
//     ✗ wrong  = color not in code at all
//   Unlimited guesses. Crack the code → round complete.
//

import SwiftUI

// MARK: - Colors

private struct MMColor: Identifiable, Equatable {
    let id: String
    let color: Color
    let name: String
}

private let allColors: [MMColor] = [
    MMColor(id: "red",    color: .red,    name: "Red"),
    MMColor(id: "orange", color: .orange, name: "Orange"),
    MMColor(id: "yellow", color: .yellow, name: "Yellow"),
    MMColor(id: "green",  color: .green,  name: "Green"),
    MMColor(id: "blue",   color: .blue,   name: "Blue"),
    MMColor(id: "purple", color: .purple, name: "Purple"),
    MMColor(id: "pink",   color: .white,  name: "White")
]

// MARK: - Guess row model

private struct MMGuessRow: Identifiable {
    let id = UUID()
    let colors: [String]
    let exact: Int
    let misplaced: Int
    let wrong: Int
}

// MARK: - View

struct MastermindView: View {
    let challenge: WeeklyChallenge
    @ObservedObject var store: HalfwayChallengeStore

    @State private var secretCode: [String] = []
    @State private var guessHistory: [MMGuessRow] = []
    @State private var currentGuess: [String?] = Array(repeating: nil, count: 5)
    @State private var selectedPeg: Int? = nil   // which peg slot is active
    @State private var isComplete = false
    @State private var isSolved = false

    private var canSubmit: Bool { currentGuess.allSatisfy { $0 != nil } }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {

                    instructionCard

                    // Past guesses (oldest first)
                    if !guessHistory.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(Array(guessHistory.enumerated()), id: \.element.id) { idx, row in
                                guessRow(row, attempt: idx + 1)
                            }
                        }
                        .id("guesses")
                    }

                    // Current guess builder
                    if !isComplete {
                        currentGuessCard
                        colorPalette
                    }

                    if isComplete {
                        completionCard
                    }
                }
                .padding()
                .onChange(of: guessHistory.count) { _, _ in
                    withAnimation { proxy.scrollTo("guesses", anchor: .bottom) }
                }
            }
        }
        .navigationTitle("🔵 Mastermind")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { setupFromStore() }
    }

    // MARK: - Setup

    private func setupFromStore() {
        isComplete = store.completedRounds.contains("round5")

        if store.mmCode.isEmpty {
            // Generate new secret code
            let code = Array(allColors.shuffled().prefix(5)).map(\.id)
            secretCode = code
            Task { await store.saveMastermindState(code: code, guesses: []) }
        } else {
            secretCode = store.mmCode
        }

        guessHistory = store.mmGuesses.compactMap { d -> MMGuessRow? in
            guard let colors = d["colors"] as? [String],
                  let exact = d["exact"] as? Int,
                  let misplaced = d["misplaced"] as? Int,
                  let wrong = d["wrong"] as? Int else { return nil }
            return MMGuessRow(colors: colors, exact: exact, misplaced: misplaced, wrong: wrong)
        }

        if guessHistory.last?.exact == 5 { isSolved = true }
    }

    // MARK: - Instruction card

    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Crack the 5-color code")
                .font(.headline)
            Text("Tap a slot, then pick a color. Feedback after each guess:")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                feedbackLegend(symbol: "⚫", label: "Right spot")
                feedbackLegend(symbol: "⚪", label: "Wrong spot")
                feedbackLegend(symbol: "✗",  label: "Not in code")
            }
            .font(.caption)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func feedbackLegend(symbol: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(symbol)
            Text(label).foregroundStyle(.secondary)
        }
    }

    // MARK: - Past guess row

    private func guessRow(_ row: MMGuessRow, attempt: Int) -> some View {
        HStack(spacing: 10) {
            Text("#\(attempt)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            // Color pegs
            HStack(spacing: 6) {
                ForEach(Array(row.colors.enumerated()), id: \.offset) { _, colorId in
                    let mc = allColors.first { $0.id == colorId }
                    Circle()
                        .fill(mc?.color ?? .gray)
                        .frame(width: 32, height: 32)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
            }

            Spacer()

            // Feedback
            VStack(alignment: .trailing, spacing: 2) {
                feedbackPill("⚫ \(row.exact)", color: row.exact > 0 ? .primary : .secondary)
                feedbackPill("⚪ \(row.misplaced)", color: row.misplaced > 0 ? .primary : .secondary)
                feedbackPill("✗ \(row.wrong)", color: row.wrong > 0 ? .red.opacity(0.7) : .secondary)
            }
            .font(.caption2)
        }
        .padding(10)
        .background(row.exact == 5 ? Color.green.opacity(0.12) : Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func feedbackPill(_ text: String, color: Color) -> some View {
        Text(text)
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    // MARK: - Current guess builder

    private var currentGuessCard: some View {
        VStack(spacing: 12) {
            Text("Your guess")
                .font(.caption).foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { i in
                    let colorId = currentGuess[i]
                    let mc = colorId.flatMap { id in allColors.first { $0.id == id } }
                    let isSelected = selectedPeg == i

                    Button {
                        selectedPeg = i
                    } label: {
                        ZStack {
                            Circle()
                                .fill(mc?.color ?? Color.secondary.opacity(0.2))
                                .frame(width: 44, height: 44)
                                .shadow(color: .black.opacity(0.2), radius: 3)
                            if colorId == nil {
                                Text("\(i + 1)").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .overlay(
                            Circle()
                                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                submitGuess()
            } label: {
                Text("Submit Guess")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Color palette

    private var colorPalette: some View {
        HStack(spacing: 12) {
            ForEach(allColors) { mc in
                let alreadyUsed = currentGuess.compactMap { $0 }.contains(mc.id)
                Button {
                    guard let peg = selectedPeg, !alreadyUsed else { return }
                    currentGuess[peg] = mc.id
                    // Auto-advance to next empty slot
                    selectedPeg = currentGuess.firstIndex(where: { $0 == nil })
                } label: {
                    Circle()
                        .fill(alreadyUsed ? mc.color.opacity(0.25) : mc.color)
                        .frame(width: 36, height: 36)
                        .shadow(color: .black.opacity(0.2), radius: 2)
                        .overlay(
                            Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(alreadyUsed)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Submit

    private func submitGuess() {
        let guess = currentGuess.compactMap { $0 }
        guard guess.count == 5 else { return }

        let (exact, misplaced) = feedback(guess: guess, code: secretCode)
        let wrong = 5 - exact - misplaced
        let row = MMGuessRow(colors: guess, exact: exact, misplaced: misplaced, wrong: wrong)
        guessHistory.append(row)

        // Clear current guess
        currentGuess = Array(repeating: nil, count: 5)
        selectedPeg = nil

        // Persist
        let rawGuesses: [[String: Any]] = guessHistory.map { g in
            ["colors": g.colors, "exact": g.exact, "misplaced": g.misplaced, "wrong": g.wrong]
        }
        Task { await store.saveMastermindState(code: secretCode, guesses: rawGuesses) }

        if exact == 5 {
            withAnimation { isComplete = true; isSolved = true }
            Task { await store.completeRound("round5") }
        }
    }

    // MARK: - Feedback calculation

    private func feedback(guess: [String], code: [String]) -> (exact: Int, misplaced: Int) {
        var exact = 0
        var misplaced = 0

        // Exact matches
        for i in 0..<5 where guess[i] == code[i] { exact += 1 }

        // Color matches (no repeats in either, so just count intersection minus exact)
        let guessSet = Set(guess)
        let codeSet = Set(code)
        let colorMatches = guessSet.intersection(codeSet).count
        misplaced = colorMatches - exact

        return (exact, misplaced)
    }

    // MARK: - Completion

    private var completionCard: some View {
        VStack(spacing: 12) {
            Text("🔵 Code Cracked!")
                .font(.title.bold())
            HStack(spacing: 8) {
                ForEach(secretCode, id: \.self) { colorId in
                    if let mc = allColors.first(where: { $0.id == colorId }) {
                        Circle().fill(mc.color).frame(width: 36, height: 36)
                    }
                }
            }
            Text("Solved in \(guessHistory.count) guess\(guessHistory.count == 1 ? "" : "es"). +6 pts earned.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
