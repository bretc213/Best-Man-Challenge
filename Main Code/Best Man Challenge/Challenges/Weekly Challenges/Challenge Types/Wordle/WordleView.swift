//
//  WordleTileState.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 2/16/26.
//

import SwiftUI
import FirebaseAuth

// MARK: - Wordle Evaluation

enum WordleTileState: String, Codable {
    case empty
    case correct
    case present
    case absent
}

struct WordleRow: Identifiable {
    let id = UUID()
    var guess: String
    var states: [WordleTileState]
}

@MainActor
final class WordleGameViewModel: ObservableObject {

    let wordLength: Int
    let maxAttempts: Int

    @Published var rows: [WordleRow] = []
    @Published var currentInput: String = ""
    @Published var isSolved: Bool = false
    @Published var attemptsUsed: Int = 0
    @Published var errorMessage: String?

    private let answer: String // uppercase

    init(answer: String, wordLength: Int, maxAttempts: Int) {
        self.answer = answer.uppercased()
        self.wordLength = wordLength
        self.maxAttempts = maxAttempts

        self.rows = (0..<maxAttempts).map { _ in
            WordleRow(
                guess: String(repeating: " ", count: wordLength),
                states: Array(repeating: .empty, count: wordLength)
            )
        }
    }

    /// ✅ Hydrate the board from previously submitted guesses (progress or finished).
    init(answer: String, wordLength: Int, maxAttempts: Int, submittedGuesses: [String]) {
        self.answer = answer.uppercased()
        self.wordLength = wordLength
        self.maxAttempts = maxAttempts

        self.rows = (0..<maxAttempts).map { _ in
            WordleRow(
                guess: String(repeating: " ", count: wordLength),
                states: Array(repeating: .empty, count: wordLength)
            )
        }

        let cleaned = submittedGuesses
            .map { $0.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count == wordLength }

        for g in cleaned.prefix(maxAttempts) {
            let states = evaluate(guess: g, answer: self.answer)
            rows[attemptsUsed] = WordleRow(guess: g, states: states)
            attemptsUsed += 1
            if g == self.answer {
                isSolved = true
                break
            }
        }

        currentInput = ""
        errorMessage = nil
    }

    func typeLetter(_ letter: String) {
        guard !isSolved else { return }
        guard attemptsUsed < maxAttempts else { return }
        guard currentInput.count < wordLength else { return }

        errorMessage = nil
        currentInput.append(letter.uppercased())
        syncCurrentRow()
    }

    func backspace() {
        guard !isSolved else { return }
        guard attemptsUsed < maxAttempts else { return }
        guard !currentInput.isEmpty else { return }

        errorMessage = nil
        currentInput.removeLast()
        syncCurrentRow()
    }

    func submit() {
        guard !isSolved else { return }
        guard attemptsUsed < maxAttempts else { return }

        let guess = currentInput.uppercased()
        guard guess.count == wordLength else {
            errorMessage = "Not enough letters."
            return
        }

        let states = evaluate(guess: guess, answer: answer)
        rows[attemptsUsed] = WordleRow(guess: guess, states: states)

        attemptsUsed += 1
        currentInput = ""
        errorMessage = nil

        if guess == answer {
            isSolved = true
        } else if attemptsUsed < maxAttempts {
            rows[attemptsUsed] = WordleRow(
                guess: String(repeating: " ", count: wordLength),
                states: Array(repeating: .empty, count: wordLength)
            )
        }
    }

    private func syncCurrentRow() {
        guard attemptsUsed < rows.count else { return }

        var padded = currentInput.uppercased()
        if padded.count < wordLength {
            padded += String(repeating: " ", count: wordLength - padded.count)
        }

        rows[attemptsUsed] = WordleRow(
            guess: padded,
            states: Array(repeating: .empty, count: wordLength)
        )
    }

    private func evaluate(guess: String, answer: String) -> [WordleTileState] {
        let g = Array(guess)
        let a = Array(answer)

        var result = Array(repeating: WordleTileState.absent, count: wordLength)
        var remaining: [Character: Int] = [:]

        for ch in a { remaining[ch, default: 0] += 1 }

        // Pass 1: correct
        for i in 0..<wordLength {
            if g[i] == a[i] {
                result[i] = .correct
                remaining[g[i], default: 0] -= 1
            }
        }

        // Pass 2: present
        for i in 0..<wordLength {
            if result[i] == .correct { continue }
            let ch = g[i]
            if let count = remaining[ch], count > 0 {
                result[i] = .present
                remaining[ch] = count - 1
            } else {
                result[i] = .absent
            }
        }

        return result
    }
}

// MARK: - Wordle View (Host)

struct WordleView: View {
    @EnvironmentObject var challengeManager: WeeklyChallengeManager

    let challengeId: String
    let prompt: String
    let answer: String?
    let wordLength: Int?
    let maxAttempts: Int?
    let isLocked: Bool

    @State private var vm: WordleGameViewModel?
    @State private var didSubmitResult: Bool = false
    @State private var submitError: String?

    private var wl: Int { wordLength ?? 5 }
    private var ma: Int { maxAttempts ?? 6 }

    // ✅ LOCAL persistence key (fast + reliable restore)
    private var localKey: String {
        let uid = Auth.auth().currentUser?.uid ?? "anon"
        let ans = (answer ?? "").uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return "wordle_progress_\(challengeId)_\(uid)_\(ans)"
    }

    private var isPuzzleReady: Bool {
        let ans = (answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !ans.isEmpty && ans.count == wl
    }

    private var finishedFromManager: Bool {
        challengeManager.lastSubmission?.isWordleFinished == true
    }

    var body: some View {
        VStack(spacing: 16) {
            header

            if !isPuzzleReady {
                notReadyState
            } else if let vm {
                // If finished (win/lose), lock the entire play loop.
                let finished = finishedFromManager || (vm.isSolved || vm.attemptsUsed >= vm.maxAttempts)

                WordleGameView(
                    vm: vm,
                    isLocked: isLocked || finished,
                    onSubmittedGuess: { guessesSoFar in
                        // ✅ Save locally immediately so leaving/re-entering always restores
                        saveLocalProgress(guessesSoFar)

                        // ✅ Also save to Firestore (best effort)
                        guard !(isLocked || finishedFromManager) else { return }
                        Task { @MainActor in
                            do {
                                try await challengeManager.saveWordleProgress(challengeId: challengeId, guesses: guessesSoFar)
                            } catch {
                                // don’t hard fail UI
                                print("⚠️ saveWordleProgress failed:", error.localizedDescription)
                            }
                        }
                    },
                    onFinished: { attempts, solved, guesses in
                        // Clear local progress once the game is finished.
                        // (We still show the board because VM is hydrated.)
                        submitOnce(attemptsUsed: attempts, solved: solved, guesses: guesses)
                    }
                )

                if let submitError, !submitError.isEmpty {
                    Text(submitError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

            } else {
                ProgressView().padding(.top, 24)
            }
        }
        .padding()
        .task(id: vmLoadKey) {
            await configureVM()
        }
    }

    private var vmLoadKey: String {
        let ans = (answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(challengeId)|\(ans)|\(wl)|\(ma)"
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(prompt).font(.headline)
            Text("Guess the word in \(ma) tries.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var notReadyState: some View {
        VStack(spacing: 10) {
            Text("Puzzle not ready yet.")
                .font(.headline)
            Text("Check back soon — the weekly word hasn’t been posted.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func configureVM() async {
        guard isPuzzleReady else {
            vm = nil
            didSubmitResult = false
            submitError = nil
            return
        }

        let ans = (answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) Local progress (instant)
        let localGuesses = loadLocalProgress()

        // 2) Firestore progress (best effort) — only if local is empty
        let remoteGuesses: [String]
        if localGuesses.isEmpty {
            remoteGuesses = await challengeManager.loadWordleProgress(challengeId: challengeId)
        } else {
            remoteGuesses = []
        }

        let guesses = !localGuesses.isEmpty ? localGuesses : remoteGuesses

        vm = WordleGameViewModel(answer: ans, wordLength: wl, maxAttempts: ma, submittedGuesses: guesses)
        didSubmitResult = false
        submitError = nil
    }

    private func submitOnce(attemptsUsed: Int, solved: Bool, guesses: [String]) {
        guard !didSubmitResult else { return }
        guard !isLocked else { return }
        guard !finishedFromManager else { return }

        didSubmitResult = true
        submitError = nil

        Task { @MainActor in
            do {
                try await challengeManager.submitWordleResult(
                    challengeId: challengeId,
                    attemptsUsed: attemptsUsed,
                    solved: solved,
                    guesses: guesses,
                    maxAttempts: ma
                )

                // ✅ Finished — wipe local progress so you can’t “resume” a completed game.
                clearLocalProgress()

            } catch {
                self.submitError = "Couldn’t submit result. Try again."
                print("❌ Wordle submit failed:", error.localizedDescription)
                self.didSubmitResult = false
            }
        }
    }

    // MARK: - Local persistence helpers

    private func saveLocalProgress(_ guesses: [String]) {
        let cleaned = guesses
            .map { $0.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count == wl }
        UserDefaults.standard.set(cleaned, forKey: localKey)
    }

    private func loadLocalProgress() -> [String] {
        (UserDefaults.standard.array(forKey: localKey) as? [String]) ?? []
    }

    private func clearLocalProgress() {
        UserDefaults.standard.removeObject(forKey: localKey)
    }
}

// MARK: - Game View

private struct WordleGameView: View {

    @ObservedObject var vm: WordleGameViewModel
    let isLocked: Bool

    let onSubmittedGuess: (_ guessesSoFar: [String]) -> Void
    let onFinished: (_ attemptsUsed: Int, _ solved: Bool, _ guesses: [String]) -> Void

    var body: some View {
        VStack(spacing: 12) {
            grid
            errorText
            keyboard
            footer
        }
        .onChange(of: vm.isSolved) { _, solved in
            if solved {
                onFinished(vm.attemptsUsed, true, collectedGuesses())
            }
        }
        .onChange(of: vm.attemptsUsed) { _, used in
            if !vm.isSolved && used >= vm.maxAttempts {
                onFinished(vm.attemptsUsed, false, collectedGuesses())
            }
        }
    }

    private func collectedGuesses() -> [String] {
        vm.rows
            .prefix(vm.attemptsUsed)
            .map { $0.guess.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var grid: some View {
        VStack(spacing: 8) {
            ForEach(Array(vm.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    let wl = vm.wordLength
                    let guessChars = Array(row.guess.padding(toLength: wl, withPad: " ", startingAt: 0))
                    ForEach(0..<wl, id: \.self) { i in
                        tile(
                            letter: String(guessChars[i]),
                            state: row.states[safe: i] ?? .empty
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tile(letter: String, state: WordleTileState) -> some View {
        let bg: Color = {
            switch state {
            case .empty: return Color.secondary.opacity(0.12)
            case .correct: return Color.green.opacity(0.35)
            case .present: return Color.yellow.opacity(0.35)
            case .absent: return Color.gray.opacity(0.25)
            }
        }()

        return Text(letter.trimmingCharacters(in: .whitespaces))
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
            .frame(width: 48, height: 48)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
    }

    private var errorText: some View {
        Group {
            if let msg = vm.errorMessage, !msg.isEmpty {
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var keyboard: some View {
        let rows: [[String]] = [
            Array("QWERTYUIOP").map(String.init),
            Array("ASDFGHJKL").map(String.init),
            ["ENTER"] + Array("ZXCVBNM").map(String.init) + ["⌫"]
        ]

        return VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            handleKey(key)
                        } label: {
                            Text(key)
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: keyWidth(key), minHeight: 44)
                                .padding(.horizontal, 6)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(isLocked || vm.isSolved || vm.attemptsUsed >= vm.maxAttempts)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func keyWidth(_ key: String) -> CGFloat? {
        if key == "ENTER" { return 70 }
        if key == "⌫" { return 54 }
        return nil
    }

    private func handleKey(_ key: String) {
        switch key {
        case "ENTER":
            let before = collectedGuesses()
            vm.submit()
            let after = collectedGuesses()

            // Only persist if a guess was actually accepted
            if after.count > before.count {
                onSubmittedGuess(after)
            }

        case "⌫":
            vm.backspace()

        default:
            vm.typeLetter(key)
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            if vm.isSolved {
                Text("✅ Solved in \(vm.attemptsUsed)!")
                    .font(.headline)
            } else if vm.attemptsUsed >= vm.maxAttempts {
                Text("❌ Out of tries.")
                    .font(.headline)
            }

            if isLocked {
                Text("🔒 Locked — submissions are closed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe idx: Int) -> Element? {
        guard idx >= 0, idx < count else { return nil }
        return self[idx]
    }
}
