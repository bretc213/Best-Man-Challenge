//
//  PokerNightModels.swift
//  Best Man Challenge
//

import Foundation
import FirebaseFirestore

struct PokerElimination: Identifiable, Hashable {
    var id: String { playerUid }

    let playerUid: String
    let place: Int
    let eliminatedAt: Date
    let eliminatedByUid: String
    let eliminatedByName: String
}

struct PokerEventState: Hashable {
    let name: String
    let ownerUid: String

    let playerUids: [String]
    let refUids: [String]

    var winnerUid: String?
    var winnerPhotoURL: String?
    var chipLeadUid: String?

    var eliminated: [PokerElimination]

    var isFinalized: Bool
    var finalizedAt: Date?

    var createdAt: Date?
    var updatedAt: Date?
}

// MARK: - Firestore Mapping

extension PokerElimination {
    init?(from dict: [String: Any]) {
        guard
            let playerUid = dict["playerUid"] as? String,
            let place = dict["place"] as? Int
        else { return nil }

        let eliminatedAt: Date
        if let ts = dict["eliminatedAt"] as? Timestamp {
            eliminatedAt = ts.dateValue()
        } else if let d = dict["eliminatedAt"] as? Date {
            eliminatedAt = d
        } else {
            eliminatedAt = Date(timeIntervalSince1970: 0)
        }

        let eliminatedByUid = dict["eliminatedByUid"] as? String ?? ""
        let eliminatedByName = dict["eliminatedByName"] as? String ?? "Unknown"

        self.playerUid = playerUid
        self.place = place
        self.eliminatedAt = eliminatedAt
        self.eliminatedByUid = eliminatedByUid
        self.eliminatedByName = eliminatedByName
    }

    var firestoreDict: [String: Any] {
        [
            "playerUid": playerUid,
            "place": place,
            "eliminatedAt": Timestamp(date: eliminatedAt),
            "eliminatedByUid": eliminatedByUid,
            "eliminatedByName": eliminatedByName
        ]
    }
}

extension PokerEventState {
    init?(from data: [String: Any]) {
        guard
            let name = data["name"] as? String,
            let ownerUid = data["ownerUid"] as? String,
            let playerUids = data["playerUids"] as? [String],
            let refUids = data["refUids"] as? [String]
        else { return nil }

        self.name = name
        self.ownerUid = ownerUid
        self.playerUids = playerUids
        self.refUids = refUids

        self.winnerUid = data["winnerUid"] as? String
        self.winnerPhotoURL = data["winnerPhotoURL"] as? String
        self.chipLeadUid = data["chipLeadUid"] as? String

        let elimArray = (data["eliminated"] as? [[String: Any]] ?? [])
        self.eliminated = elimArray.compactMap { PokerElimination(from: $0) }

        self.isFinalized = (data["is_finalized"] as? Bool) ?? false
        if let ts = data["finalizedAt"] as? Timestamp { self.finalizedAt = ts.dateValue() }
        else if let d = data["finalizedAt"] as? Date { self.finalizedAt = d }
        else { self.finalizedAt = nil }

        if let ts = data["createdAt"] as? Timestamp { self.createdAt = ts.dateValue() }
        else if let d = data["createdAt"] as? Date { self.createdAt = d }
        else { self.createdAt = nil }

        if let ts = data["updatedAt"] as? Timestamp { self.updatedAt = ts.dateValue() }
        else if let d = data["updatedAt"] as? Date { self.updatedAt = d }
        else { self.updatedAt = nil }
    }
}
