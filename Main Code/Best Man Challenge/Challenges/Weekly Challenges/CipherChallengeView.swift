//
//  CipherChallengeView.swift
//  Best Man Challenge
//
//  Interactive multi-layer puzzle challenge (a real in-app game, like Blackjack /
//  Ride the Bus — NOT a quiz). Three graded stages, 10 points total:
//    Step 1 · Solve the 4×4 mini-sudoku            → 3 pts  (validated via MiniSudokuValidator)
//    Step 2 · Decode & type the hidden phrase       → 3 pts  (Caesar-decoded from the ciphertext)
//    Step 3 · Answer the riddle it reveals          → 4 pts  (accepts `answer` + accepted_answers)
//
//  Partial credit: each stage scores independently. The total is written to the
//  submission `score`, which the weekly standings read directly.
//
//  Data-driven from WeeklyChallenge.puzzle + .cipher + .answer + .accepted_answers.
//  Launched by a "Play the Cipher" button in WeeklyChallengeView (players) and
//  WeeklyChallengeAdminPreviewView (owner preview) for .riddle challenges that
//  carry both puzzle & cipher. Submits via WeeklyChallengeManager.submitCipherResult.
//

import SwiftUI
import Combine

struct CipherChallengeView: View {
    let challenge: WeeklyChallenge

    @EnvironmentObject var challengeManager: WeeklyChallengeManager

    // Points per stage (3 + 3 + 4 = 10)
    private let sudokuPoints = 3
    private let phrasePoints = 3
    private let answerPoints = 4
    private var maxPoints: Int { sudokuPoints + phrasePoints + answerPoints }

    // Working sudoku grid (flat, 16 cells; 0 = empty)
    @State private var grid: [Int] = Array(repeating: 0, count: 16)
    @State private var unlocked: Bool = false
    @State private var puzzleMessage: String?

    @State private var phraseText: String = ""
    @State private var phraseLocked: Bool = false
    @State private var phraseMessage: String?
    @State private var answerText: String = ""

    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    // Inline feedback for wrong riddle guesses (retry until correct)
    @State private var answerMessage: String?

    // True while a stuck player has re-entered the challenge to retry the answer.
    @State private var reentering: Bool = false

    // Local result snapshot for immediate feedback after submitting
    @State private var justSubmitted: Bool = false
    @State private var resultScore: Int = 0
    @State private var resultBreakdown: [String: Bool] = [:]

    // Restores saved progress from Firestore exactly once, when it arrives.
    @State private var didRestore: Bool = false

    private var givens: [Bool] {
        let seed = challenge.puzzle?.grid ?? Array(repeating: 0, count: 16)
        return seed.map { $0 != 0 }
    }

    private var shiftKey: Int { challenge.cipher?.shift ?? challenge.puzzle?.unlock_value ?? 0 }
    private var ciphertext: String { challenge.cipher?.ciphertext ?? "" }
    private var isLocked: Bool { challenge.isLocked || challenge.isExpired }

    private var existingSubmission: WeeklyChallengeSubmission? { challengeManager.lastSubmission }

    private var hasSubmitted: Bool {
        justSubmitted
        || existingSubmission?.cipherFinalSubmitted == true
        || existingSubmission?.score != nil
    }

    /// Whether the player has actually finished — got the riddle answer right.
    /// Legacy submissions from the old one-and-done flow can be "submitted" but
    /// incomplete (answer wrong); those players need a way back in.
    private var completedCorrectly: Bool {
        if justSubmitted { return resultBreakdown["answer"] == true || resultScore >= maxPoints }
        if existingSubmission?.breakdown?["answer"] == true { return true }
        return (existingSubmission?.score ?? 0) >= maxPoints
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text(challenge.title).font(.title2.bold())
                if !challenge.description.isEmpty {
                    Text(challenge.description).foregroundStyle(.secondary)
                }
                pointsLegend
                Divider().opacity(0.3)

                if hasSubmitted && !reentering {
                    submissionCard
                } else if isLocked {
                    Text("This challenge is locked.").foregroundStyle(.secondary)
                } else {
                    sudokuCard
                    if unlocked {
                        decodeCard
                        if phraseLocked {
                            answerCard
                            submitCard
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding()
        }
        .navigationTitle("The Cipher")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            restoreProgressIfPossible()
            if grid.allSatisfy({ $0 == 0 }) {
                grid = challenge.puzzle?.grid ?? Array(repeating: 0, count: 16)
            }
        }
        // The submission doc may arrive after the view appears — restore then too.
        .onReceive(challengeManager.$lastSubmission) { _ in
            restoreProgressIfPossible()
        }
    }

    /// Rehydrates saved sudoku/phrase progress from Firestore so a player can leave
    /// mid-puzzle and pick up where they left off. Runs at most once, after the
    /// submission has actually loaded. If the challenge was already finalized, it
    /// leaves everything to the result card (via `hasSubmitted`).
    private func restoreProgressIfPossible() {
        guard !didRestore else { return }
        guard let sub = existingSubmission else { return }   // wait until it loads
        didRestore = true

        if sub.cipherFinalSubmitted == true || sub.score != nil { return }

        if let g = sub.cipherGrid, g.count == 16 { grid = g }
        if sub.cipherSudokuUnlocked == true {
            unlocked = true
            puzzleMessage = "Solved! +\(sudokuPoints) pts. Key unlocked below."
        }
        if sub.cipherPhraseLocked == true {
            phraseLocked = true
            if let p = sub.cipherPhrase, !p.isEmpty { phraseText = p }
        } else if let p = sub.cipherPhrase, !p.isEmpty {
            phraseText = p
        }
    }

    private var pointsLegend: some View {
        Text("Sudoku \(sudokuPoints) pts · Phrase \(phrasePoints) pts · Answer \(answerPoints) pts · \(maxPoints) total")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Step 1: Sudoku

    private var sudokuCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Step 1 · Solve the Mini-Sudoku (\(sudokuPoints) pts)", systemImage: "square.grid.2x2")
                .font(.headline)

            Text("Every row, column, and 2×2 box must contain 1, 2, 3, and 4. Tap a cell to cycle its number.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            sudokuGrid
                .disabled(unlocked)
                .opacity(unlocked ? 0.6 : 1.0)

            if let puzzleMessage {
                Text(puzzleMessage)
                    .font(.footnote)
                    .foregroundStyle(unlocked ? .green : .red)
            }

            if !unlocked {
                Button {
                    checkPuzzle()
                } label: {
                    Text("Unlock the Key").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .cardStyle()
    }

    private var sudokuGrid: some View {
        VStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { r in
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { c in
                        cellView(index: r * 4 + c)
                    }
                }
            }
        }
    }

    private func cellView(index: Int) -> some View {
        let value = grid[index]
        let isGiven = givens[index]
        return Text(value == 0 ? "" : "\(value)")
            .font(.title2.weight(isGiven ? .bold : .regular))
            .frame(width: 54, height: 54)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isGiven ? Color.secondary.opacity(0.18) : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
            )
            .foregroundStyle(isGiven ? Color.primary : Color.accentColor)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isGiven, !unlocked else { return }
                grid[index] = (grid[index] + 1) % 5   // 0→1→2→3→4→0
                puzzleMessage = nil
            }
    }

    private func checkPuzzle() {
        if MiniSudokuValidator.isValidCompleted4x4(grid) {
            unlocked = true
            puzzleMessage = "Solved! +\(sudokuPoints) pts. Key unlocked below."
            // Persist so the player can leave and return already unlocked.
            Task {
                await challengeManager.saveCipherProgress(
                    grid: grid,
                    sudokuUnlocked: true,
                    phraseLocked: phraseLocked,
                    phrase: phraseText
                )
            }
        } else if grid.contains(0) {
            puzzleMessage = "Fill every cell first."
        } else {
            puzzleMessage = "Not quite — each row, column, and 2×2 box needs 1, 2, 3, and 4."
        }
    }

    private func checkPhrase() {
        guard !expectedPhrase.isEmpty,
              normalize(phraseText) == normalize(expectedPhrase) else {
            phraseMessage = "Not quite — decode the message with the key and try again."
            return
        }
        phraseLocked = true
        phraseMessage = nil
        // Persist the decoded phrase so Step 3 stays unlocked on return.
        Task {
            await challengeManager.saveCipherProgress(
                grid: grid,
                sudokuUnlocked: unlocked,
                phraseLocked: true,
                phrase: phraseText
            )
        }
    }

    // MARK: - Step 2: Decode & type the phrase

    private var decodeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Step 2 · Decode the Message (\(phrasePoints) pts)", systemImage: "key.fill")
                .font(.headline)

            Text(challenge.puzzle?.unlock_text?.isEmpty == false
                 ? (challenge.puzzle?.unlock_text ?? "")
                 : "Key = \(shiftKey)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            Text(ciphertext)
                .font(.system(.body, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))

            Text("Shift each letter back \(shiftKey), then type the decoded phrase:")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("Type the decoded phrase…", text: $phraseText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .disabled(phraseLocked)

            if let phraseMessage {
                Text(phraseMessage)
                    .font(.footnote)
                    .foregroundStyle(phraseLocked ? .green : .red)
            }

            if phraseLocked {
                Label("Correct! +\(phrasePoints) pts. Step 3 unlocked below.", systemImage: "lock.open.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
            } else {
                Button {
                    checkPhrase()
                } label: {
                    Text("Submit Phrase").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(phraseText.trimmingCharacters(in: .whitespaces).isEmpty)

                Text("You must decode and submit the correct phrase before you can answer the riddle.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    // MARK: - Step 3: Answer

    private var answerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Step 3 · Answer the Riddle (\(answerPoints) pts)", systemImage: "text.bubble")
                .font(.headline)

            TextField("Type your answer…", text: $answerText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .onChange(of: answerText) { _ in answerMessage = nil }

            if let answerMessage {
                Text(answerMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .cardStyle()
    }

    private var submitCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }
            Button {
                Task { await submitTapped() }
            } label: {
                Text(isSubmitting ? "Submitting…" : "Submit Answer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting || answerText.trimmingCharacters(in: .whitespaces).isEmpty)

            Text("Keep guessing until you crack it — the challenge finishes when your answer is correct.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    // MARK: - Submission summary

    private var submissionCard: some View {
        let breakdown = justSubmitted ? resultBreakdown : (existingSubmission?.breakdown ?? [:])
        let score = justSubmitted ? resultScore : (existingSubmission?.score ?? 0)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Your Result").font(.headline)

            stageRow("Sudoku", ok: breakdown["sudoku"] ?? false, pts: sudokuPoints)
            stageRow("Phrase", ok: breakdown["phrase"] ?? false, pts: phrasePoints)
            stageRow("Answer", ok: breakdown["answer"] ?? false, pts: answerPoints)

            Divider().opacity(0.3)
            HStack {
                Text("Total").fontWeight(.semibold)
                Spacer()
                Text("\(score) / \(maxPoints)").fontWeight(.bold)
            }

            if completedCorrectly {
                Text("Challenge complete — nice work! 🎉")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if challenge.isExpired {
                Text("This weekly challenge has ended.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("You haven't cracked the riddle yet. Jump back in and finish it!")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    reenterChallenge()
                } label: {
                    Label("Re-enter Challenge", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
        }
        .cardStyle()
    }

    private func stageRow(_ label: String, ok: Bool, pts: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .red)
            Text(label)
            Spacer()
            Text("\(ok ? pts : 0) / \(pts)")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    // MARK: - Grading + submit

    private func submitTapped() async {
        // Block resubmits only once the challenge is actually completed correctly.
        guard !completedCorrectly else { return }
        errorMessage = nil

        // Retry until correct — a wrong riddle answer just prompts another guess.
        // The challenge only finishes (and shows the Result card) once it's right.
        guard isAnswerCorrect(answerText) else {
            answerMessage = "Not quite — that's not the answer. Try again!"
            return
        }

        answerMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        // Reaching here means all three stages are complete → full marks.
        let breakdown: [String: Bool] = [
            "sudoku": true,
            "phrase": true,
            "answer": true
        ]
        let score = maxPoints

        do {
            try await challengeManager.submitCipherResult(
                phrase: phraseText,
                answer: answerText,
                score: score,
                maxScore: maxPoints,
                breakdown: breakdown
            )
            resultScore = score
            resultBreakdown = breakdown
            justSubmitted = true
            reentering = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Lets a player who submitted a wrong answer (or a legacy one-and-done
    /// submission) go back into the challenge and retry the riddle. Restores the
    /// already-cleared stages so they land straight on Step 3.
    private func reenterChallenge() {
        if let g = existingSubmission?.cipherGrid, g.count == 16 { grid = g }
        unlocked = true
        phraseLocked = true
        // Show the decoded phrase in the locked field (they'd already solved it).
        if let p = existingSubmission?.cipherPhrase, !p.isEmpty {
            phraseText = p
        } else if phraseText.trimmingCharacters(in: .whitespaces).isEmpty {
            phraseText = expectedPhrase
        }
        answerText = ""
        answerMessage = nil
        errorMessage = nil
        justSubmitted = false
        reentering = true
    }

    /// The plaintext the ciphertext decodes to, computed from shift + direction.
    private var expectedPhrase: String {
        let dir = (challenge.cipher?.direction ?? "back").lowercased()
        let delta = dir == "forward" ? shiftKey : -shiftKey
        return caesarShift(ciphertext, by: delta)
    }

    private func isAnswerCorrect(_ typed: String) -> Bool {
        var accepted = challenge.accepted_answers ?? []
        if let a = challenge.answer { accepted.append(a) }
        let target = normalize(typed)
        guard !target.isEmpty else { return false }
        return accepted.contains { normalize($0) == target }
    }

    private func caesarShift(_ text: String, by k: Int) -> String {
        func shifted(base: Int, ascii: UInt8) -> Character {
            let idx = ((Int(ascii) - base + k) % 26 + 26) % 26
            return Character(UnicodeScalar(UInt8(base + idx)))
        }
        var out = ""
        for ch in text {
            if ch.isUppercase, let a = ch.asciiValue {
                out.append(shifted(base: 65, ascii: a))
            } else if ch.isLowercase, let a = ch.asciiValue {
                out.append(shifted(base: 97, ascii: a))
            } else {
                out.append(ch)
            }
        }
        return out
    }

    /// Tolerant match: lowercase, drop leading article, keep letters/digits only.
    private func normalize(_ s: String) -> String {
        var t = s.lowercased().trimmingCharacters(in: .whitespaces)
        for article in ["a ", "an ", "the "] where t.hasPrefix(article) {
            t = String(t.dropFirst(article.count))
        }
        return String(t.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }
}
