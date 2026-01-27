//
//  AsyncWait.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/24/26.
//


import Foundation

enum AsyncWait {
    /// Polls until condition returns true or timeout hits.
    static func until(
        timeoutSeconds: Double = 8,
        pollEveryMillis: UInt64 = 150,
        condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: pollEveryMillis * 1_000_000)
        }
        throw NSError(
            domain: "AsyncWait",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for data."]
        )
    }
}
