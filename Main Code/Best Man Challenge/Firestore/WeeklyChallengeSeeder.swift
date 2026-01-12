//
//  WeeklyChallengeSeeder.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 12/25/25.
//
//  NOTE:
//  - Firestore does NOT like nested arrays (e.g., [[Int]]), so Sudoku grid is stored FLAT [Int].
//  - Because some 4×4 puzzles can have multiple valid solutions, we DO NOT store a single "solution".
//    Instead, the app should validate the user’s entry with MiniSudokuValidator.isValidCompleted4x4(...)
//

import Foundation
import FirebaseFirestore

struct WeeklyChallengeSeeder {

    /// Seeds/updates one test weekly challenge doc (Sudoku → unlock key → cipher → riddle).
    /// Safe to re-run: uses merge:true
    static func seedTestCipherRiddleWeek() async throws {
        let db = Firestore.firestore()

        // Pick the doc you want to update for testing:
        let docId = "2026_w01"
        let ref = db.collection("weekly_challenges").document(docId)

        // 4×4 Sudoku (flat array, row-major). 0 = empty.
        let sudokuGrid: [Int] = [
            1, 0, 0, 4,
            0, 4, 1, 0,
            0, 1, 4, 0,
            4, 0, 0, 1
        ]

        // Unlock key derived from middle 2×2 box sum in our example:
        // Middle 2×2 box values end up being [4,1;1,4] in a valid solution => sum = 10.
        // You can keep this rule as “the puzzle unlocks a shift of 10”.
        let unlockShift = 10

        // ✅ Correct ciphertext for:
        // "WHAT HAS A RING, BUT HAS NO FINGER"
        // Encrypted with Caesar +10; so decode by shifting BACK 10.
        let ciphertext = "GRKD RKC K BSXQ, LED RKC XY PSXQOB"

        let data: [String: Any] = [
            "week": 1,
            "title": "Week 1: Puzzle Lock",
            "description": "Solve the mini Sudoku to unlock the decoding key. Then decode the message and answer the riddle.",
            "type": "riddle",
            "is_active": true,

            // Layer 1: Mini Sudoku
            "puzzle": [
                "type": "mini_sudoku_4x4",
                "size": 4,
                "grid": sudokuGrid,

                // store the “unlock rule” + value (what you show once solved)
                "unlock_rule": "middle_box_sum",
                "unlock_value": unlockShift,
                "unlock_text": "Key = \(unlockShift) (shift letters back \(unlockShift))"
            ],

            // Layer 2: Cipher
            "cipher": [
                "type": "caesar",
                "ciphertext": ciphertext,
                "direction": "back",
                "shift": unlockShift
            ],

            // Layer 3: Answer
            // (You can remove this later, or only reveal after endDate)
            "answer": "telephone"
        ]

        try await ref.setData(data, merge: true)
        print("✅ Seeded test weekly challenge into weekly_challenges/\(docId)")
    }
}
