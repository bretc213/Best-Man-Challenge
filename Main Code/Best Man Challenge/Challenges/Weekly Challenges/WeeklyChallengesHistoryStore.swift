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
            .order(by: "weekInt", descending: true)
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
                let now = Date()
                let parsed: [WeeklyChallenge] = docs.compactMap { doc in
                    WeeklyChallengeManager.parseWeeklyChallenge(doc: doc)
                }.filter { ch in
                    // Show if end_date has passed — primary trigger
                    if let end = ch.endDate { return end < now }

                    // No end date: fall back to start date
                    if let start = ch.startDate { return start < now }

                    // is_finalized == true is a catch-all override (no dates set)
                    return ch.is_finalized == true
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
