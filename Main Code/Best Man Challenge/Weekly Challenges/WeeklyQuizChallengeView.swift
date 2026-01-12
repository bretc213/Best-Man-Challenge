//
//  WeeklyQuizChallengeView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/2/26.
//


import SwiftUI

struct WeeklyQuizChallengeView: View {
    let challenge: WeeklyChallenge
    let lastSubmission: WeeklyChallengeSubmission?
    let onSubmit: (_ answers: [String: Int], _ score: Int, _ maxScore: Int) async throws -> Void

    @State private var selected: [String: Int] = [:]
    @State private var error: String?
    @State private var isSubmitting = false

    var body: some View {
        if let score = lastSubmission?.score,
           let max = lastSubmission?.maxScore {

            VStack(alignment: .leading, spacing: 10) {
                Text("✅ You already submitted.")
                    .font(.headline)

                Text("Score: \(score)/\(max)")
                    .foregroundStyle(.secondary)

                Spacer()
            }

        } else if let questions = challenge.quiz?.questions, !questions.isEmpty {

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(questions) { q in
                        quizQuestionCard(q)
                    }

                    if let error {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }

                    Button {
                        Task { await submitQuiz(questions: questions) }
                    } label: {
                        Text(isSubmitting ? "Submitting..." : "Submit Quiz")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting || selected.count < questions.count)
                    .padding(.top, 8)
                }
                .padding(.top, 10)
            }

        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Quiz not configured.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private func quizQuestionCard(_ q: WeeklyQuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(q.prompt)
                .font(.headline)

            ForEach(q.options.indices, id: \.self) { idx in
                let isPicked = selected[q.id] == idx
                HStack {
                    Text(q.options[idx])
                    Spacer()
                    Image(systemName: isPicked ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isPicked ? .green : .secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { selected[q.id] = idx }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func submitQuiz(questions: [WeeklyQuizQuestion]) async {
        error = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let pointsPerCorrect = challenge.quiz?.points_per_correct ?? 1
        var score = 0

        for q in questions {
            if selected[q.id] == q.correct_index {
                score += pointsPerCorrect
            }
        }

        do {
            try await onSubmit(selected, score, questions.count * pointsPerCorrect)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
