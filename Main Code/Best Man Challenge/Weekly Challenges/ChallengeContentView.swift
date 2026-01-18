//
//  ChallengeContentView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 5/26/25.
//  Updated on 12/25/25
//


import SwiftUI

struct ChallengeContentView: View {
    
    @EnvironmentObject var challengeManager: WeeklyChallengeManager

    let challenge: WeeklyChallenge
    let lastSubmission: WeeklyChallengeSubmission?

    let onSubmitRiddle: (String, Bool) async throws -> Void
    let onSubmitQuiz: (_ answers: [String: Int], _ score: Int, _ maxScore: Int) async throws -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Header (shared)
            Text(challenge.title)
                .font(.title2)
                .bold()

            Text(challenge.description)
                .foregroundColor(.secondary)

            Divider()

            switch challenge.type {

            case .quiz:
                WeeklyQuizChallengeView(
                    challenge: challenge,
                    lastSubmission: challengeManager.lastSubmission,
                    onSubmit: { answers, score, maxScore in
                        try await challengeManager.submitQuiz(
                            answers: answers,
                            score: score,
                            maxScore: maxScore
                        )
                    }
                )


            case .riddle:
                RiddleChallengeView(
                    challenge: challenge,
                    lastSubmission: lastSubmission,
                    onSubmit: onSubmitRiddle
                )

            case .minesweeper:
                Text("Minesweeper mode coming soon.")
                    .foregroundColor(.secondary)

            case .creative:
                Text("Creative mode coming soon.")
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }
}
