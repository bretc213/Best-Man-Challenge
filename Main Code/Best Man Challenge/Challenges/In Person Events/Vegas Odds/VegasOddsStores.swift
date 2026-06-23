//
//  VegasOddsStores.swift
//  Best Man Challenge
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Events

@MainActor
final class VegasOddsEventsStore: ObservableObject {
    @Published var events: [VegasOddsEvent] = []
    @Published var errorMessage: String? = nil

    private var listener: ListenerRegistration?

    func startListening() {
        stopListening()
        errorMessage = nil

        let db = Firestore.firestore()
        listener = db.collection("vegas_odds_events")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in self.errorMessage = err.localizedDescription }
                    return
                }

                let docs = snap?.documents ?? []
                let mapped = docs.map { VegasOddsEvent(id: $0.documentID, data: $0.data()) }
                Task { @MainActor in self.events = mapped }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}

// MARK: - Odds lines for a given event

@MainActor
final class VegasOddsLinesStore: ObservableObject {
    @Published var linesByPlayerId: [String: VegasOddsLine] = [:]
    @Published var errorMessage: String? = nil

    private var listener: ListenerRegistration?

    func startListening(eventId: String) {
        stopListening()
        errorMessage = nil

        let db = Firestore.firestore()
        listener = db.collection("vegas_odds_events")
            .document(eventId)
            .collection("odds")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in self.errorMessage = err.localizedDescription }
                    return
                }

                var out: [String: VegasOddsLine] = [:]
                for doc in snap?.documents ?? [] {
                    let line = VegasOddsLine(id: doc.documentID, data: doc.data())
                    // Key by playerId so lookups match PlayersStore ids
                    out[line.playerId] = line
                }

                Task { @MainActor in self.linesByPlayerId = out }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func line(for playerId: String) -> VegasOddsLine? {
        linesByPlayerId[playerId]
    }

    func oddsString(for playerId: String) -> String? {
        linesByPlayerId[playerId]?.oddsString
    }

    func americanOdds(for playerId: String) -> Int? {
        linesByPlayerId[playerId]?.americanOdds
    }

    func probability(for playerId: String) -> Double? {
        linesByPlayerId[playerId]?.top3Probability
    }

    func decimalOdds(for playerId: String) -> Double? {
        linesByPlayerId[playerId]?.decimalOdds
    }
}

// MARK: - Bankroll for an event (per user)

@MainActor
final class VegasOddsBankrollStore: ObservableObject {
    @Published var balance: Int? = nil
    @Published var errorMessage: String? = nil

    private var listener: ListenerRegistration?

    func startListening(eventId: String) {
        stopListening()
        errorMessage = nil

        guard let uid = Auth.auth().currentUser?.uid else {
            self.errorMessage = "Not signed in."
            self.balance = nil
            return
        }

        let db = Firestore.firestore()
        let ref = db.collection("vegas_odds_events")
            .document(eventId)
            .collection("bankrolls")
            .document(uid)

        listener = ref.addSnapshotListener { [weak self] snap, err in
            guard let self else { return }
            if let err {
                Task { @MainActor in self.errorMessage = err.localizedDescription }
                return
            }

            // Default bankroll is $300 if missing
            let bal = (snap?.data()?["balance"] as? NSNumber)?.intValue ?? 300
            Task { @MainActor in self.balance = bal }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}

// MARK: - A single user's bet status for an event

@MainActor
final class VegasOddsMyBetStore: ObservableObject {
    @Published var betAlreadyPlaced: Bool = false
    @Published var myBet: VegasOddsBet? = nil
    @Published var errorMessage: String? = nil

    private var listener: ListenerRegistration?

    func startListening(eventId: String) {
        stopListening()
        errorMessage = nil

        guard let bettorId = Auth.auth().currentUser?.uid else {
            self.errorMessage = "Not signed in."
            return
        }

        let db = Firestore.firestore()
        let docId = "\(eventId)_\(bettorId)"

        listener = db.collection("vegas_odds_bets")
            .document(docId)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in self.errorMessage = err.localizedDescription }
                    return
                }

                guard let snap, snap.exists else {
                    Task { @MainActor in
                        self.betAlreadyPlaced = false
                        self.myBet = nil
                    }
                    return
                }

                let bet = VegasOddsBet(id: snap.documentID, data: snap.data() ?? [:])
                Task { @MainActor in
                    self.betAlreadyPlaced = true
                    self.myBet = bet
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func placeBet(
        event: VegasOddsEvent,
        eventId: String,
        eventName: String,
        picks: [String],
        bettorDisplayName: String?,
        pickDisplayNames: [String],
        oddsStrings: [String]
    ) async throws {

        guard let bettorId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "VegasOdds", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
        }

        let db = Firestore.firestore()
        let docId = "\(eventId)_\(bettorId)"
        let ref = db.collection("vegas_odds_bets").document(docId)

        // Map auth uid -> playerId (linked_player_id)
        let userSnap = try await db.collection("users").document(bettorId).getDocument()
        let u = userSnap.data() ?? [:]
        guard let bettorPlayerId = (u["linked_player_id"] as? String) ?? (u["linkedPlayerId"] as? String) else {
            throw NSError(domain: "VegasOdds", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing linked_player_id for current user."])
        }

        let betPerPick = (picks.isEmpty ? event.betPerPick : (event.betPerPick))
        let totalWager = picks.count * betPerPick

        try await ref.setData([
            "eventId": eventId,
            "eventName": eventName,
            "bettorId": bettorId, // auth uid
            "bettorAuthUid": bettorId,
            "bettorPlayerId": bettorPlayerId,
            "bettorDisplayName": bettorDisplayName as Any,
            "picks": picks,
            "pickDisplayNames": pickDisplayNames,
            "oddsStrings": oddsStrings,
            "betPerPick": betPerPick,
            "maxPicks": event.maxPicks,
            "totalWager": totalWager,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "isSettled": false
        ], merge: true)
    }
}

// MARK: - Leaderboard totals (cached on players docs)

struct VegasWinningsRow: Identifiable {
    let id: String
    let displayName: String
    let vegasWinnings: Double
}

@MainActor
final class VegasOddsLeaderboardStore: ObservableObject {
    @Published var rows: [VegasWinningsRow] = []
    @Published var errorMessage: String? = nil

    private var listener: ListenerRegistration?

    func startListening() {
        stopListening()
        errorMessage = nil

        let db = Firestore.firestore()
        listener = db.collection("players")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in self.errorMessage = err.localizedDescription }
                    return
                }

                let docs = snap?.documents ?? []
                let mapped: [VegasWinningsRow] = docs.compactMap { d in
                    let data = d.data()
                    let name = (data["displayName"] as? String) ?? (data["display_name"] as? String) ?? d.documentID
                    let winnings = (data["vegas_winnings"] as? NSNumber)?.doubleValue
                        ?? (data["vegasWinnings"] as? NSNumber)?.doubleValue
                        ?? 0
                    return VegasWinningsRow(id: d.documentID, displayName: name, vegasWinnings: winnings)
                }
                .sorted { $0.vegasWinnings > $1.vegasWinnings }

                Task { @MainActor in self.rows = mapped }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}

// MARK: - Bet history for a given player

@MainActor
final class VegasOddsHistoryStore: ObservableObject {
    @Published var betsByEventId: [String: VegasOddsBet] = [:]
    @Published var errorMessage: String? = nil

    private var listener: ListenerRegistration?

    func startListening(bettorId: String) {
        stopListening()
        errorMessage = nil

        let db = Firestore.firestore()
        // Query by bettorPlayerId (player doc ID) — NOT bettorId (auth UID).
        // The leaderboard passes player IDs, and bet docs store the player ID in bettorPlayerId.
        listener = db.collection("vegas_odds_bets")
            .whereField("bettorPlayerId", isEqualTo: bettorId)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in self.errorMessage = err.localizedDescription }
                    return
                }

                var out: [String: VegasOddsBet] = [:]
                for doc in snap?.documents ?? [] {
                    let bet = VegasOddsBet(id: doc.documentID, data: doc.data())
                    out[bet.eventId] = bet
                }

                Task { @MainActor in self.betsByEventId = out }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
