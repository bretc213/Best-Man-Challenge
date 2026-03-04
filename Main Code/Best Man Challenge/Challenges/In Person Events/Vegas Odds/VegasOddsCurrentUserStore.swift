//
//  VegasOddsCurrentUserStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 2/27/26.
//


import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class VegasOddsCurrentUserStore: ObservableObject {
    @Published var linkedPlayerId: String? = nil
    @Published var errorMessage: String? = nil

    private var listener: ListenerRegistration?

    func startListening() {
        stopListening()
        errorMessage = nil

        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            errorMessage = "Not signed in."
            linkedPlayerId = nil
            return
        }

        let db = Firestore.firestore()
        listener = db.collection("users")
            .document(uid)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }

                if let err {
                    Task { @MainActor in
                        self.errorMessage = err.localizedDescription
                        self.linkedPlayerId = nil
                    }
                    return
                }

                let data = snap?.data() ?? [:]
                let pid = (data["linked_player_id"] as? String)
                    ?? (data["linkedPlayerId"] as? String) // just in case you ever rename it

                Task { @MainActor in
                    self.linkedPlayerId = pid
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit {
        // deinit is not MainActor-isolated, so hop safely:
        Task { @MainActor [weak self] in
            self?.stopListening()
        }
    }
}