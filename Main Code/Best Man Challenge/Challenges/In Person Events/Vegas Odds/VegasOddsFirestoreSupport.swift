//
//  VegasOddsFirestoreSupport.swift
//  Best Man Challenge
//

import Foundation
import FirebaseFirestore

extension Timestamp: TimestampLike {
    var dateValue: Date { self.dateValue() }
}

// MARK: - Odds math (probability-driven)

enum OddsMath {

    static func clampProbability(_ p: Double) -> Double {
        min(max(p, 0.0001), 0.9999)
    }

    /// Fair American odds from probability.
    static func americanOdds(fromProbability p: Double) -> Int {
        let p = clampProbability(p)
        if p >= 0.5 {
            return -Int(round((p / (1 - p)) * 100))
        } else {
            return Int(round(((1 - p) / p) * 100))
        }
    }

    static func formatAmerican(_ odds: Int) -> String {
        odds > 0 ? "+\(odds)" : "\(odds)"
    }

    /// Fair decimal odds from probability.
    static func decimalOdds(fromProbability p: Double) -> Double {
        1.0 / clampProbability(p)
    }

    /// Convert American odds to implied probability.
    static func probability(fromAmerican odds: Int) -> Double {
        if odds > 0 {
            return 100.0 / (Double(odds) + 100.0)
        } else {
            return Double(-odds) / (Double(-odds) + 100.0)
        }
    }

    /// Convert American odds directly to decimal odds.
    static func decimalOdds(fromAmerican odds: Int) -> Double {
        if odds > 0 {
            return (Double(odds) / 100.0) + 1.0
        } else {
            return (100.0 / Double(-odds)) + 1.0
        }
    }
}
