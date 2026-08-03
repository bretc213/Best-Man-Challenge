//
//  WeeklyChallengeSeeder2026W31.swift
//  Best Man Challenge
//
//  Week 31: The Midsummer Cipher
//  Dates: Aug 3–9, 2026
//  Mechanic: solve a 4×4 mini-sudoku → unlock the Caesar shift key →
//            decode the message → answer the riddle.  (10 pts)
//
//  Moved here from W30 (cipher idea) — replaces the prior Triple Wordle content.
//  Uses setData WITHOUT merge so it fully overwrites any earlier W31 doc.
//
//  Puzzle content is verified:
//    Sudoku givens have a UNIQUE solution; the center 2×2 (1,2,4,3) sums to 10 → shift key.
//    Ciphertext "GRKD RKC K BSXQ LED XY PSXQOB" shifted back 10 = "WHAT HAS A RING BUT NO FINGER".
//    Answer: TELEPHONE.
//

import Foundation
import FirebaseFirestore

enum WeeklyChallengeSeeder2026W31 {

    static func seedIfNeeded() async {
        let db = Firestore.firestore()
        let challengeId = "2026_w31"
        let ref = db.collection("weekly_challenges").document(challengeId)

        do {
            let snap = try await ref.getDocument()

            // Skip only once the full (3-stage, scored) Cipher content is in place.
            // Presence of accepted_answers marks the latest version — re-seeds an
            // older Cipher/Triple-Wordle doc, then skips on subsequent launches.
            if snap.exists,
               let title = snap.data()?["title"] as? String,
               title.contains("Cipher"),
               snap.data()?["accepted_answers"] != nil {
                print("ℹ️ W31 Midsummer Cipher already seeded — skipping.")
                return
            }

            // Full replace (no merge) — clears any prior Triple Wordle content at this doc.
            try await ref.setData(buildData())
            print("✅ W31 Midsummer Cipher seeded.")
        } catch {
            print("❌ W31 seedIfNeeded failed:", error.localizedDescription)
        }
    }

    private static func buildData() -> [String: Any] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 3
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let startDate = cal.date(from: comps)!
        comps.day = 10                     // end = Aug 10 (Mon)
        let endDate = cal.date(from: comps)!

        // 4×4 mini-sudoku givens (flat, row-major, 0 = empty). Unique solution.
        //   2 · · 1
        //   · 1 2 ·
        //   · 4 3 ·
        //   3 · · 4
        let sudokuGrid: [Int] = [
            2, 0, 0, 1,
            0, 1, 2, 0,
            0, 4, 3, 0,
            3, 0, 0, 4
        ]
        let unlockShift = 10   // center 2×2 of the unique solution sums to 10

        return [
            "week": 31,
            "weekInt": 31,
            "title": "Week 31: The Midsummer Cipher",
            "description": "Three layers, one answer. Solve the mini-sudoku to unlock the decoding key, use it to crack the secret message, then answer the riddle it reveals.",
            "type": "riddle",
            "game_format": "cipher",

            "is_active": false,
            "is_finalized": false,
            "finalized_at": NSNull(),

            "max_points": 10,
            "winner_bonus": 0,
            "winner_bonuses_applied": false,
            "winners": [],

            "start_date": Timestamp(date: startDate),
            "end_date": Timestamp(date: endDate),

            // Layer 1 — Mini Sudoku
            "puzzle": [
                "type": "mini_sudoku_4x4",
                "size": 4,
                "grid": sudokuGrid,
                "unlock_rule": "center_box_sum",
                "unlock_value": unlockShift,
                "unlock_text": "Key = \(unlockShift) (shift each letter back \(unlockShift))"
            ],

            // Layer 2 — Caesar cipher
            "cipher": [
                "type": "caesar",
                "ciphertext": "GRKD RKC K BSXQ LED XY PSXQOB",
                "direction": "back",
                "shift": unlockShift
            ],

            // Layer 3 — Riddle answer (final stage). Both accepted.
            "answer": "TELEPHONE",
            "accepted_answers": ["TELEPHONE", "PHONE"],

            "updated_at": FieldValue.serverTimestamp()
        ]
    }
}
