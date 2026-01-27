//
//  PlayerLedgerStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/24/26.
//


import Foundation
import FirebaseFirestore

@MainActor
final class PlayerLedgerStore: ObservableObject {
    @Published var awards: [PointAward] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private var listener: ListenerRegistration?

    func startListening(playerId: String) {
        stopListening()
        isLoading = true
        errorMessage = nil

        let db = Firestore.firestore()

        listener = db.collection("point_awards")
            .whereField("playerId", isEqualTo: playerId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }

                if let err {
                    Task { @MainActor in
                        self.errorMessage = err.localizedDescription
                        self.isLoading = false
                    }
                    return
                }

                let docs = snap?.documents ?? []
                let parsed = docs.compactMap {
                    PointAward(id: $0.documentID, data: $0.data())
                }

                Task { @MainActor in
                    self.awards = parsed
                    self.isLoading = false
                    self.errorMessage = nil
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
