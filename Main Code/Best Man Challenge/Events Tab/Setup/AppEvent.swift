//
//  AppEvent.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/20/26.
//


import Foundation
import FirebaseFirestore

struct AppEvent: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var kind: String               // "in_person" for now
    var startDate: Date
    var endDate: Date
    var location: String?
    var notes: String?
    /// Bumped whenever event details change significantly enough to require re-confirmation.
    /// If an existing RSVP's stored version doesn't match, the user is prompted to reconfirm.
    var rsvpVersion: Int?
    /// Optional arrival time choices displayed alongside the RSVP (e.g. for multi-day trips).
    var arrivalOptions: [String]?
}
