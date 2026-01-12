//
//  WeeklyOverallRow.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/7/26.
//


import Foundation
import FirebaseFirestore

struct WeeklyOverallRow: Identifiable {
    let id: String              // linkedPlayerId
    let displayName: String
    let totalPoints: Int
}

@MainActor
final class WeeklyChallengesOverallStore: ObservableObject {
    @Published var rows: [WeeklyOverallRow] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening() {
        errorMessage = nil
        isLoading = true

        listener?.remove()
        listener = db.collection("weekly_challenges_leaderboard")
            .order(by: "totalPoints", descending: true)
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
                let parsed: [WeeklyOverallRow] = docs.map { doc in
                    let d = doc.data()
                    return WeeklyOverallRow(
                        id: doc.documentID,
                        displayName: d["displayName"] as? String ?? doc.documentID,
                        totalPoints: d["totalPoints"] as? Int ?? 0
                    )
                }

                Task { @MainActor in
                    self.rows = parsed
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
