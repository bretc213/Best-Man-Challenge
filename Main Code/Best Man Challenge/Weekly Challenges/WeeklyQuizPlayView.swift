//
//  WeeklyQuizPlayView.swift
//  Best Man Challenge
//

import SwiftUI

struct WeeklyQuizPlayView: View {
    let challenge: WeeklyChallenge
    @ObservedObject var manager: WeeklyChallengeManager

    @Environment(\.dismiss) private var dismiss

    @State private var selections: [String: Int] = [:]
    @State private var isSubmitting = false
    @State private var errorText: String?

    // ✅ Lock after endDate
    private var isLocked: Bool {
        Date() >= challenge.endDate
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text(challenge.title)
                    .font(.title2)
                    .bold()

                if isLocked {
                    Text("🔒 This quiz is locked.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if isPendingScoring {
                    Text("✅ Your picks will be scored after the games finish.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let questions = challenge.quiz?.questions, !questions.isEmpty {
                    ForEach(questions, id: \.id) { q in
                        questionCard(q)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        Text(isSubmitting ? "Submitting…" : (isLocked ? "Locked" : "Submit Quiz"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting || isLocked)

                } else {
                    Text("No quiz questions found for this challenge.")
                        .foregroundStyle(.secondary)
                }

                if let errorText {
                    Text(errorText)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }
            .padding()
        }
        .navigationTitle("Quiz")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isPendingScoring: Bool {
        guard let questions = challenge.quiz?.questions, !questions.isEmpty else { return false }
        return questions.contains(where: { $0.correct_index == nil })
    }

    private func questionCard(_ q: WeeklyQuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(q.prompt)
                .font(.headline)

            ForEach(Array(q.options.enumerated()), id: \.offset) { idx, opt in
                Button {
                    // ✅ Don’t allow changes after lock
                    guard !isLocked else { return }
                    selections[q.id] = idx
                } label: {
                    HStack {
                        Image(systemName: selections[q.id] == idx ? "largecircle.fill.circle" : "circle")
                        Text(opt)
                        Spacer()
                    }
                    .opacity(isLocked ? 0.65 : 1.0)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                .disabled(isLocked)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func submit() async {
        // ✅ Hard enforcement lock (important)
        if isLocked {
            errorText = "This quiz is locked."
            return
        }

        guard let lp = manager.linkedPlayerId, let dn = manager.displayName else {
            errorText = "You are not linked to a player yet."
            return
        }
        guard let questions = challenge.quiz?.questions, !questions.isEmpty else {
            errorText = "No questions available."
            return
        }

        // ✅ Require all questions answered
        for q in questions {
            if selections[q.id] == nil {
                errorText = "Please answer all questions before submitting."
                return
            }
        }

        var score = 0
        let maxScore = questions.count

        if !isPendingScoring {
            for q in questions {
                if let correct = q.correct_index, selections[q.id] == correct {
                    score += 1
                }
            }
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await manager.submitQuiz(
                linkedPlayerId: lp,
                displayName: dn,
                answers: selections,
                score: score,
                maxScore: maxScore
            )
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
