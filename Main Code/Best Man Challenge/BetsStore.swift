//
//  BetsStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 12/23/25.
//


import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class BetsStore: ObservableObject {
    @Published var betAlreadyPlaced: Bool = false
    @Published var errorMessage: String? = nil

    private var listener: ListenerRegistration?
    private var currentChallengeId: String = ""

    func setChallengeId(_ challengeId: String) {
        guard challengeId != currentChallengeId else { return }
        currentChallengeId = challengeId
        restartListener()
    }

    func startListening() {
        restartListener()
    }

    private func restartListener() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Not logged in."
            betAlreadyPlaced = false
            return
        }
        guard !currentChallengeId.isEmpty else { return }

        let db = Firestore.firestore()
        listener?.remove()

        listener = db.collection("bets")
            .whereField("bettor_uid", isEqualTo: uid)
            .whereField("challenge_id", isEqualTo: currentChallengeId)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.betAlreadyPlaced = false
                    return
                }

                self.betAlreadyPlaced = !(snap?.documents.isEmpty ?? true)
                self.errorMessage = nil
            }
    }

    deinit { listener?.remove() }
}
