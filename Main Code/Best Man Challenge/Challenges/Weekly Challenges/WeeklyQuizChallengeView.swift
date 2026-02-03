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
    let isLocked: Bool
    let onSubmit: (_ answers: [String: Int], _ score: Int, _ maxScore: Int) async throws -> Void

    // ✅ THIS IS THE FIX
    // Default value makes old call sites compile
    init(
        challenge: WeeklyChallenge,
        lastSubmission: WeeklyChallengeSubmission?,
        isLocked: Bool = false,
        onSubmit: @escaping (_ answers: [String: Int], _ score: Int, _ maxScore: Int) async throws -> Void
    ) {
        self.challenge = challenge
        self.lastSubmission = lastSubmission
        self.isLocked = isLocked
        self.onSubmit = onSubmit
    }

    @State private var selected: [String: Int] = [:]
    @State private var error: String?
    @State private var isSubmitting = false
    @State private var didAutoSubmit = false

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

                    if isLocked {
                        Text("Time expired — answers are locked.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(questions) { q in
                        quizQuestionCard(q)
                            .opacity(isLocked ? 0.7 : 1)
                    }

                    if let error {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }

                    Button {
                        Task { await submitQuiz(questions: questions, isAuto: false) }
                    } label: {
                        Text(isSubmitting ? "Submitting..." : "Submit Quiz")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting || isLocked || selected.count < questions.count)
                }
                .padding()
            }
            .onReceive(NotificationCenter.default.publisher(for: .weeklyQuizTimeExpired)) { _ in
                guard !didAutoSubmit else { return }
                didAutoSubmit = true
                Task { await submitQuiz(questions: questions, isAuto: true) }
            }

        } else {
            Text("Quiz not configured.")
                .foregroundStyle(.secondary)
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
                .onTapGesture {
                    guard !isLocked else { return }
                    guard lastSubmission == nil else { return }
                    guard !isSubmitting else { return }
                    selected[q.id] = idx
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func submitQuiz(questions: [WeeklyQuizQuestion], isAuto: Bool) async {
        guard lastSubmission == nil else { return }
        guard !isSubmitting else { return }

        if !isAuto && selected.count < questions.count {
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let pointsPerCorrect = challenge.quiz?.points_per_correct ?? 1
        var score = 0

        for q in questions {
            guard let correct = q.correct_index else { continue }
            if selected[q.id] == correct {
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
