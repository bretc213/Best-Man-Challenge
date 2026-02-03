//
//  AtHomeGamesStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/31/26.
//


import Foundation
import FirebaseFirestore

@MainActor
final class AtHomeGamesStore: ObservableObject {
    @Published var games: [AtHomeGame] = []
    @Published var errorMessage: String? = nil

    private var listener: ListenerRegistration?

    func startListening() {
        let db = Firestore.firestore()

        listener?.remove()
        listener = db.collection("at_home_games")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                let docs = snapshot?.documents ?? []
                let mapped = docs.compactMap { AtHomeGame(id: $0.documentID, data: $0.data()) }

                // Sort by state group (optional) then sortOrder then title
                self.games = mapped.sorted {
                    if $0.state != $1.state { return $0.state < $1.state }
                    if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                    return $0.title < $1.title
                }

                self.errorMessage = nil
            }
    }

    deinit { listener?.remove() }
}
