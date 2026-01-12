//
//  MiniSudokuValidator.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 12/26/25.
//


import Foundation

enum MiniSudokuValidator {

    /// Validates a completed 4×4 mini-sudoku.
    /// - Parameter grid: flat array length 16 (row-major). Values must be 1...4 (no zeros).
    static func isValidCompleted4x4(_ grid: [Int]) -> Bool {
        guard grid.count == 16 else { return false }
        // Must be fully filled
        guard grid.allSatisfy({ (1...4).contains($0) }) else { return false }

        // Check rows
        for r in 0..<4 {
            let row = (0..<4).map { c in grid[r * 4 + c] }
            if !isSet1to4(row) { return false }
        }

        // Check cols
        for c in 0..<4 {
            let col = (0..<4).map { r in grid[r * 4 + c] }
            if !isSet1to4(col) { return false }
        }

        // Check 2×2 boxes: top-left corners at (0,0), (0,2), (2,0), (2,2)
        let boxStarts = [(0,0), (0,2), (2,0), (2,2)]
        for (sr, sc) in boxStarts {
            let box = [
                grid[(sr + 0) * 4 + (sc + 0)],
                grid[(sr + 0) * 4 + (sc + 1)],
                grid[(sr + 1) * 4 + (sc + 0)],
                grid[(sr + 1) * 4 + (sc + 1)]
            ]
            if !isSet1to4(box) { return false }
        }

        return true
    }

    private static func isSet1to4(_ vals: [Int]) -> Bool {
        return Set(vals) == Set([1,2,3,4])
    }
}
