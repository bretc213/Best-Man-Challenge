//
//  AdminFinalizeTestView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/23/26.
//


import SwiftUI

struct AdminFinalizeTestView: View {
    @State private var message: String = ""
    @State private var running = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Admin Finalize Test")
                .font(.title2).bold()

            Button {
                Task {
                    await runFinalizeTest()
                }
            } label: {
                if running {
                    ProgressView()
                } else {
                    Text("Run Finalize (test)")
                }
            }
            .buttonStyle(.borderedProminent)

            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding()
    }

    func runFinalizeTest() async {
        running = true
        message = ""
        do {
            // Replace with real challengeId and real scores map when ready
            let challengeId = "test_challenge_001"

            // Example scores: change to real mapping (playerId -> score)
            let scores: [String: Double] = [
                "anthonyc": 38,
                "dannyo": 38,    // tie with anthonyc
                "isaiahs": 30,
                "jakeo": 20,
                "joeg": 20       // tie with jakeo
                // ... add remaining participants
            ]

            let finalizer = ChallengePointsFinalizer()
            try await finalizer.finalizeChallenge(
                challengeId: challengeId,
                scoresByPlayer: scores,
                multiplier: 1,
                higherIsBetter: true
            )

            message = "Finalize complete. Check point_awards and players.total_points."
        } catch {
            message = "Failed: \(error.localizedDescription)"
        }
        running = false
    }
}
