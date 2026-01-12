//
//  Player.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 6/23/25.
//


import Foundation

struct FirestorePlayer: Identifiable, Hashable {
    let id: String                 // Firestore doc id (e.g. "player01")
    let displayName: String
    let eventBalance: Int
    let totalWinnings: Double

    init?(id: String, data: [String: Any]) {
        guard let displayName = data["display_name"] as? String else { return nil }
        self.id = id
        self.displayName = displayName
        self.eventBalance = (data["event_balance"] as? NSNumber)?.intValue ?? 0
        self.totalWinnings = (data["total_winnings"] as? NSNumber)?.doubleValue ?? 0
    }
}
