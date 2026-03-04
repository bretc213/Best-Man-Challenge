//
//  BetService.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 12/23/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

enum BetService {

    static func confirmBet(
        challengeId: String,
        challengeTitle: String,
        selectedPlayerIds: [String],
        betAmount: Int,
        odds: [String],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let db = Firestore.firestore()
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "BetService", code: 401,
                                        userInfo: [NSLocalizedDescriptionKey: "Not logged in."])))
            return
        }

        // ✅ First: detect if this is a Vegas Odds event.
        let vegasEventRef = db.collection("vegas_odds_events").document(challengeId)
        vegasEventRef.getDocument { eventSnap, eventErr in
            if let eventSnap, eventSnap.exists {
                confirmVegasOddsBet(
                    db: db,
                    uid: uid,
                    eventId: challengeId,
                    eventName: challengeTitle,
                    selectedPlayerIds: selectedPlayerIds,
                    betAmount: betAmount,
                    odds: odds,
                    completion: completion
                )
            } else {
                // Fallback to legacy behavior (users.event_balance + bets collection)
                confirmLegacyBet(
                    db: db,
                    uid: uid,
                    challengeId: challengeId,
                    challengeTitle: challengeTitle,
                    selectedPlayerIds: selectedPlayerIds,
                    betAmount: betAmount,
                    odds: odds,
                    completion: completion
                )
            }

            if let eventErr {
                // If detection failed for some reason, still try legacy
                // (Don’t block betting just because this read failed).
                // NOTE: This is intentionally after the branches above.
                _ = eventErr
            }
        }
    }

    // MARK: - Vegas Odds path

    private static func confirmVegasOddsBet(
        db: Firestore,
        uid: String,
        eventId: String,
        eventName: String,
        selectedPlayerIds: [String],
        betAmount: Int,
        odds: [String],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let bankrollRef = db.collection("vegas_odds_events")
            .document(eventId)
            .collection("bankrolls")
            .document(uid)

        let betRef = db.collection("vegas_odds_bets").document("\(eventId)_\(uid)")
        let userRef = db.collection("users").document(uid)

        let betPerPick: Int = {
            guard !selectedPlayerIds.isEmpty else { return betAmount }
            return max(1, betAmount / selectedPlayerIds.count)
        }()

        db.runTransaction({ transaction, errorPointer -> Any? in
            // READS FIRST (required by Firestore transactions)

            // Event bankroll (default $300 if missing)
            let bankrollSnap: DocumentSnapshot
            do { bankrollSnap = try transaction.getDocument(bankrollRef) }
            catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            let currentBal = (bankrollSnap.data()?["balance"] as? NSNumber)?.intValue ?? 300
            if currentBal < betAmount {
                errorPointer?.pointee = NSError(
                    domain: "BetService",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey:
                        "Not enough balance. You have $\(currentBal), need $\(betAmount)."
                    ]
                )
                return nil
            }

            // Optional: user display name + linked player id
            var bettorDisplayName: String? = nil
            var bettorPlayerId: String? = nil
            if let userSnap = try? transaction.getDocument(userRef) {
                let u = userSnap.data() ?? [:]
                bettorDisplayName = (u["displayName"] as? String)
                    ?? (u["name"] as? String)
                    ?? (u["display_name"] as? String)

                bettorPlayerId = (u["linked_player_id"] as? String)
                    ?? (u["linkedPlayerId"] as? String)
            }

            if bettorPlayerId == nil {
                errorPointer?.pointee = NSError(
                    domain: "BetService",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Your account is missing linked_player_id in users/\(uid)."]
                )
                return nil
            }

            // Fetch pick display names from players collection
            var pickDisplayNames: [String] = []
            pickDisplayNames.reserveCapacity(selectedPlayerIds.count)

            for pid in selectedPlayerIds {
                let pRef = db.collection("players").document(pid)
                if let pSnap = try? transaction.getDocument(pRef) {
                    let data = pSnap.data() ?? [:]
                    let name = (data["displayName"] as? String)
                        ?? (data["display_name"] as? String)
                        ?? pid
                    pickDisplayNames.append(name)
                } else {
                    pickDisplayNames.append(pid)
                }
            }

            // WRITES AFTER READS

            // Bet doc (Vegas odds)
            let betData: [String: Any] = [
                "eventId": eventId,
                "eventName": eventName,
                "bettorId": uid, // auth uid (doc id key)
                "bettorAuthUid": uid,
                "bettorPlayerId": bettorPlayerId as Any,
                "bettorDisplayName": bettorDisplayName as Any,
                "picks": selectedPlayerIds,
                "pickDisplayNames": pickDisplayNames,
                "oddsStrings": odds,
                "betPerPick": betPerPick,
                "maxPicks": selectedPlayerIds.count,
                "totalWager": betAmount,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "isSettled": false
            ]
            transaction.setData(betData, forDocument: betRef, merge: true)

            // Bankroll update
            transaction.setData([
                "balance": currentBal - betAmount,
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: bankrollRef, merge: true)

            return nil
        }, completion: { _, error in
            if let error = error { completion(.failure(error)) }
            else { completion(.success(())) }
        })
    }

    // MARK: - Legacy path (unchanged)

    private static func confirmLegacyBet(
        db: Firestore,
        uid: String,
        challengeId: String,
        challengeTitle: String,
        selectedPlayerIds: [String],
        betAmount: Int,
        odds: [String],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let userRef = db.collection("users").document(uid)
        let betRef = db.collection("bets").document()

        let betData: [String: Any] = [
            "bettor_uid": uid,
            "challenge_id": challengeId,
            "challenge_title": challengeTitle,
            "bet_amount": betAmount,
            "selected_player_ids": selectedPlayerIds,
            "odds": odds,
            "created_at": FieldValue.serverTimestamp()
        ]

        db.runTransaction({ transaction, errorPointer -> Any? in
            // READS FIRST
            let userSnap: DocumentSnapshot
            do {
                userSnap = try transaction.getDocument(userRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            let currentBal = (userSnap.data()?["event_balance"] as? NSNumber)?.intValue ?? 0
            if currentBal < betAmount {
                errorPointer?.pointee = NSError(
                    domain: "BetService",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey:
                        "Not enough balance. You have $\(currentBal), need $\(betAmount)."
                    ]
                )
                return nil
            }

            // WRITES AFTER READS
            transaction.setData(betData, forDocument: betRef)
            transaction.updateData(["event_balance": currentBal - betAmount], forDocument: userRef)

            return nil
        }, completion: { _, error in
            if let error = error { completion(.failure(error)) }
            else { completion(.success(())) }
        })
    }
}
