import SwiftUI
import FirebaseAuth

struct WeeklyImageQuizPlayView: View {
    let challenge: WeeklyChallenge
    @ObservedObject var manager: WeeklyChallengeManager

    @EnvironmentObject var session: SessionStore

    @State private var answers: [String: String] = [:]
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didLoadDraft = false

    private var questions: [WeeklyImageQuizQuestion] {
        challenge.imageQuizQuestions
    }

    private var canSubmit: Bool {
        if isRefOrAdmin { return true }
        return hasLinkedPlayer
    }

    private var showsLinkWarning: Bool {
        !canSubmit && !isRefOrAdmin
    }

    private var role: String {
        (session.profile?.role ?? "").lowercased()
    }

    private var hasLinkedPlayer: Bool {
        let lp = session.profile?.linkedPlayerId ?? ""
        return !lp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isRefOrAdmin: Bool {
        role == "ref" || role == "admin" || role == "commish" || role == "commissioner"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(challenge.title)
                    .font(.title2.bold())

                if let description = challenge.description.isEmpty ? nil : challenge.description {
                    Text(description)
                        .foregroundStyle(.secondary)
                }

                if let rules = challenge.rules, !rules.isEmpty {
                    rulesCard(rules)
                }

                Divider().opacity(0.3)

                if let score = manager.lastSubmission?.score,
                   let max = manager.lastSubmission?.maxScore {
                    submittedCard(score: score, maxScore: max)
                } else if questions.isEmpty {
                    Text("Image quiz not configured.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(questions) { question in
                        questionCard(question)
                    }

                    if showsLinkWarning {
                        Text("You are not linked to a player yet.")
                            .foregroundColor(.red)
                            .font(.footnote)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        Text(isSubmitting ? "Submitting..." : "Submit Answers")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting || manager.lastSubmission != nil || !allAnswered)
                }

                Spacer(minLength: 24)
            }
            .padding()
        }
        .navigationTitle("Image Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadSavedDraftIfNeeded()
        }
    }

    private var allAnswered: Bool {
        questions.allSatisfy {
            !(answers[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    @ViewBuilder
    private func rulesCard(_ rules: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rules")
                .font(.headline)

            ForEach(Array(rules.enumerated()), id: \.offset) { idx, rule in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(idx + 1).")
                        .foregroundStyle(.secondary)
                    Text(rule)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func submittedCard(score: Int, maxScore: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("✅ You already submitted.")
                .font(.headline)

            Text("Score: \(score)/\(maxScore)")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func questionCard(_ question: WeeklyImageQuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question.prompt)
                .font(.headline)

            Image(question.image_name)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 210)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            TextField("Enter character name", text: binding(for: question.id))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(manager.lastSubmission != nil)
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func binding(for questionId: String) -> Binding<String> {
        Binding(
            get: { answers[questionId] ?? "" },
            set: { answers[questionId] = $0 }
        )
    }

    private func submit() async {
        guard manager.lastSubmission == nil else { return }
        guard !isSubmitting else { return }

        if !canSubmit {
            errorMessage = "You are not linked to a player yet."
            return
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let result = ImageQuizGrader.score(
            answersByQuestionId: answers,
            questions: questions,
            pointsPerCorrect: challenge.imageQuizPointsPerCorrect
        )

        do {
            try await manager.submitImageQuiz(
                answers: answers,
                score: result.score,
                maxScore: questions.count * challenge.imageQuizPointsPerCorrect,
                breakdown: result.breakdown
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadSavedDraftIfNeeded() async {
        guard !didLoadDraft else { return }
        didLoadDraft = true

        // If already submitted, don't overwrite UI with any saved draft.
        guard manager.lastSubmission == nil else { return }

        if let saved = await manager.loadImageQuizDraft(challengeId: challenge.id), !saved.isEmpty {
            answers = saved
        }
    }
}
