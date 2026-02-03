//
//  WeeklyChallengesHistoryStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/7/26.
//

import Foundation
import FirebaseFirestore

@MainActor
final class WeeklyChallengesHistoryStore: ObservableObject {
    @Published var pastChallenges: [WeeklyChallenge] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening() {
        errorMessage = nil
        isLoading = true

        listener?.remove()
        listener = db.collection("weekly_challenges")
            .whereField("is_active", isEqualTo: false)
            .order(by: "week", descending: true)
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
                let parsed: [WeeklyChallenge] = docs.compactMap { doc in
                    WeeklyChallengeManager.parseWeeklyChallenge(doc: doc)
                }

                Task { @MainActor in
                    self.pastChallenges = parsed
                    self.isLoading = false
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        isLoading = false
    }
}
