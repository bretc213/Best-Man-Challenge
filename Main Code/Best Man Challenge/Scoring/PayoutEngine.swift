//
//  PayoutEngine.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/23/26.
//


import Foundation

enum PayoutEngine {
    static let baseline: [Double] = [15, 12, 10, 8, 7, 6, 5, 4, 3, 2, 1]

    static func awardPoints(
        finishGroups: [[String]],
        multiplier: Double = 1.0,
        baselinePoints: [Double] = baseline
    ) -> [String: Double] {
        let table = baselinePoints.map { $0 * multiplier }
        var awards: [String: Double] = [:]
        var slot = 0 // 0-based index (0 == 1st)

        for group in finishGroups where !group.isEmpty {
            let k = group.count
            let start = slot
            let end = min(slot + k, table.count)

            if start >= table.count {
                group.forEach { awards[$0] = 0 }
                slot += k
                continue
            }

            let slice = Array(table[start..<end])
            let total = slice.reduce(0, +)
            let avg = total / Double(k) // PGA tie averaging

            group.forEach { awards[$0] = avg }
            slot += k
        }

        return awards
    }
}
