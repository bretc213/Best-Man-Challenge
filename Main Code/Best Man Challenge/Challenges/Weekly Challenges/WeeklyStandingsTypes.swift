//
//  WeeklyScoreRow 2.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/12/26.
//

import Foundation
import SwiftUI



struct WeeklyScoreRow: Identifiable {
    let id: String
    let displayName: String

    let score: Int
    let maxScore: Int?

    let answers: [String: Int]?

    let submittedAt: Date?
}


enum WeeklyGroupMode: String, CaseIterable {
    case players = "Players"
    case admins  = "Admins"
}
