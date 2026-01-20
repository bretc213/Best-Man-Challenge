//
//  RSVPStatus.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/20/26.
//


import Foundation

enum RSVPStatus: String, CaseIterable, Codable {
    case yes
    case no
    case maybe

    var label: String {
        switch self {
        case .yes: return "Yes"
        case .no: return "No"
        case .maybe: return "Maybe"
        }
    }
}
