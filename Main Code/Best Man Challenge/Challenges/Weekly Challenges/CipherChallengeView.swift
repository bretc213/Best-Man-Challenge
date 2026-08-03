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

    // Local result snapshot for immediate feedback after submitting
    @State private var justSubmitted: Bool = false
    @State private var resultScore: Int = 0
    @State private var resultBreakdown: [String: Bool] = [:]

    private var givens: [Bool] {
        let seed = challenge.puzzle?.grid ?? Array(repeating: 0, count: 16)
        return seed.map { $0 != 0 }
    }

    private var shiftKey: Int { challenge.cipher?.shift ?? challenge.puzzle?.unlock_value ?? 0 }
    private var ciphertext: String { challenge.cipher?.ciphertext ?? "" }
    private var isLocked: Bool { challenge.isLocked || challenge.isExpired }

    private var existingSubmission: WeeklyChallengeSubmission? { challengeManager.lastSubmission }

    private var hasSubmitted: Bool {
        justSubmitted || existingSubmission?.score != nil ||
        (existingSubmission?.answerText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
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

                if hasSubmitted {
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
            if grid.allSatisfy({ $0 == 0 }) {
                grid = challenge.puzzle?.grid ?? Array(repeating: 0, count: 16)
            }
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
                Text(isSubmitting ? "Submitting…" : "Submit")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting || answerText.trimmingCharacters(in: .whitespaces).isEmpty)

            Text("You can only submit once — you keep points for whatever you got right.")
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

            Text(challenge.isExpired ? "This weekly challenge has ended." : "You can only submit once.")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let phraseOK = normalize(phraseText) == normalize(expectedPhrase) && !expectedPhrase.isEmpty
        let answerOK = isAnswerCorrect(answerText)

        // Sudoku is always correct here (unlocking required solving it).
        let breakdown: [String: Bool] = [
            "sudoku": true,
            "phrase": phraseOK,
            "answer": answerOK
        ]
        let score = sudokuPoints
            + (phraseOK ? phrasePoints : 0)
            + (answerOK ? answerPoints : 0)

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
        } catch {
            errorMessage = error.localizedDescription
        }
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
