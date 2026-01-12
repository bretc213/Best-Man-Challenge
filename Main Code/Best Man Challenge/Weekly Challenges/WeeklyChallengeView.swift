import SwiftUI

struct WeeklyChallengeView: View {
    @StateObject private var challengeManager = WeeklyChallengeManager()

    // Later we can pass these from your real session model
    let linkedPlayerId: String?
    let displayName: String?

    @State private var showQuiz = false

    init(linkedPlayerId: String? = nil, displayName: String? = nil) {
        self.linkedPlayerId = linkedPlayerId
        self.displayName = displayName
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
            .onAppear {
                challengeManager.setUserContext(
                    linkedPlayerId: linkedPlayerId,
                    displayName: displayName
                )
                challengeManager.refresh()
            }
            .onDisappear {
                challengeManager.stopListening()
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
                        Text("Start Quiz")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let last = challengeManager.lastSubmission {
                    lastSubmissionCard(last)
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

    private func lastSubmissionCard(_ submission: WeeklyChallengeSubmission) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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

    private var noSubmissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your submission").font(.headline)
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
