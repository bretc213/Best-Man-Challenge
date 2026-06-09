//
//  SoftballChallengeSeeder2026.swift
//  Best Man Challenge
//
/*
import Foundation
import FirebaseFirestore

enum SoftballChallengeSeeder2026 {

    static let didSeedKey = "didSeed_softball_wcws_2026_v5_clean_decode_safe"
    static let challengeId = "wcws_2026"

    static func seedIfNeeded() async {
        if UserDefaults.standard.bool(forKey: didSeedKey) {
            print("ℹ️ WCWS 2026 already seeded.")
            return
        }

        do {
            try await seed()
            UserDefaults.standard.set(true, forKey: didSeedKey)
            print("✅ WCWS 2026 seeded successfully.")
        } catch {
            print("❌ WCWS 2026 seed failed:", error.localizedDescription)
        }
    }

    static func seed() async throws {
        let db = Firestore.firestore()

        let regionals: [[String: Any]] = [
            regional(id: "regional_01", nationalSeed: 1, host: "Alabama", location: "Tuscaloosa Regional", teams: [
                team(id: "alabama", name: "Alabama", seed: 1),
                team(id: "southeastern_louisiana", name: "Southeastern Louisiana", seed: 2),
                team(id: "belmont", name: "Belmont", seed: 3),
                team(id: "usc_upstate", name: "USC Upstate", seed: 4)
            ]),
            regional(id: "regional_02", nationalSeed: 2, host: "Texas", location: "Austin Regional", teams: [
                team(id: "texas", name: "Texas", seed: 1),
                team(id: "wisconsin", name: "Wisconsin", seed: 2),
                team(id: "baylor", name: "Baylor", seed: 3),
                team(id: "wagner", name: "Wagner", seed: 4)
            ]),
            regional(id: "regional_03", nationalSeed: 3, host: "Oklahoma", location: "Norman Regional", teams: [
                team(id: "oklahoma", name: "Oklahoma", seed: 1),
                team(id: "kansas", name: "Kansas", seed: 2),
                team(id: "michigan", name: "Michigan", seed: 3),
                team(id: "binghamton", name: "Binghamton", seed: 4)
            ]),
            regional(id: "regional_04", nationalSeed: 4, host: "Nebraska", location: "Lincoln Regional", teams: [
                team(id: "nebraska", name: "Nebraska", seed: 1),
                team(id: "louisville", name: "Louisville", seed: 2),
                team(id: "grand_canyon", name: "Grand Canyon", seed: 3),
                team(id: "south_dakota", name: "South Dakota", seed: 4)
            ]),
            regional(id: "regional_05", nationalSeed: 5, host: "Arkansas", location: "Fayetteville Regional", teams: [
                team(id: "arkansas", name: "Arkansas", seed: 1),
                team(id: "washington", name: "Washington", seed: 2),
                team(id: "south_florida", name: "South Florida", seed: 3),
                team(id: "fordham", name: "Fordham", seed: 4)
            ]),
            regional(id: "regional_06", nationalSeed: 6, host: "Florida", location: "Gainesville Regional", teams: [
                team(id: "florida", name: "Florida", seed: 1),
                team(id: "texas_state", name: "Texas State", seed: 2),
                team(id: "georgia_tech", name: "Georgia Tech", seed: 3),
                team(id: "florida_am", name: "Florida A&M", seed: 4)
            ]),
            regional(id: "regional_07", nationalSeed: 7, host: "Tennessee", location: "Knoxville Regional", teams: [
                team(id: "tennessee", name: "Tennessee", seed: 1),
                team(id: "virginia", name: "Virginia", seed: 2),
                team(id: "indiana", name: "Indiana", seed: 3),
                team(id: "northern_kentucky", name: "Northern Kentucky", seed: 4)
            ]),
            regional(id: "regional_08", nationalSeed: 8, host: "UCLA", location: "Los Angeles Regional", teams: [
                team(id: "ucla", name: "UCLA", seed: 1),
                team(id: "south_carolina", name: "South Carolina", seed: 2),
                team(id: "cal_state_fullerton", name: "Cal State Fullerton", seed: 3),
                team(id: "california_baptist", name: "California Baptist", seed: 4)
            ]),
            regional(id: "regional_09", nationalSeed: 9, host: "Florida State", location: "Tallahassee Regional", teams: [
                team(id: "florida_state", name: "Florida State", seed: 1),
                team(id: "ucf", name: "UCF", seed: 2),
                team(id: "jax_state", name: "Jax State", seed: 3),
                team(id: "stetson", name: "Stetson", seed: 4)
            ]),
            regional(id: "regional_10", nationalSeed: 10, host: "Georgia", location: "Athens Regional", teams: [
                team(id: "georgia", name: "Georgia", seed: 1),
                team(id: "clemson", name: "Clemson", seed: 2),
                team(id: "unc_greensboro", name: "UNC Greensboro", seed: 3),
                team(id: "charleston", name: "Charleston", seed: 4)
            ]),
            regional(id: "regional_11", nationalSeed: 11, host: "Texas Tech", location: "Lubbock Regional", teams: [
                team(id: "texas_tech", name: "Texas Tech", seed: 1),
                team(id: "ole_miss", name: "Ole Miss", seed: 2),
                team(id: "boston_u", name: "Boston U", seed: 3),
                team(id: "marist", name: "Marist", seed: 4)
            ]),
            regional(id: "regional_12", nationalSeed: 12, host: "Duke", location: "Durham Regional", teams: [
                team(id: "duke", name: "Duke", seed: 1),
                team(id: "arizona", name: "Arizona", seed: 2),
                team(id: "marshall", name: "Marshall", seed: 3),
                team(id: "howard", name: "Howard", seed: 4)
            ]),
            regional(id: "regional_13", nationalSeed: 13, host: "Oklahoma State", location: "Stillwater Regional", teams: [
                team(id: "oklahoma_state", name: "Oklahoma State", seed: 1),
                team(id: "stanford", name: "Stanford", seed: 2),
                team(id: "princeton", name: "Princeton", seed: 3),
                team(id: "eastern_illinois", name: "Eastern Illinois", seed: 4)
            ]),
            regional(id: "regional_14", nationalSeed: 14, host: "Oregon", location: "Eugene Regional", teams: [
                team(id: "oregon", name: "Oregon", seed: 1),
                team(id: "mississippi_state", name: "Mississippi State", seed: 2),
                team(id: "saint_marys", name: "Saint Mary’s", seed: 3),
                team(id: "idaho_state", name: "Idaho State", seed: 4)
            ]),
            regional(id: "regional_15", nationalSeed: 15, host: "Texas A&M", location: "College Station Regional", teams: [
                team(id: "texas_am", name: "Texas A&M", seed: 1),
                team(id: "arizona_state", name: "Arizona State", seed: 2),
                team(id: "mcneese", name: "McNeese", seed: 3),
                team(id: "uconn", name: "UConn", seed: 4)
            ]),
            regional(id: "regional_16", nationalSeed: 16, host: "LSU", location: "Baton Rouge Regional", teams: [
                team(id: "lsu", name: "LSU", seed: 1),
                team(id: "virginia_tech", name: "Virginia Tech", seed: 2),
                team(id: "south_alabama", name: "South Alabama", seed: 3),
                team(id: "akron", name: "Akron", seed: 4)
            ])
        ]

        let bracketRef = db.collection("softball_brackets").document(challengeId)

        let bracketData: [String: Any] = [
            "id": challengeId,
            "challengeId": challengeId,
            "title": "2026 WCWS Bracket",
            "subtitle": "NCAA Softball Tournament",
            "status": "live",
            "regionalPoints": 2,
            "superRegionalPoints": 4,
            "finalistPoints": 8,
            "championPoints": 16,
            "regionals": regionals,
            "results": [
                "regionalWinners": [:],
                "superRegionalWinners": [:],
                "finalists": []
            ],
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await bracketRef.setData(bracketData, merge: false)

        for regionalData in regionals {
            guard let id = regionalData["id"] as? String else { continue }
            try await bracketRef
                .collection("regionals")
                .document(id)
                .setData(regionalData, merge: false)
        }

        let superRegionals: [[String: Any]] = [
            superRegional(id: "super_01_16", seedA: 1, seedB: 16, regionalA: "regional_01", regionalB: "regional_16"),
            superRegional(id: "super_08_09", seedA: 8, seedB: 9, regionalA: "regional_08", regionalB: "regional_09"),
            superRegional(id: "super_05_12", seedA: 5, seedB: 12, regionalA: "regional_05", regionalB: "regional_12"),
            superRegional(id: "super_04_13", seedA: 4, seedB: 13, regionalA: "regional_04", regionalB: "regional_13"),
            superRegional(id: "super_03_14", seedA: 3, seedB: 14, regionalA: "regional_03", regionalB: "regional_14"),
            superRegional(id: "super_06_11", seedA: 6, seedB: 11, regionalA: "regional_06", regionalB: "regional_11"),
            superRegional(id: "super_07_10", seedA: 7, seedB: 10, regionalA: "regional_07", regionalB: "regional_10"),
            superRegional(id: "super_02_15", seedA: 2, seedB: 15, regionalA: "regional_02", regionalB: "regional_15")
        ]

        for superData in superRegionals {
            guard let id = superData["id"] as? String else { continue }
            try await bracketRef
                .collection("super_regionals")
                .document(id)
                .setData(superData, merge: false)
        }

        try await db.collection("at_home_games").document(challengeId).setData([
            "title": "WCWS Bracket",
            "assetImage": "wcws",
            "route": "wcws_softball",
            "state": "live",
            "sortOrder": 50,
            "gameType": "softball_bracket",
            "gameRefId": challengeId,
            "challengeId": challengeId,
            "startsAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    private static func regional(
        id: String,
        nationalSeed: Int,
        host: String,
        location: String,
        teams: [[String: Any]]
    ) -> [String: Any] {
        [
            "id": id,
            "nationalSeed": nationalSeed,
            "host": host,
            "location": location,
            "teams": teams
        ]
    }

    private static func team(id: String, name: String, seed: Int) -> [String: Any] {
        [
            "id": id,
            "teamId": id,
            "name": name,
            "displayName": name,
            "seed": seed,
            "regionalSeed": seed
        ]
    }

    private static func superRegional(
        id: String,
        seedA: Int,
        seedB: Int,
        regionalA: String,
        regionalB: String
    ) -> [String: Any] {
        [
            "id": id,
            "seedA": seedA,
            "seedB": seedB,
            "regionalA": regionalA,
            "regionalB": regionalB
        ]
    }
}
 */
