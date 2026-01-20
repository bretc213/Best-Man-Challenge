//
//  InPersonEventsSeeder.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/20/26.
//


import Foundation
import FirebaseFirestore

enum InPersonEventsSeeder {

    static func seed() async throws {
        let db = Firestore.firestore()
        let col = db.collection("events")

        func ts(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Timestamp {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
            let date = cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
            return Timestamp(date: date)
        }

        let events: [[String: Any]] = [
            [
                "id": "poker_night_2026_03_07",
                "title": "Poker Night",
                "kind": "in_person",
                "startDate": ts(2026, 3, 7, 19, 0),
                "endDate": ts(2026, 3, 7, 23, 0),
                "location": "TBD",
                "notes": ""
            ],
            [
                "id": "backyard_day_2026_05_24",
                "title": "Backyard Day",
                "kind": "in_person",
                "startDate": ts(2026, 5, 24, 12, 0),
                "endDate": ts(2026, 5, 24, 18, 0),
                "location": "TBD",
                "notes": ""
            ],
            [
                "id": "golf_sim_2026_07_03",
                "title": "Golf Simulator",
                "kind": "in_person",
                "startDate": ts(2026, 7, 3, 19, 0),
                "endDate": ts(2026, 7, 3, 22, 0),
                "location": "TBD",
                "notes": ""
            ],
            [
                "id": "weekend_trip_2026_10_16",
                "title": "Weekend Trip",
                "kind": "in_person",
                "startDate": ts(2026, 10, 16, 10, 0),
                "endDate": ts(2026, 10, 18, 18, 0),
                "location": "TBD",
                "notes": ""
            ],
            [
                "id": "board_video_games_2026_12_19",
                "title": "Board / Video Games",
                "kind": "in_person",
                "startDate": ts(2026, 12, 19, 18, 0),
                "endDate": ts(2026, 12, 19, 23, 0),
                "location": "TBD",
                "notes": ""
            ],
            [
                // I’m interpreting "1/2/27/26" as Jan 2, 2027
                "id": "closing_ceremonies_2027_01_02",
                "title": "Closing Ceremonies",
                "kind": "in_person",
                "startDate": ts(2027, 1, 2, 18, 0),
                "endDate": ts(2027, 1, 2, 22, 0),
                "location": "TBD",
                "notes": ""
            ]
        ]

        for e in events {
            let id = e["id"] as! String
            let ref = col.document(id)

            var data = e
            data.removeValue(forKey: "id")
            data["createdAt"] = FieldValue.serverTimestamp()
            data["updatedAt"] = FieldValue.serverTimestamp()

            try await ref.setData(data, merge: true)
        }

        print("✅ Seeded in-person events to /events")
    }
}
