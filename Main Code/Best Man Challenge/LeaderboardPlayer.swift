//
//  LeaderboardPlayer.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 12/23/25.
//


import Foundation

struct LeaderboardPlayer: Identifiable, Hashable {
    let id: String
    let name: String
    let totalPoints: Int

    init?(id: String, data: [String: Any]) {
        guard let name = data["display_name"] as? String else { return nil }
        self.id = id
        self.name = name
        self.totalPoints = (data["total_points"] as? NSNumber)?.intValue ?? 0
    }
}
