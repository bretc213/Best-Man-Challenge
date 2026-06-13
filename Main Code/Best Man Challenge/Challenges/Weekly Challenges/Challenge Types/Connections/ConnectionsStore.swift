//
//  ConnectionsStore.swift
//  Best Man Challenge
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Runtime models

enum ConnectionsAttemptResult {
    case correct(category: ConnectionsCategory)
    case oneAway
    case wrong
    case alreadySolved
}

struct ConnectionsGameState {
    var solvedCategoryIds: Set<String> = []
    var mistakesUsed: Int = 0
    var selectedWords: Set<String> = []

    func isSolved(with config: WeeklyChallengeConnectionsConfig) -> Bool {
        solvedCategoryIds.count == config.categories.count
    }

    func totalScore(with config: WeeklyChallengeConnectionsConfig) -> Int {
        config.categories
            .filter { solvedCategoryIds.contains($0.id) }
            .reduce(0) { $0 + $1.point_value }
    }
}

// MARK: - Store

@MainActor
final class ConnectionsStore: ObservableObject {

    @Published var gameState = ConnectionsGameState()
    @Published var shuffledWords: [String] = []
    @Published var isSubmitting = false
    @Published var isFinished = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var currentChallengeId: String?
    private var config: WeeklyChallengeConnectionsConfig?

    deinit { listener?.remove() }

    // MARK: - Lifecycle

    func start(challengeId: String, config: WeeklyChallengeConnectionsConfig) {
        self.currentChallengeId = challengeId
        self.config = config

        // Shuffle words on first launch
        if shuffledWords.isEmpty {
            shuffledWords = config.allWords.shuffled()
        }

        guard let uid = Auth.auth().currentUser?.uid else { return }
        listener?.remove()

        listener = db.collection("weekly_challenges")
            .document(challengeId)
            .collection("submissions")
            .document(uid)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let data = snap?.data() else { return }
                self.restoreState(from: data)
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
        currentChallengeId = nil
        config = nil
    }

    // MARK: - Word selection

    func toggleWord(_ word: String) {
        guard !isFinished else { return }
        if gameState.selectedWords.contains(word) {
            gameState.selectedWords.remove(word)
        } else if gameState.selectedWords.count < 4 {
            gameState.selectedWords.insert(word)
        }
    }

    // MARK: - Submit a guess of exactly 4 words

    func submitGuess() async -> ConnectionsAttemptResult {
        guard let config,
              gameState.selectedWords.count == 4,
              let challengeId = currentChallengeId,
              let uid = Auth.auth().currentUser?.uid else {
            return .wrong
        }

        let selected = gameState.selectedWords

        // Already solved?
        for cat in config.categories where gameState.solvedCategoryIds.contains(cat.id) {
            if Set(cat.words) == selected { return .alreadySolved }
        }

        // Check for exact match
        if let match = config.categories.first(where: { Set($0.words) == selected && !gameState.solvedCategoryIds.contains($0.id) }) {
            gameState.solvedCategoryIds.insert(match.id)
            gameState.selectedWords = []

            let finished = gameState.isSolved(with: config)
            isFinished = finished
            isSubmitting = true
            await persistState(uid: uid, challengeId: challengeId, config: config)
            isSubmitting = false
            return .correct(category: match)
        }

        // Check one-away
        let isOneAway = config.categories.contains { cat in
            !gameState.solvedCategoryIds.contains(cat.id) &&
            Set(cat.words).intersection(selected).count == 3
        }

        gameState.mistakesUsed += 1
        gameState.selectedWords = []

        if gameState.mistakesUsed >= config.max_mistakes {
            isFinished = true
            isSubmitting = true
            await persistState(uid: uid, challengeId: challengeId, config: config)
            isSubmitting = false
        }

        return isOneAway ? .oneAway : .wrong
    }

    // MARK: - Persistence

    private func persistState(uid: String, challengeId: String, config: WeeklyChallengeConnectionsConfig) async {
        guard let profile = await fetchLinkedPlayerId(uid: uid) else { return }
        let score = gameState.totalScore(with: config)
        let linkedId = profile.linkedPlayerId ?? uid

        let data: [String: Any] = [
            "uid": uid,
            "linked_player_id": profile.linkedPlayerId as Any,
            "display_name": profile.displayName as Any,
            "score": score,
            "solved_categories": Array(gameState.solvedCategoryIds),
            "mistakes_used": gameState.mistakesUsed,
            "is_finished": isFinished,
            "updated_at": FieldValue.serverTimestamp()
        ]

        do {
            try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("submissions")
                .document(linkedId)
                .setData(data, merge: true)
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private func restoreState(from data: [String: Any]) {
        if let cats = data["solved_categories"] as? [String] {
            gameState.solvedCategoryIds = Set(cats)
        }
        if let mistakes = data["mistakes_used"] as? Int {
            gameState.mistakesUsed = mistakes
        }
        if let finished = data["is_finished"] as? Bool {
            isFinished = finished
        }
    }

    private func fetchLinkedPlayerId(uid: String) async -> (linkedPlayerId: String?, displayName: String?)? {
        let snap = try? await db.collection("users").document(uid).getDocument()
        let d = snap?.data()
        return (d?["linkedPlayerId"] as? String, d?["displayName"] as? String)
    }
}
