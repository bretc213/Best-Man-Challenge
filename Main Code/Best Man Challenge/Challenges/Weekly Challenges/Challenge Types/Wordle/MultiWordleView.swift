//
//  MultiWordleView.swift
//  Best Man Challenge
//
//  Hosts N simultaneous Wordle boards (e.g. W31 Triple Wordle: BRIDE, RINGS, AISLE).
//  Each word is independent. Score = sum of individual word scores.
//  Scoring per word: solved ? max(1, (maxAttempts + 6) - attemptsUsed) : 0

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Per-word game state wrapper

private struct WordleGame: Identifiable {
    let id: String               // MultiWordleWord.id
    let label: String?
    var vm: WordleGameViewModel
    var submitted: Bool = false
    var localKey: String
}

// MARK: - MultiWordleView

struct MultiWordleView: View {
    let challenge: WeeklyChallenge
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var challengeManager: WeeklyChallengeManager

    @State private var games: [WordleGame] = []
    @State private var activeIndex: Int = 0
    @State private var allFinished = false
    @State private var totalScore = 0
    @State private var submitError: String?
    @State private var isSaving = false

    private var config: WeeklyChallengeMultiWordle? { challenge.multi_wordle }

    private var isLocked: Bool {
        if let end = challenge.endDate { return Date() >= end }
        return challenge.isLocked
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard

                if games.isEmpty {
                    Text("Multi-Wordle not configured.")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    wordPicker
                    activeGameView
                    scoreCard
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationTitle("Triple Wordle")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { setupGames() }
        .alert("Error", isPresented: .init(
            get: { submitError != nil },
            set: { if !$0 { submitError = nil } }
        )) {
            Button("OK") { submitError = nil }
        } message: { Text(submitError ?? "") }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(challenge.title).font(.title2.bold())
            Text(challenge.description).font(.subheadline).foregroundStyle(.secondary)
            if isLocked {
                Label("Submissions closed", systemImage: "lock.fill")
                    .font(.caption).foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Word picker tabs

    private var wordPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(games.enumerated()), id: \.element.id) { idx, game in
                    Button {
                        withAnimation { activeIndex = idx }
                    } label: {
                        VStack(spacing: 4) {
                            Text("Word \(idx + 1)")
                                .font(.subheadline.bold())
                            if game.vm.isSolved {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            } else if game.vm.attemptsUsed >= game.vm.maxAttempts {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                            } else {
                                Text("\(game.vm.maxAttempts - game.vm.attemptsUsed) left")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(activeIndex == idx ? Color.accent : Color.secondary.opacity(0.12))
                        .foregroundStyle(activeIndex == idx ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal)
    }

    // MARK: - Active game

    @ViewBuilder
    private var activeGameView: some View {
        if activeIndex < games.count {
            let game = games[activeIndex]
            WordleGameEmbedded(
                vm: game.vm,
                isLocked: isLocked,
                onGuessSubmitted: { guesses in
                    saveLocalProgress(guesses, for: activeIndex)
                },
                onFinished: { attempts, solved, guesses in
                    handleWordFinished(index: activeIndex, attempts: attempts, solved: solved, guesses: guesses)
                }
            )
            .id(game.id)  // force re-render when tab changes
            .padding(.horizontal)
        }
    }

    // MARK: - Score card

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Score", systemImage: "star.fill")
                .font(.headline).foregroundStyle(.accent)
            ForEach(Array(games.enumerated()), id: \.element.id) { idx, game in
                let pts = wordScore(for: game)
                HStack {
                    Text("Word \(idx + 1)")
                    Spacer()
                    if game.submitted {
                        Text("\(pts) pts")
                            .font(.subheadline.bold())
                            .foregroundStyle(pts > 0 ? .green : .red)
                    } else {
                        Text("—").foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
            }
            Divider()
            HStack {
                Text("Total").font(.headline)
                Spacer()
                Text("\(totalScore) pts").font(.headline).foregroundStyle(.accent)
            }
            if isSaving {
                ProgressView("Saving score…").font(.caption)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Setup

    private func setupGames() {
        guard let config, games.isEmpty else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }

        games = config.words.map { word in
            let key = "multiwordle_\(challenge.id)_\(uid)_\(word.id)"
            let saved = (UserDefaults.standard.array(forKey: key) as? [String]) ?? []
            let vm = WordleGameViewModel(
                answer: word.answer,
                wordLength: word.word_length,
                maxAttempts: word.max_attempts,
                submittedGuesses: saved
            )
            let finished = vm.isSolved || vm.attemptsUsed >= vm.maxAttempts
            return WordleGame(id: word.id, label: word.label, vm: vm, submitted: finished, localKey: key)
        }

        recalcScore()
        checkAllFinished()
    }

    // MARK: - Guess / finish handlers

    private func saveLocalProgress(_ guesses: [String], for index: Int) {
        guard index < games.count else { return }
        UserDefaults.standard.set(guesses, forKey: games[index].localKey)
    }

    private func handleWordFinished(index: Int, attempts: Int, solved: Bool, guesses: [String]) {
        guard index < games.count else { return }
        games[index].submitted = true
        recalcScore()
        checkAllFinished()

        // Auto-advance to next unsolved word
        if let next = games.indices.first(where: { i in
            !games[i].submitted && i != index
        }) {
            withAnimation { activeIndex = next }
        }

        if allFinished {
            Task { await persistFinalScore() }
        }
    }

    private func recalcScore() {
        totalScore = games.filter { $0.submitted }.reduce(0) { $0 + wordScore(for: $1) }
    }

    private func checkAllFinished() {
        allFinished = games.allSatisfy {
            $0.vm.isSolved || $0.vm.attemptsUsed >= $0.vm.maxAttempts
        }
    }

    private func wordScore(for game: WordleGame) -> Int {
        guard game.vm.isSolved else { return 0 }
        return max(1, (game.vm.maxAttempts + 6) - game.vm.attemptsUsed)
    }

    // MARK: - Persist final score

    private func persistFinalScore() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isSaving = true
        defer { isSaving = false }

        // ✅ Use the already-parsed session profile (snake_case fields are read
        // correctly in SessionStore). The previous version read camelCase keys
        // ("displayName"/"linkedPlayerId") that don't exist on the user doc, so
        // display_name was saved as nil and standings fell back to the raw UID.
        let linkedId = session.linkedPlayerId ?? uid
        let displayName = session.displayName

        do {
            try await Firestore.firestore()
                .collection("weekly_challenges")
                .document(challenge.id)
                .collection("submissions")
                .document(linkedId)
                .setData([
                    "uid": uid,
                    "linked_player_id": linkedId,
                    "display_name": displayName,
                    "score": totalScore,
                    "updated_at": FieldValue.serverTimestamp()
                ], merge: true)
        } catch {
            submitError = "Couldn't save score: \(error.localizedDescription)"
        }
    }
}

// MARK: - Embedded Wordle (no external dependencies, uses existing VM)

private struct WordleGameEmbedded: View {
    @ObservedObject var vm: WordleGameViewModel
    let isLocked: Bool
    let onGuessSubmitted: ([String]) -> Void
    let onFinished: (Int, Bool, [String]) -> Void

    private var finished: Bool { vm.isSolved || vm.attemptsUsed >= vm.maxAttempts }

    var body: some View {
        VStack(spacing: 12) {
            grid
            if let err = vm.errorMessage { Text(err).font(.footnote).foregroundStyle(.red) }
            keyboard
            footer
        }
        .onChange(of: vm.isSolved) { _, solved in
            if solved { onFinished(vm.attemptsUsed, true, guesses()) }
        }
        .onChange(of: vm.attemptsUsed) { _, used in
            if !vm.isSolved && used >= vm.maxAttempts { onFinished(used, false, guesses()) }
        }
    }

    private func guesses() -> [String] {
        vm.rows.prefix(vm.attemptsUsed)
            .map { $0.guess.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var grid: some View {
        VStack(spacing: 6) {
            ForEach(Array(vm.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    let chars = Array(row.guess.padding(toLength: vm.wordLength, withPad: " ", startingAt: 0))
                    ForEach(0..<vm.wordLength, id: \.self) { i in
                        tile(letter: String(chars[i]), state: row.states[safe2: i] ?? .empty)
                    }
                }
            }
        }
    }

    private func tile(letter: String, state: WordleTileState) -> some View {
        let bg: Color = {
            switch state {
            case .empty:   return Color.secondary.opacity(0.12)
            case .correct: return Color.green.opacity(0.35)
            case .present: return Color.yellow.opacity(0.35)
            case .absent:  return Color.gray.opacity(0.25)
            }
        }()
        return Text(letter.trimmingCharacters(in: .whitespaces))
            .font(.title3.bold())
            .frame(width: 44, height: 44)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    private var keyboard: some View {
        let rows: [[String]] = [
            Array("QWERTYUIOP").map(String.init),
            Array("ASDFGHJKL").map(String.init),
            ["ENTER"] + Array("ZXCVBNM").map(String.init) + ["⌫"]
        ]
        return VStack(spacing: 6) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 5) {
                    ForEach(row, id: \.self) { key in
                        Button { handleKey(key) } label: {
                            Text(key).font(.footnote.bold())
                                .frame(maxWidth: keyW(key), minHeight: 40)
                                .padding(.horizontal, 5)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(isLocked || finished)
                    }
                }
            }
        }
    }

    private func keyW(_ k: String) -> CGFloat? { k == "ENTER" ? 60 : k == "⌫" ? 48 : nil }

    private func handleKey(_ key: String) {
        let before = guesses().count
        switch key {
        case "ENTER":
            vm.submit()
            let after = guesses()
            if after.count > before { onGuessSubmitted(after) }
        case "⌫": vm.backspace()
        default:   vm.typeLetter(key)
        }
    }

    private var footer: some View {
        Group {
            if vm.isSolved {
                Text("✅ Solved in \(vm.attemptsUsed)!").font(.headline)
            } else if vm.attemptsUsed >= vm.maxAttempts {
                Text("❌ Out of tries.").font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension Array {
    subscript(safe2 idx: Int) -> Element? {
        guard idx >= 0, idx < count else { return nil }
        return self[idx]
    }
}
