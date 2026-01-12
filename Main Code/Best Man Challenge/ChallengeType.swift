//
//  ChallengeType.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 12/25/25.
//

import Foundation

enum ChallengeType: String, Codable, CaseIterable {
    case riddle
    case minesweeper
    case creative
    case quiz = "quiz"
}
