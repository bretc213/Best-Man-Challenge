//
//  RiddleChallengeView.swift
//  Best Man Challenge
//

import SwiftUI

struct RiddleChallengeView: View {
    let challenge: WeeklyChallenge
    let lastSubmission: WeeklyChallengeSubmission?
    let onSubmit: (_ text: String, _ isCorrect: Bool) async throws -> Void

    @State private var answerText: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            Text(challenge.title)
                .font(.title2)
                .bold()

            Text(challenge.description)
                .foregroundStyle(.secondary)

            // ✅ If user already submitted (riddle), show result summary
            if let submission = lastSubmission,
               let submittedAnswer = submission.answerText,
               !submittedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                submissionCard(submission: submission)

            } else {
                // No submission yet → show input UI
                inputCard
            }

            Spacer()
        }
        .padding(.top, 6)
        .onAppear {
            // If you want to prefill for testing, you can, but keeping clean for v1
        }
    }

    // MARK: - Input UI

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Answer")
                .font(.headline)

            TextField("Type your answer…", text: $answerText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await submitTapped() }
            } label: {
                Text(isSubmitting ? "Submitting..." : "Submit")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting || answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .cardStyle()
    }

    // MARK: - Submission Summary

    private func submissionCard(submission: WeeklyChallengeSubmission) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Submission")
                .font(.headline)

            if let answer = submission.answerText {
                Text(answer)
                    .font(.body)
            }

            // ✅ FIX: isCorrect is Bool? now, so unwrap safely
            if let isCorrect = submission.isCorrect {
                HStack(spacing: 8) {
                    Image(systemName: isCorrect ? "checkmark.seal.fill" : "xmark.seal.fill")
                    Text(isCorrect ? "Correct" : "Incorrect")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(isCorrect ? .green : .red)
            } else {
                // For safety: if this is actually a quiz submission, it won’t show correctness here
                Text("Submitted")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if challenge.isExpired {
                Text("This weekly challenge has ended.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("You can only submit once.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    // MARK: - Actions

    private func submitTapped() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let cleaned = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            errorMessage = "Answer cannot be empty."
            return
        }

        // Determine correctness if the challenge has an answer
        // (For your sudoku/cipher/riddle weeks this is how you were doing it.)
        let correctAnswer = (challenge.answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        let isCorrect: Bool = {
            guard !correctAnswer.isEmpty else { return false }
            return cleaned.lowercased() == correctAnswer.lowercased()
        }()

        do {
            try await onSubmit(cleaned, isCorrect)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationView {
        RiddleChallengeView(
            challenge: WeeklyChallenge(
                id: "2026_w01",
                week: 1,
                title: "Test Riddle",
                description: "A simple riddle to test submission UI.",
                type: ChallengeType(rawValue: "riddle") ?? .riddle, // adjust if your enum differs
                startDate: Date().addingTimeInterval(-3600),
                endDate: Date().addingTimeInterval(3600 * 24),
                answer: "test",
                puzzle: nil,
                cipher: nil,
                quiz: nil,
                is_active: true
            ),
            lastSubmission: WeeklyChallengeSubmission(
                id: "uid",
                uid: "uid",
                linkedPlayerId: "bretc",
                displayName: "Bret C.",
                answerText: "test",
                isCorrect: true,
                answers: nil,
                score: nil,
                maxScore: nil,
                submittedAt: Date()
            ),
            onSubmit: { _, _ in }
        )
    }
}
