//
//  FirestoreBet.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 12/23/25.
//


import Foundation
import FirebaseFirestore

struct FirestoreBet: Identifiable, Hashable {
    let id: String
    let challengeTitle: String
    let betAmount: Int
    let selectedPlayerIds: [String]
    let odds: [String]
    let createdAt: Date?

    init?(id: String, data: [String: Any]) {
        guard let challengeTitle = data["challenge_title"] as? String else { return nil }

        self.id = id
        self.challengeTitle = challengeTitle
        self.betAmount = (data["bet_amount"] as? NSNumber)?.intValue ?? 0
        self.selectedPlayerIds = data["selected_player_ids"] as? [String] ?? []
        self.odds = data["odds"] as? [String] ?? []
        if let ts = data["created_at"] as? Timestamp {
            self.createdAt = ts.dateValue()
        } else {
            self.createdAt = nil
        }
    }
}
