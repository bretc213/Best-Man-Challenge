import SwiftUI
import FirebaseAuth

struct WeeklyChallengeView: View {
    @EnvironmentObject var challengeManager: WeeklyChallengeManager
    @EnvironmentObject var session: SessionStore

    @State private var showQuiz = false
    @State private var showPropBets = false

    private func deadlineDate(for challenge: WeeklyChallenge) -> Date? {
        challenge.locksAt ?? challenge.endDate
    }

    private func isLocked(_ challenge: WeeklyChallenge) -> Bool {
        guard let deadline = deadlineDate(for: challenge) else { return false }
        return Date() >= deadline
    }

    private func quizButtonTitle(for challenge: WeeklyChallenge) -> String {
        if isLocked(challenge) { return "View Quiz (Locked)" }
        return challengeManager.lastSubmission == nil ? "Start Quiz" : "Quiz Completed"
    }

    private func propBetsButtonTitle(for challenge: WeeklyChallenge) -> String {
        isLocked(challenge) ? "View Picks (Locked)" : "Make Picks"
    }

    var body: some View {
        content
            .onAppear {
                challengeManager.setUserContext(
                    uid: Auth.auth().currentUser?.uid,
                    linkedPlayerId: session.profile?.linkedPlayerId,
                    displayName: session.profile?.displayName
                )
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { challengeManager.refresh() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh")
                }
            }
            .navigationDestination(isPresented: $showQuiz) {
                if let challenge = challengeManager.currentChallenge {
                    WeeklyQuizPlayView(challenge: challenge, manager: challengeManager)
                } else {
                    Text("No active challenge.").navigationTitle("Quiz")
                }
            }
            .navigationDestination(isPresented: $showPropBets) {
                if let challenge = challengeManager.currentChallenge {
                    PropBetsView(challengeId: challenge.id)
                } else {
                    Text("No active challenge.").navigationTitle("Prop Bets")
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

                // ✅ Quiz CTA + timer copy ONLY for quiz
                if challenge.type == .quiz {
                    Button { showQuiz = true } label: {
                        Text(quizButtonTitle(for: challenge))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Text("You’ll have 5 minutes once you start.")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }

                // ✅ Prop Bets CTA (no timer)
                if challenge.type == .prop_bets {
                    Button { showPropBets = true } label: {
                        Text(propBetsButtonTitle(for: challenge))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Text(isLocked(challenge) ? "Picks are locked." : "You can change picks any time before kickoff.")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }

                // ✅ Submission section: quiz/riddle vs prop bets
                if challenge.type == .prop_bets {
                    if let summary = challengeManager.propBetsPickSummary, summary.hasSubmitted {
                        propBetsSubmissionCard(summary, challenge: challenge)
                    } else {
                        noSubmissionCard
                    }
                } else {
                    if let last = challengeManager.lastSubmission {
                        lastSubmissionCard(last, challenge: challenge)
                    } else {
                        noSubmissionCard
                    }
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
                Text(challenge.description).foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if let start = challenge.startDate {
                    pill("Starts", start.formatted(date: .abbreviated, time: .omitted))
                }

                if let end = challenge.endDate {
                    pill("Ends", end.formatted(date: .abbreviated, time: .omitted))
                } else if let locks = challenge.locksAt {
                    pill("Locks", locks.formatted(date: .abbreviated, time: .omitted))
                } else {
                    pill("Ends", "—")
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func lastSubmissionCard(_ submission: WeeklyChallengeSubmission, challenge: WeeklyChallenge) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your submission").font(.headline)
            Text("Submitted \(submission.submittedAt.formatted(date: .abbreviated, time: .shortened))")
                .foregroundStyle(.secondary)

            if let score = submission.score {
                if let max = submission.maxScore {
                    Text("Score: \(score)/\(max)")
                } else {
                    Text("Score: \(score)")
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func propBetsSubmissionCard(_ summary: PropBetsPickSummary, challenge: WeeklyChallenge) -> some View {
        let submittedText: String = {
            guard let d = summary.submittedAt else { return "Submitted —" }
            return "Submitted \(d.formatted(date: .abbreviated, time: .shortened))"
        }()

        let totalProps = max(challengeManager.currentChallenge == nil ? 0 : 0, 0) // placeholder; we don't have props count here
        // We can’t know total props count from this screen without querying subcollection.
        // So we show picks count only (still useful).
        return VStack(alignment: .leading, spacing: 10) {
            Text("Your submission")
                .font(.headline)

            Text(submittedText)
                .foregroundStyle(.secondary)

            Text("Picks submitted: \(summary.selections.count)")
                .foregroundStyle(.primary)

            if isLocked(challenge) {
                Text("Locked.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("You can still update picks until kickoff.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var noSubmissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your submission").font(.headline)
            Text("No submission yet.").foregroundStyle(.secondary)
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
