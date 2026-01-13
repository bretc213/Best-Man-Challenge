//
//  WeeklyScoreRow 2.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/12/26.
//


import Foundation

struct WeeklyScoreRow: Identifiable {
    let id: String              // uid
    let displayName: String
    let linkedPlayerId: String?
    let score: Int
    let maxScore: Int?
    let submittedAt: Date?
}

enum WeeklyGroupMode: String, CaseIterable {
    case players = "Players"
    case admins  = "Admins"
}
