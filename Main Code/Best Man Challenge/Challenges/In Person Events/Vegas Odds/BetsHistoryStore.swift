//
//  BetsHistoryStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 12/23/25.
//


import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class BetsHistoryStore: ObservableObject {
    @Published var bets: [FirestoreBet] = []
    @Published var errorMessage: String? = nil

    private var listener: ListenerRegistration?

    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Not logged in."
            bets = []
            return
        }

        let db = Firestore.firestore()
        listener?.remove()
        listener = db.collection("bets")
            .whereField("bettor_uid", isEqualTo: uid)
            .order(by: "created_at", descending: true)
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.bets = []
                    return
                }

                let docs = snap?.documents ?? []
                self.bets = docs.compactMap { FirestoreBet(id: $0.documentID, data: $0.data()) }
                self.errorMessage = nil
            }
    }

    deinit { listener?.remove() }
}
