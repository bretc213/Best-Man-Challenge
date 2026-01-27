//
//  PointAward.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/24/26.
//


import Foundation
import FirebaseFirestore

struct PointAward: Identifiable, Hashable {
    let id: String

    let challengeId: String
    let playerId: String

    let points: Double
    let basePoints: Double
    let bonusPoints: Double
    let multiplier: Double?

    let createdAt: Date?
    let note: String?

    init?(id: String, data: [String: Any]) {
        guard
            let challengeId = data["challengeId"] as? String,
            let playerId = data["playerId"] as? String
        else { return nil }

        self.id = id
        self.challengeId = challengeId
        self.playerId = playerId

        self.points = (data["points"] as? NSNumber)?.doubleValue ?? 0.0
        self.basePoints = (data["basePoints"] as? NSNumber)?.doubleValue ?? 0.0
        self.bonusPoints = (data["bonusPoints"] as? NSNumber)?.doubleValue ?? 0.0
        self.multiplier = (data["multiplier"] as? NSNumber)?.doubleValue

        if let ts = data["createdAt"] as? Timestamp {
            self.createdAt = ts.dateValue()
        } else {
            self.createdAt = nil
        }

        self.note = data["note"] as? String
    }
}
