//
//  Ranker.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/23/26.
//


import Foundation

enum Ranker {
    static func makeFinishGroups(
        scores: [String: Double],
        higherIsBetter: Bool = true
    ) -> [[String]] {
        // deterministic sort: primary by score, secondary by playerId (stable)
        let sorted = scores.sorted { a, b in
            if a.value == b.value { return a.key < b.key }
            return higherIsBetter ? (a.value > b.value) : (a.value < b.value)
        }

        var groups: [[String]] = []
        var current: [String] = []
        var lastScore: Double?

        for (pid, score) in sorted {
            if let last = lastScore, score != last {
                groups.append(current)
                current = [pid]
            } else {
                current.append(pid)
            }
            lastScore = score
        }
        if !current.isEmpty { groups.append(current) }
        return groups
    }
}
