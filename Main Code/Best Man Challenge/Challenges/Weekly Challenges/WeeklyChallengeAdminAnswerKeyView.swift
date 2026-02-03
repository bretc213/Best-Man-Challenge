//
//  WeeklyChallengeAdminAnswerKeyView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/8/26.
//


//
//  WeeklyChallengeAdminAnswerKeyView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/8/26.
//

import SwiftUI

struct WeeklyChallengeAdminAnswerKeyView: View {
    let challenge: WeeklyChallenge
    @StateObject private var adminStore = WeeklyChallengeAdminStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Answer Key (Admin)")
                .font(.title2.bold())

            Text("Tap Over/Under for each prop to set the correct answer.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if adminStore.isSaving {
                ProgressView("Saving...")
                    .padding(.top, 6)
            }

            if let err = adminStore.errorMessage {
                Text("Couldn’t save: \(err)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let questions = challenge.quiz?.questions, !questions.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(questions) { q in
                            adminQuestionCard(q)
                        }
                    }
                    .padding(.top, 4)
                }
            } else {
                Text("No quiz questions found.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private func adminQuestionCard(_ q: WeeklyQuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(q.prompt)
                .font(.headline)

            // Over/Under buttons
            HStack(spacing: 10) {
                adminPickButton(question: q, idx: 0)
                adminPickButton(question: q, idx: 1)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func adminPickButton(question q: WeeklyQuizQuestion, idx: Int) -> some View {
        let isSelected = (q.correct_index == idx)

        return Button {
            Task {
                await adminStore.setCorrectIndex(
                    challengeId: challenge.id,
                    questionId: q.id,
                    correctIndex: idx
                )
            }
        } label: {
            HStack {
                Text(q.options[idx])
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.green.opacity(0.18) : Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .disabled(adminStore.isSaving)
    }
}
