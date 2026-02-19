//
//  PokerNightStore.swift
//  Best Man Challenge
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class PokerNightStore: ObservableObject {
    @Published var eventId: String
    @Published var state: PokerEventState?

    // UI display
    @Published var displayNameByUid: [String: String] = [:]

    // For finalizer (maps uid -> linked_player_id)
    @Published var linkedPlayerIdByUid: [String: String] = [:]

    @Published var isLoading: Bool = true
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // ✅ Your schema (per screenshot)
    private let usersCollection = "users"
    private let displayNameField = "display_name"
    private let linkedPlayerIdField = "linked_player_id"

    init(eventId: String) {
        self.eventId = eventId
        listen()
    }

    deinit { listener?.remove() }

    var isOwner: Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        return state?.ownerUid == uid
    }

    func listen() {
        isLoading = true
        errorMessage = nil

        let ref = db.collection("poker_events").document(eventId)

        listener?.remove()
        listener = ref.addSnapshotListener { [weak self] snap, err in
            guard let self else { return }

            if let err {
                Task { @MainActor in
                    self.errorMessage = err.localizedDescription
                    self.isLoading = false
                }
                return
            }

            guard let snap, snap.exists, let data = snap.data() else {
                Task { @MainActor in
                    self.errorMessage = "Poker event not found."
                    self.isLoading = false
                }
                return
            }

            guard let parsed = PokerEventState(from: data) else {
                Task { @MainActor in
                    self.errorMessage = "Poker event schema mismatch (missing required fields)."
                    self.isLoading = false
                }
                return
            }

            Task { @MainActor in
                self.state = parsed
                self.isLoading = false
            }

            Task { await self.loadUserProfilesIfNeeded(for: parsed) }
        }
    }

    private func loadUserProfilesIfNeeded(for state: PokerEventState) async {
        let needed = Set(state.playerUids + state.refUids)

        // Only fetch missing ones
        let missing = Array(needed.filter {
            displayNameByUid[$0] == nil || linkedPlayerIdByUid[$0] == nil
        })

        if missing.isEmpty { return }

        let chunks = missing.chunked(into: 30) // whereIn limit

        for chunk in chunks {
            do {
                let snap = try await db.collection(usersCollection)
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()

                var nameUpdates: [String: String] = [:]
                var linkedUpdates: [String: String] = [:]

                for doc in snap.documents {
                    let uid = doc.documentID

                    let display = (doc.get(displayNameField) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    nameUpdates[uid] = (display?.isEmpty == false) ? display! : uid

                    let linked = (doc.get(linkedPlayerIdField) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let linked, !linked.isEmpty {
                        linkedUpdates[uid] = linked
                    }
                }

                // fallback for any uid without a doc
                for uid in chunk {
                    if nameUpdates[uid] == nil { nameUpdates[uid] = uid }
                }

                await MainActor.run {
                    self.displayNameByUid.merge(nameUpdates) { _, new in new }
                    self.linkedPlayerIdByUid.merge(linkedUpdates) { _, new in new }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load user profiles: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Admin Actions

    func setWinner(_ playerUid: String) async {
        guard isOwner, var s = state else { return }
        guard s.playerUids.contains(playerUid) else { return } // refs can't win
        s.winnerUid = playerUid
        await writeStateMerge(s)
    }

    func setChipLead(_ playerUid: String) async {
        guard isOwner, var s = state else { return }
        guard s.playerUids.contains(playerUid) else { return } // refs can't be chip lead
        s.chipLeadUid = playerUid
        await writeStateMerge(s)
    }

    func eliminate(playerUid: String, eliminatedByUid: String) async {
        guard isOwner, var s = state else { return }
        guard s.playerUids.contains(playerUid) else { return } // only the 12 place
        guard !s.eliminated.contains(where: { $0.playerUid == playerUid }) else { return }

        let total = s.playerUids.count
        let alreadyEliminated = s.eliminated.count
        let nextPlace = total - alreadyEliminated // 12, 11, 10...

        let eliminatorName = displayNameByUid[eliminatedByUid] ?? "Unknown"

        let entry = PokerElimination(
            playerUid: playerUid,
            place: nextPlace,
            eliminatedAt: Date(),
            eliminatedByUid: eliminatedByUid,
            eliminatedByName: eliminatorName
        )

        s.eliminated.append(entry)

        if s.chipLeadUid == playerUid { s.chipLeadUid = nil }
        if s.winnerUid == playerUid { s.winnerUid = nil }

        await writeStateMerge(s)
    }

    func resetPlayer(_ playerUid: String) async {
        guard isOwner, var s = state else { return }
        s.eliminated.removeAll { $0.playerUid == playerUid }
        if s.chipLeadUid == playerUid { s.chipLeadUid = nil }
        if s.winnerUid == playerUid { s.winnerUid = nil }
        await writeStateMerge(s)
    }

    func resetAll() async {
        guard isOwner, var s = state else { return }
        s.winnerUid = nil
        s.winnerPhotoURL = nil
        s.chipLeadUid = nil
        s.eliminated = []
        s.isFinalized = false
        s.finalizedAt = nil
        await writeStateMerge(s)
    }

    // MARK: - Finalizer (×2)

    /// Returns scores keyed by linked_player_id, using the final places.
    /// Requires: winner set AND 11 eliminations (places 2-12 locked).
    func buildFinalizerScores() throws -> [String: Double] {
        guard let s = state else {
            throw PokerFinalizeError.noState
        }

        let total = s.playerUids.count // should be 12
        guard total == 12 else {
            throw PokerFinalizeError.badPlayerCount(expected: 12, actual: total)
        }

        guard let winnerUid = s.winnerUid else {
            throw PokerFinalizeError.missingWinner
        }

        // ✅ Enforce all 12 places determined:
        // If winner is set, we require 11 eliminations (#2-#12).
        guard s.eliminated.count == 11 else {
            throw PokerFinalizeError.incompletePlacements(currentEliminations: s.eliminated.count, requiredEliminations: 11)
        }

        // Build place map
        var placeByUid: [String: Int] = [:]
        placeByUid[winnerUid] = 1

        for e in s.eliminated {
            placeByUid[e.playerUid] = e.place
        }

        // Ensure we have a place for every player uid
        for uid in s.playerUids {
            if placeByUid[uid] == nil {
                throw PokerFinalizeError.missingPlaceForPlayer(uid: uid)
            }
        }

        // Convert to scores and key by linked_player_id
        var scores: [String: Double] = [:]
        for uid in s.playerUids {
            guard let place = placeByUid[uid] else { continue }

            // place 1 -> 12 pts ... place 12 -> 1 pt
            let pts = Double(total - place + 1)

            guard let linked = linkedPlayerIdByUid[uid], !linked.isEmpty else {
                throw PokerFinalizeError.missingLinkedPlayerId(uid: uid)
            }

            scores[linked] = pts
        }

        return scores
    }

    /// Marks the poker event as finalized in Firestore.
    func markFinalized() async {
        do {
            try await db.collection("poker_events").document(eventId).setData([
                "is_finalized": true,
                "finalizedAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Firestore write

    private func writeStateMerge(_ s: PokerEventState) async {
        do {
            let ref = db.collection("poker_events").document(eventId)
            try await ref.setData([
                "winnerUid": s.winnerUid as Any,
                "winnerPhotoURL": s.winnerPhotoURL as Any,
                "chipLeadUid": s.chipLeadUid as Any,
                "eliminated": s.eliminated.map { $0.firestoreDict },
                "updatedAt": Timestamp(date: Date())
            ], merge: true)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Errors

enum PokerFinalizeError: LocalizedError {
    case noState
    case badPlayerCount(expected: Int, actual: Int)
    case missingWinner
    case incompletePlacements(currentEliminations: Int, requiredEliminations: Int)
    case missingPlaceForPlayer(uid: String)
    case missingLinkedPlayerId(uid: String)

    var errorDescription: String? {
        switch self {
        case .noState:
            return "Poker Night data not loaded yet."
        case .badPlayerCount(let e, let a):
            return "Poker Night expected \(e) players, found \(a)."
        case .missingWinner:
            return "Set the Winner before finalizing."
        case .incompletePlacements(let cur, let req):
            return "Not ready to finalize. You have \(cur) eliminations; you need \(req)."
        case .missingPlaceForPlayer:
            return "Not ready to finalize. A player is missing a locked place."
        case .missingLinkedPlayerId:
            return "Cannot finalize because a player is missing linked_player_id in users/{uid}."
        }
    }
}

// MARK: - Utils

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var result: [[Element]] = []
        var i = 0
        while i < count {
            let end = Swift.min(i + size, count)
            result.append(Array(self[i..<end]))
            i = end
        }
        return result
    }
}
