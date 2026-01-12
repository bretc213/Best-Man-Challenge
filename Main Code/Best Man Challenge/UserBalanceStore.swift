//
//  UserBalanceStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 12/23/25.
//


import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class UserBalanceStore: ObservableObject {
    @Published var eventBalance: Int = 0
    @Published var errorMessage: String? = nil

    private var listener: ListenerRegistration?

    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Not logged in."
            return
        }

        let db = Firestore.firestore()
        listener?.remove()
        listener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                let data = snap?.data() ?? [:]
                self.eventBalance = (data["event_balance"] as? NSNumber)?.intValue ?? 0
                self.errorMessage = nil
            }
    }

    deinit { listener?.remove() }
}
