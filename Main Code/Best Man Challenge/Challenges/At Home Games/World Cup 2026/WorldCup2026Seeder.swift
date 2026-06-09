//
//  WorldCup2026Seeder.swift
//  Best Man Challenge
//
//  Seeds all 48 teams to Firestore.
//  Run once from Admin tools or a debug button.
//
//  Groups verified against the official 2026 FIFA World Cup draw (Wikipedia / FIFA.com).

import SwiftUI
import Foundation
import FirebaseFirestore

@MainActor
final class WorldCup2026Seeder {

    static let bracketId = "world_cup_2026"

    // MARK: - 48 Teams (FIFA 2026 World Cup Draw)

    static let teams: [(id: String, name: String, abbr: String, group: String, flag: String, sortOrder: Int)] = [
        // GROUP A
        ("MEX",  "Mexico",           "MEX",  "A", "🇲🇽", 1),
        ("RSA",  "South Africa",     "RSA",  "A", "🇿🇦", 2),
        ("KOR",  "South Korea",      "KOR",  "A", "🇰🇷", 3),
        ("CZE",  "Czechia",          "CZE",  "A", "🇨🇿", 4),

        // GROUP B
        ("CAN",  "Canada",           "CAN",  "B", "🇨🇦", 1),
        ("BIH",  "Bosnia-Herz.",     "BIH",  "B", "🇧🇦", 2),
        ("QAT",  "Qatar",            "QAT",  "B", "🇶🇦", 3),
        ("SUI",  "Switzerland",      "SUI",  "B", "🇨🇭", 4),

        // GROUP C
        ("BRA",  "Brazil",           "BRA",  "C", "🇧🇷", 1),
        ("MAR",  "Morocco",          "MAR",  "C", "🇲🇦", 2),
        ("HAI",  "Haiti",            "HAI",  "C", "🇭🇹", 3),
        ("SCO",  "Scotland",         "SCO",  "C", "🏴󠁧󠁢󠁳󠁣󠁴󠁿", 4),

        // GROUP D
        ("USA",  "United States",    "USA",  "D", "🇺🇸", 1),
        ("PAR",  "Paraguay",         "PAR",  "D", "🇵🇾", 2),
        ("AUS",  "Australia",        "AUS",  "D", "🇦🇺", 3),
        ("TUR",  "Türkiye",          "TUR",  "D", "🇹🇷", 4),

        // GROUP E
        ("GER",  "Germany",          "GER",  "E", "🇩🇪", 1),
        ("CUW",  "Curaçao",          "CUW",  "E", "🇨🇼", 2),
        ("CIV",  "Ivory Coast",      "CIV",  "E", "🇨🇮", 3),
        ("ECU",  "Ecuador",          "ECU",  "E", "🇪🇨", 4),

        // GROUP F
        ("NED",  "Netherlands",      "NED",  "F", "🇳🇱", 1),
        ("JPN",  "Japan",            "JPN",  "F", "🇯🇵", 2),
        ("SWE",  "Sweden",           "SWE",  "F", "🇸🇪", 3),
        ("TUN",  "Tunisia",          "TUN",  "F", "🇹🇳", 4),

        // GROUP G
        ("BEL",  "Belgium",          "BEL",  "G", "🇧🇪", 1),
        ("EGY",  "Egypt",            "EGY",  "G", "🇪🇬", 2),
        ("IRN",  "Iran",             "IRN",  "G", "🇮🇷", 3),
        ("NZL",  "New Zealand",      "NZL",  "G", "🇳🇿", 4),

        // GROUP H
        ("ESP",  "Spain",            "ESP",  "H", "🇪🇸", 1),
        ("CPV",  "Cape Verde",       "CPV",  "H", "🇨🇻", 2),
        ("KSA",  "Saudi Arabia",     "KSA",  "H", "🇸🇦", 3),
        ("URU",  "Uruguay",          "URU",  "H", "🇺🇾", 4),

        // GROUP I
        ("FRA",  "France",           "FRA",  "I", "🇫🇷", 1),
        ("SEN",  "Senegal",          "SEN",  "I", "🇸🇳", 2),
        ("IRQ",  "Iraq",             "IRQ",  "I", "🇮🇶", 3),
        ("NOR",  "Norway",           "NOR",  "I", "🇳🇴", 4),

        // GROUP J
        ("ARG",  "Argentina",        "ARG",  "J", "🇦🇷", 1),
        ("ALG",  "Algeria",          "ALG",  "J", "🇩🇿", 2),
        ("AUT",  "Austria",          "AUT",  "J", "🇦🇹", 3),
        ("JOR",  "Jordan",           "JOR",  "J", "🇯🇴", 4),

        // GROUP K
        ("POR",  "Portugal",         "POR",  "K", "🇵🇹", 1),
        ("COD",  "DR Congo",         "COD",  "K", "🇨🇩", 2),
        ("UZB",  "Uzbekistan",       "UZB",  "K", "🇺🇿", 3),
        ("COL",  "Colombia",         "COL",  "K", "🇨🇴", 4),

        // GROUP L
        ("ENG",  "England",          "ENG",  "L", "🏴󠁧󠁢󠁥󠁮󠁧󠁿", 1),
        ("CRO",  "Croatia",          "CRO",  "L", "🇭🇷", 2),
        ("GHA",  "Ghana",            "GHA",  "L", "🇬🇭", 3),
        ("PAN",  "Panama",           "PAN",  "L", "🇵🇦", 4),
    ]

    // MARK: - Seed

    static func seedTeams() async throws {
        let db = Firestore.firestore()
        let bracketRef = db.collection("brackets").document(bracketId)
        let collection = bracketRef.collection("teams")

        // Step 1: Delete all existing team docs first
        let existing = try await collection.getDocuments()
        if !existing.documents.isEmpty {
            var deleteBatch = db.batch()
            for (i, doc) in existing.documents.enumerated() {
                deleteBatch.deleteDocument(doc.reference)
                if (i + 1) % 400 == 0 {
                    try await deleteBatch.commit()
                    deleteBatch = db.batch()
                }
            }
            try await deleteBatch.commit()
        }

        // Step 2: Update bracket meta doc
        try await bracketRef.setData([
            "title": "2026 FIFA World Cup",
            "status": "open",
            "isLocked": false,
            "createdAt": FieldValue.serverTimestamp()
        ], merge: true)

        // Step 3: Write the 48 correct teams
        var batch = db.batch()
        for (i, team) in teams.enumerated() {
            let ref = collection.document(team.id)
            batch.setData([
                "name":      team.name,
                "abbr":      team.abbr,
                "group":     team.group,
                "flag":      team.flag,
                "sortOrder": team.sortOrder
            ], forDocument: ref)

            if (i + 1) % 400 == 0 {
                try await batch.commit()
                batch = db.batch()
            }
        }
        try await batch.commit()
        print("✅ WorldCup2026Seeder: \(teams.count) teams seeded to brackets/\(bracketId)/teams")
    }
}

// MARK: - Admin Seed Button (add to AdminTools or a debug view)

struct WorldCup2026SeedButton: View {
    @State private var isSeeding = false
    @State private var result = ""

    var body: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    isSeeding = true
                    do {
                        try await WorldCup2026Seeder.seedTeams()
                        result = "✅ Seeded \(WorldCup2026Seeder.teams.count) teams"
                    } catch {
                        result = "❌ \(error.localizedDescription)"
                    }
                    isSeeding = false
                }
            } label: {
                Label(isSeeding ? "Seeding…" : "Seed WC 2026 Teams", systemImage: "arrow.down.circle")
            }
            .disabled(isSeeding)

            if !result.isEmpty {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
