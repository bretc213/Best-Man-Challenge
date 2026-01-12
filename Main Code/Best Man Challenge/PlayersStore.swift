//
//  PlayersStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 12/23/25.
//


import Foundation
import FirebaseFirestore

@MainActor
final class PlayersStore: ObservableObject {
    @Published var players: [FirestorePlayer] = []
    @Published var errorMessage: String? = nil

    private var listener: ListenerRegistration?

    func startListening() {
        let db = Firestore.firestore()

        listener?.remove()
        listener = db.collection("players")
            .order(by: "total_winnings", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                let docs = snapshot?.documents ?? []
                self.players = docs.compactMap { FirestorePlayer(id: $0.documentID, data: $0.data()) }
                self.errorMessage = nil
            }
    }

    deinit { listener?.remove() }
}
