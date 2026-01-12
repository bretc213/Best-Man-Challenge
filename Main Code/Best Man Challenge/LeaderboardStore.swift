//
//  LeaderboardStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 12/23/25.
//


import Foundation
import FirebaseFirestore

@MainActor
final class LeaderboardStore: ObservableObject {
    @Published var players: [LeaderboardPlayer] = []
    @Published var errorMessage: String? = nil

    private var listener: ListenerRegistration?

    func startListening() {
        let db = Firestore.firestore()

        listener?.remove()
        listener = db.collection("players")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                let docs = snapshot?.documents ?? []
                self.players = docs.compactMap { LeaderboardPlayer(id: $0.documentID, data: $0.data()) }
                self.errorMessage = nil
            }
    }

    deinit { listener?.remove() }
}
