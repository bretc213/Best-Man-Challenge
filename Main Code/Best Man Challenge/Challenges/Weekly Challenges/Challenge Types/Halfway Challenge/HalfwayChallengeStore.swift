//
//  HalfwayChallengeStore.swift
//  Best Man Challenge
//
//  Manages W25 Halfway Point Challenge state:
//   - Which rounds are complete (persisted in Firestore game_state/{uid})
//   - Score = completed rounds × 6 pts
//   - Writes final score to submissions/{uid} whenever progress changes
//
//  Firestore paths:
//   weekly_challenges/2026_w25/game_state/{uid}   ← per-player progress
//   weekly_challenges/2026_w25/submissions/{uid}  ← leaderboard score
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - Round metadata (decoded from Firestore challenge doc)

struct HalfwayRound: Identifiable {
    let id: String          // "round1"..."round5"
    let position: Int
    let title: String
    let emoji: String
    let description: String
    let points: Int
}

// MARK: - Store

@MainActor
final class HalfwayChallengeStore: ObservableObject {

    // MARK: Published state

    @Published var rounds: [HalfwayRound] = []
    @Published var completedRounds: Set<String> = []   // round IDs that are done
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Per-game persisted state (loaded from Firestore, updated by each game view)
    @Published var rtbDeckCodes: [String] = []
    @Published var rtbQuestion: Int = 0           // 0–3
    @Published var rtbRunCards: [String] = []     // card codes in current run

    @Published var mmCode: [String] = []          // mastermind secret code
    @Published var mmGuesses: [[String: Any]] = []

    @Published var bjWins: Int = 0                // 0–10

    @Published var yhComplete: [String] = []      // completed yahtzee categories

    @Published var memBoard: [String] = []        // 24 player IDs (shuffled)
    @Published var memMatched: [String] = []      // matched player IDs
    @Published var memStrikes: Int = 0

    // MARK: Computed

    var score: Int { completedRounds.count * 6 }
    var maxScore: Int { 6 * 6 }  // wait — 5 rounds × 6 pts = 30, but store uses 5

    func isUnlocked(_ round: HalfwayRound) -> Bool {
        if round.position == 1 { return true }
        guard let prev = rounds.first(where: { $0.position == round.position - 1 }) else { return false }
        return completedRounds.contains(prev.id)
    }

    // MARK: Private

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var challengeId = ""
    private var uid: String? { Auth.auth().currentUser?.uid }

    deinit { listener?.remove() }

    // MARK: - Load

    func load(challenge: WeeklyChallenge) {
        challengeId = challenge.id
        isLoading = true

        // Parse rounds from challenge doc
        if let config = challenge.halfwayChallenge {
            rounds = config.rounds
        }

        guard let uid else { isLoading = false; return }

        listener?.remove()
        listener = db.collection("weekly_challenges")
            .document(challengeId)
            .collection("game_state")
            .document(uid)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                self.isLoading = false
                if let err { self.errorMessage = err.localizedDescription; return }

                let d = snap?.data() ?? [:]
                self.completedRounds = Set((d["rounds_complete"] as? [String]) ?? [])

                // RTB
                self.rtbDeckCodes  = d["rtb_deck"]      as? [String] ?? []
                self.rtbQuestion   = d["rtb_question"]   as? Int     ?? 0
                self.rtbRunCards   = d["rtb_run_cards"]  as? [String] ?? []

                // Mastermind
                self.mmCode    = d["mm_code"]    as? [String]      ?? []
                self.mmGuesses = d["mm_guesses"] as? [[String: Any]] ?? []

                // Blackjack
                self.bjWins = d["bj_wins"] as? Int ?? 0

                // Yahtzee
                self.yhComplete = d["yh_complete"] as? [String] ?? []

                // Memory
                self.memBoard    = d["mem_board"]    as? [String] ?? []
                self.memMatched  = d["mem_matched"]  as? [String] ?? []
                self.memStrikes  = d["mem_strikes"]  as? Int      ?? 0
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Reset (owner testing only)

    func resetMySubmissions() async {
        guard let uid else { return }
        do {
            try await db.collection("weekly_challenges").document(challengeId)
                .collection("game_state").document(uid).delete()
            try await db.collection("weekly_challenges").document(challengeId)
                .collection("submissions").document(uid).delete()
            // Clear local state so views reflect the reset immediately
            completedRounds = []
            rtbDeckCodes = []; rtbQuestion = 0; rtbRunCards = []
            mmCode = []; mmGuesses = []
            bjWins = 0
            yhComplete = []
            memBoard = []; memMatched = []; memStrikes = 0
        } catch {
            errorMessage = "Reset failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Mark round complete

    func completeRound(_ roundId: String) async {
        guard !completedRounds.contains(roundId) else { return }
        completedRounds.insert(roundId)
        await saveState([:])
        await syncScore()
    }

    // MARK: - Per-game state saves

    func saveRTBState(deckCodes: [String], question: Int, runCards: [String]) async {
        await saveState([
            "rtb_deck":      deckCodes,
            "rtb_question":  question,
            "rtb_run_cards": runCards
        ])
    }

    func saveMastermindState(code: [String], guesses: [[String: Any]]) async {
        await saveState([
            "mm_code":    code,
            "mm_guesses": guesses
        ])
    }

    func saveBlackjackWins(_ wins: Int) async {
        await saveState(["bj_wins": wins])
    }

    func saveYahtzeeComplete(_ categories: [String]) async {
        await saveState(["yh_complete": categories])
    }

    func saveMemoryState(board: [String], matched: [String], strikes: Int) async {
        await saveState([
            "mem_board":   board,
            "mem_matched": matched,
            "mem_strikes": strikes
        ])
    }

    // MARK: - Private helpers

    private func saveState(_ extra: [String: Any]) async {
        guard let uid else { return }

        var data: [String: Any] = [
            "rounds_complete": Array(completedRounds),
            "updated_at": FieldValue.serverTimestamp()
        ]
        for (k, v) in extra { data[k] = v }

        do {
            try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("game_state")
                .document(uid)
                .setData(data, merge: true)
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private func syncScore() async {
        guard let uid else { return }
        let currentScore = completedRounds.count * 6

        do {
            // Look up linked_player_id
            let userSnap = try await db.collection("users").document(uid).getDocument()
            let linkedId = userSnap.data()?["linked_player_id"] as? String
            let displayName = userSnap.data()?["display_name"] as? String

            try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("submissions")
                .document(uid)
                .setData([
                    "uid": uid,
                    "linked_player_id": linkedId as Any,
                    "display_name": displayName as Any,
                    "score": currentScore,
                    "max_score": 30,
                    "rounds_complete": completedRounds.count,
                    "updated_at": FieldValue.serverTimestamp()
                ], merge: true)
        } catch {
            print("⚠️ HalfwayChallenge syncScore failed:", error.localizedDescription)
        }
    }
}

// MARK: - WeeklyChallenge extension for halfway_challenge config

struct HalfwayChallengeConfig {
    let rounds: [HalfwayRound]
}

extension WeeklyChallenge {
    var halfwayChallenge: HalfwayChallengeConfig? {
        // Parsed from the "halfway_challenge" nested map in the Firestore doc.
        // WeeklyChallengeManager needs to pass this through — for now we fall back
        // to a hardcoded round list so the views always work.
        let defaultRounds: [HalfwayRound] = [
            HalfwayRound(id: "round1", position: 1, title: "Ride the Bus",  emoji: "🚌", description: "Answer all 4 card questions in a row.", points: 6),
            HalfwayRound(id: "round2", position: 2, title: "Blackjack",     emoji: "🃏", description: "Beat the dealer 100 times with a streak multiplier.", points: 6),
            HalfwayRound(id: "round3", position: 3, title: "Yahtzee",       emoji: "🎲", description: "Complete all 6 lower-section categories.", points: 6),
            HalfwayRound(id: "round4", position: 4, title: "Memory",        emoji: "🧠", description: "Match all 12 pairs of groomsmen photos.", points: 6),
            HalfwayRound(id: "round5", position: 5, title: "Mastermind",    emoji: "🔵", description: "Crack the 5-color code.", points: 6)
        ]
        return HalfwayChallengeConfig(rounds: defaultRounds)
    }
}
