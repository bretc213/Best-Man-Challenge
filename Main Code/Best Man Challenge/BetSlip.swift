//
//  BetSlip.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 5/24/25.
//


import Foundation

struct BetSlip: Identifiable {
    let id = UUID()
    let challenge: String
    let selectedPlayers: [String]
    let odds: [String]
    let betAmount: Int
    let toWin: Int
    let timestamp: Date
}
