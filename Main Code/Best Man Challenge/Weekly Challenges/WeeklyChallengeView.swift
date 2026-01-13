import SwiftUI

struct WeeklyChallengeView: View {
    @EnvironmentObject var challengeManager: WeeklyChallengeManager

    @State private var showQuiz = false

    private func isLocked(_ challenge: WeeklyChallenge) -> Bool {
        Date() >= challenge.endDate
    }

    private func buttonTitle(for challenge: WeeklyChallenge) -> String {
        if isLocked(challenge) {
            return "View Picks (Locked)"
        }
        return challengeManager.lastSubmission == nil
            ? "Start Quiz"
            : "View / Edit Picks"
    }
    
    var body: some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        challengeManager.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh")
                }
            }
            .navigationDestination(isPresented: $showQuiz) {
                if let challenge = challengeManager.currentChallenge {
                    WeeklyQuizPlayView(challenge: challenge, manager: challengeManager)
                } else {
                    Text("No active challenge.")
                        .navigationTitle("Quiz")
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch challengeManager.state {
        case .idle, .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading weekly challenge…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty:
            VStack(spacing: 12) {
                Text("No weekly challenges are available right now.")
                    .font(.headline)
                Button("Refresh") { challengeManager.refresh() }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            VStack(spacing: 12) {
                Text("Couldn’t load weekly challenge")
                    .font(.headline)
                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") { challengeManager.refresh() }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded:
            if let challenge = challengeManager.currentChallenge {
                loadedView(challenge)
            } else {
                Text("No active challenge.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func loadedView(_ challenge: WeeklyChallenge) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard(challenge)

                if challenge.type == .quiz {
                    Button {
                        showQuiz = true
                    } label: {
                        Text(buttonTitle(for: challenge))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }


                if let last = challengeManager.lastSubmission {
                    lastSubmissionCard(last, challenge: challenge)
                } else {
                    noSubmissionCard
                }
            }
            .padding()
        }
    }

    private func headerCard(_ challenge: WeeklyChallenge) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(challenge.title)
                .font(.title2)
                .bold()

            if !challenge.description.isEmpty {
                Text(challenge.description)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                pill("Starts", challenge.startDate.formatted(date: .abbreviated, time: .omitted))
                pill("Ends", challenge.endDate.formatted(date: .abbreviated, time: .omitted))
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // ✅ Updated: shows their answers for the week (when available)
    private func lastSubmissionCard(_ submission: WeeklyChallengeSubmission, challenge: WeeklyChallenge) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your submission")
                .font(.headline)

            Text("Submitted \(submission.submittedAt.formatted(date: .abbreviated, time: .shortened))")
                .foregroundStyle(.secondary)

            // Score (if known)
            if let score = submission.score {
                if let max = submission.maxScore {
                    Text("Score: \(score)/\(max)")
                } else {
                    Text("Score: \(score)")
                }
            }

            // If any quiz question is missing correct_index, this week is "pending scoring"
            if isPendingScoring(challenge) {
                Text("Scoring will be applied after the games finish.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Show quiz answers (if they exist)
            if let answers = submission.answers,
               let questions = challenge.quiz?.questions,
               !questions.isEmpty {

                Divider().opacity(0.35)

                Text("Your picks")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    ForEach(questions, id: \.id) { q in
                        let pickedIndex = answers[q.id]
                        let pickedText: String = {
                            guard let pickedIndex,
                                  pickedIndex >= 0,
                                  pickedIndex < q.options.count else { return "—" }
                            return q.options[pickedIndex]
                        }()

                        HStack(alignment: .top, spacing: 10) {
                            Text(q.prompt)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)

                            Spacer()

                            Text(pickedText)
                                .font(.footnote.weight(.semibold))
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func isPendingScoring(_ challenge: WeeklyChallenge) -> Bool {
        guard let qs = challenge.quiz?.questions, !qs.isEmpty else { return false }
        // requires WeeklyQuizQuestion.correct_index to be Int?
        return qs.contains(where: { $0.correct_index == nil })
    }

    private var noSubmissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your submission")
                .font(.headline)
            Text("No submission yet (or you’re not linked to a player).")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func pill(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline)
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
