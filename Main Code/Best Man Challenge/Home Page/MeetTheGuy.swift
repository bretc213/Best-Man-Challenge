//
//  MeetTheGuy.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/2/26.
//


import Foundation

struct MeetTheGuy: Identifiable {
    let id: String              // matches playerId (bretc, joelr, etc.)
    let name: String
    let email: String
    let nickname: String
    let relationship: String
    let favoriteMemory: String
    let rating: String
    let funFacts: String
    let photoAssetName: String? // nil for now, filled later
}
