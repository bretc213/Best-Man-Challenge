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
