import Foundation

/// All final backyard challenge results, hardcoded.
/// Points are official and will not change. Bret is marked as host (no tournament award).
/// Kyle's points are adjusted per outside rule (did not attend Alt Shot).
enum BackyardHardcodedResults {

    // MARK: - Helper

    private static func row(_ id: String, _ name: String, _ pts: Int) -> BackyardStandingRow {
        BackyardStandingRow(playerId: id, displayName: name, rawScore: Double(pts), points: pts, thru: nil)
    }

    // MARK: - Overall

    static func overallRows() -> [BackyardStandingRow] {
        [
            row("mitch",     "Mitch",          139),
            row("bret",      "Bret",           106),  // Host — no tournament award
            row("joel",      "Joel",           102),
            row("isaiah",    "Isaiah",          90),
            row("danny",     "Danny",           84),
            row("matt_c",    "Matthew Carlos",  75),
            row("valentino", "Valentino",        75),
            row("matt_p",    "Matthew Page",    74),
            row("ronnie",    "Ronnie",           40),
            row("jake",      "Jake",             33),
            row("kyle",      "Kyle",             28),
            row("anthony",   "Anthony",          27),
        ]
    }

    // MARK: - Bucket Golf

    static func golf18Rows() -> [BackyardStandingRow] {
        [
            row("isaiah",    "Isaiah",          45),  // 1st  MK×3
            row("mitch",     "Mitch",           36),  // 2nd
            row("valentino", "Valentino",        30),  // 3rd
            row("bret",      "Bret",            24),  // 4th (tie)
            row("joel",      "Joel",            24),  // 4th (tie)
            row("danny",     "Danny",           18),  // 6th
            row("matt_p",    "Matthew Page",    15),  // 7th
            row("matt_c",    "Matthew Carlos",  12),  // 8th
            row("anthony",   "Anthony",          9),  // 9th (tie)
            row("ronnie",    "Ronnie",           9),  // 9th (tie)
            row("jake",      "Jake",             3),  // 11th
            row("kyle",      "Kyle",             0),  // 12th
        ]
    }

    static func closestToPinRows() -> [BackyardStandingRow] {
        [
            row("matt_p",    "Matthew Page",    15),  // 1st  MK×1
            row("isaiah",    "Isaiah",          12),  // 2nd
            row("danny",     "Danny",           10),  // 3rd
            row("valentino", "Valentino",         8),  // 4th
            row("bret",      "Bret",             7),  // 5th
            row("matt_c",    "Matthew Carlos",   6),  // 6th
            row("mitch",     "Mitch",            5),  // 7th
            row("ronnie",    "Ronnie",           4),  // 8th
            row("jake",      "Jake",             3),  // 9th
            row("joel",      "Joel",             2),  // 10th
            row("anthony",   "Anthony",          1),  // 11th
            row("kyle",      "Kyle",             0),  // 12th
        ]
    }

    static func altShotRows() -> [BackyardStandingRow] {
        [
            row("mitch",     "Mitch",           10),  // 1st (tie)
            row("kyle",      "Kyle",            10),  // 1st (tie)
            row("joel",      "Joel",             8),  // 3rd (tie)
            row("matt_c",    "Matthew Carlos",   8),  // 3rd (tie)
            row("valentino", "Valentino",         5),  // 5th (tie)
            row("anthony",   "Anthony",          5),  // 5th (tie)
            row("jake",      "Jake",             5),  // 5th (tie)
            row("isaiah",    "Isaiah",           5),  // 5th (tie)
            row("bret",      "Bret",             2),  // 9th (tie)
            row("ronnie",    "Ronnie",           2),  // 9th (tie)
            row("danny",     "Danny",            1),  // 11th (tie)
            row("matt_p",    "Matthew Page",     1),  // 11th (tie)
        ]
    }

    static func golfTotalRows() -> [BackyardStandingRow] {
        [
            row("isaiah",    "Isaiah",          62),
            row("mitch",     "Mitch",           51),
            row("valentino", "Valentino",        43),
            row("joel",      "Joel",            34),
            row("bret",      "Bret",            33),
            row("matt_p",    "Matthew Page",    31),
            row("danny",     "Danny",           29),
            row("matt_c",    "Matthew Carlos",  26),
            row("anthony",   "Anthony",         15),
            row("ronnie",    "Ronnie",          15),
            row("jake",      "Jake",            11),
            row("kyle",      "Kyle",            10),
        ]
    }

    // MARK: - Cornhole

    static func dekaRows() -> [BackyardStandingRow] {
        [
            row("joel",      "Joel",            15),  // 1st  MK×1
            row("danny",     "Danny",           12),  // 2nd
            row("bret",      "Bret",            10),  // 3rd
            row("mitch",     "Mitch",            8),  // 4th
            row("matt_p",    "Matthew Page",     7),  // 5th
            row("isaiah",    "Isaiah",           6),  // 6th
            row("ronnie",    "Ronnie",           5),  // 7th
            row("valentino", "Valentino",         4),  // 8th
            row("matt_c",    "Matthew Carlos",   3),  // 9th
            row("anthony",   "Anthony",          2),  // 10th
            row("jake",      "Jake",             1),  // 11th
            row("kyle",      "Kyle",             0),  // 12th
        ]
    }

    static func cornholeSinglesRows() -> [BackyardStandingRow] {
        [
            row("bret",      "Bret",            30),  // Gold 1st   MK×2
            row("joel",      "Joel",            24),  // Gold 2nd
            row("mitch",     "Mitch",           20),  // Gold 3rd
            row("danny",     "Danny",           16),  // Gold 4th
            row("matt_p",    "Matthew Page",    14),  // Silver 1st
            row("valentino", "Valentino",        12),  // Silver 2nd
            row("isaiah",    "Isaiah",          10),  // Silver 3rd
            row("ronnie",    "Ronnie",           8),  // Silver 4th
            row("matt_c",    "Matthew Carlos",   6),  // Bronze 1st
            row("anthony",   "Anthony",          4),  // Bronze 2nd
            row("jake",      "Jake",             2),  // Bronze 3rd
            row("kyle",      "Kyle",             0),  // Bronze 4th
        ]
    }

    static func cornholeTotalRows() -> [BackyardStandingRow] {
        [
            row("bret",      "Bret",            40),
            row("joel",      "Joel",            39),
            row("danny",     "Danny",           28),
            row("mitch",     "Mitch",           28),
            row("matt_p",    "Matthew Page",    21),
            row("isaiah",    "Isaiah",          16),
            row("valentino", "Valentino",        16),
            row("ronnie",    "Ronnie",          13),
            row("matt_c",    "Matthew Carlos",   9),
            row("anthony",   "Anthony",          6),
            row("jake",      "Jake",             3),
            row("kyle",      "Kyle",             0),
        ]
    }

    // MARK: - Ladder Ball

    static func ladderBallRows() -> [BackyardStandingRow] {
        [
            row("mitch",     "Mitch",           30),
            row("matt_c",    "Matthew Carlos",  24),
            row("joel",      "Joel",            20),
            row("jake",      "Jake",            16),
            row("bret",      "Bret",            13),
            row("matt_p",    "Matthew Page",     9),
            row("ronnie",    "Ronnie",           9),
            row("isaiah",    "Isaiah",           3),
            row("danny",     "Danny",            3),
            row("valentino", "Valentino",         3),
            row("anthony",   "Anthony",          3),
            row("kyle",      "Kyle",             0),
        ]
    }

    // MARK: - QB54

    static func qb54Rows() -> [BackyardStandingRow] {
        [
            row("mitch",     "Mitch",           30),
            row("danny",     "Danny",           24),
            row("bret",      "Bret",            20),
            row("matt_c",    "Matthew Carlos",  16),
            row("valentino", "Valentino",        13),
            row("matt_p",    "Matthew Page",    13),
            row("isaiah",    "Isaiah",           9),
            row("joel",      "Joel",             9),
            row("ronnie",    "Ronnie",           3),
            row("jake",      "Jake",             3),
            row("anthony",   "Anthony",          3),
            row("kyle",      "Kyle",             0),
        ]
    }
}
