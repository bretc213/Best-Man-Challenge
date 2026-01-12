//
//  WeeklyQuizPlayView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/8/26.
//


import SwiftUI

struct WeeklyQuizPlayView: View {
    let challenge: WeeklyChallenge
    @ObservedObject var manager: WeeklyChallengeManager

    @Environment(\.dismiss) private var dismiss

    @State private var selections: [String: Int] = [:]
    @State private var isSubmitting = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text(challenge.title)
                    .font(.title2)
                    .bold()

                if let questions = challenge.quiz?.questions, !questions.isEmpty {
                    ForEach(questions, id: \.id) { q in
                        questionCard(q)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        Text(isSubmitting ? "Submitting…" : "Submit Quiz")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting)

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

    private func questionCard(_ q: WeeklyQuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(q.prompt)
                .font(.headline)

            ForEach(Array(q.options.enumerated()), id: \.offset) { idx, opt in
                Button {
                    selections[q.id] = idx
                } label: {
                    HStack {
                        Image(systemName: selections[q.id] == idx ? "largecircle.fill.circle" : "circle")
                        Text(opt)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func submit() async {
        guard let lp = manager.linkedPlayerId, let dn = manager.displayName else {
            errorText = "You are not linked to a player yet."
            return
        }
        guard let questions = challenge.quiz?.questions, !questions.isEmpty else {
            errorText = "No questions available."
            return
        }

        // score
        var score = 0
        for q in questions {
            if selections[q.id] == q.correct_index { score += 1 }
        }
        let maxScore = questions.count

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
