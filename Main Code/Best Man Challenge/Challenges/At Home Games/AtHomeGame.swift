//
//  AtHomeGame.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/31/26.
//

import Foundation
import FirebaseFirestore

struct AtHomeGame: Identifiable, Hashable {
    let id: String
    let title: String
    let assetImage: String
    let route: String
    let state: String
    let sortOrder: Int

    // 🔹 NEW (Firebase-driven routing)
    let gameType: String?
    let gameRefId: String?

    // Optional / existing
    let challengeId: String?
    let startsAt: Date?

    init?(id: String, data: [String: Any]) {
        guard
            let title = data["title"] as? String,
            let assetImage = data["assetImage"] as? String,
            let route = data["route"] as? String,
            let state = data["state"] as? String
        else { return nil }

        self.id = id
        self.title = title
        self.assetImage = assetImage
        self.route = route
        self.state = state
        self.sortOrder = (data["sortOrder"] as? NSNumber)?.intValue ?? 0

        // 🔹 NEW fields from Firestore
        self.gameType = data["gameType"] as? String
        self.gameRefId = data["gameRefId"] as? String

        // Existing / optional
        self.challengeId = data["challengeId"] as? String

        if let ts = data["startsAt"] as? Timestamp {
            self.startsAt = ts.dateValue()
        } else {
            self.startsAt = nil
        }
    }
}
