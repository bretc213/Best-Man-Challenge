import SwiftUI
import FirebaseAuth

struct WeeklyChallengeView: View {
    @EnvironmentObject var challengeManager: WeeklyChallengeManager
    @EnvironmentObject var session: SessionStore

    @State private var showQuiz = false
    @State private var showImageQuiz = false
    @State private var showPropBets = false
    @State private var showWordle = false
    @State private var showMultiWordle = false
    @State private var showPhotoChallenge = false
    @State private var showScavengerHunt = false
    @State private var showConnections = false
    @State private var showHalfwayChallenge = false
    @State private var showPropBetsAdmin = false
    @State private var showPhotoAdmin = false

    private var isOwnerAccount: Bool {
        let role = session.profile?.role ?? ""
        return role == "owner" || role == "commish"
    }

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

    private func imageQuizButtonTitle(for challenge: WeeklyChallenge) -> String {
        if isLocked(challenge) { return "View Image Quiz (Locked)" }
        return challengeManager.lastSubmission == nil ? "Start Image Quiz" : "Image Quiz Completed"
    }

    private func propBetsButtonTitle(for challenge: WeeklyChallenge) -> String {
        isLocked(challenge) ? "View Picks (Locked)" : "Make Picks"
    }

    private func wordleFinished() -> Bool {
        challengeManager.lastSubmission?.isWordleFinished == true
    }

    private func wordleButtonTitle(for challenge: WeeklyChallenge) -> String {
        if wordleFinished() { return "Weekly Challenge Completed" }
        if isLocked(challenge) { return "Wordle (Locked)" }
        return "Play Wordle"
    }

    private func syncUserContextIntoManager() {
        challengeManager.setUserContext(
            uid: Auth.auth().currentUser?.uid,
            linkedPlayerId: session.profile?.linkedPlayerId,
            displayName: session.profile?.displayName
        )
    }

    var body: some View {
        content
            .onAppear {
                syncUserContextIntoManager()
            }
            .onChange(of: session.profile?.displayName) { _, _ in
                syncUserContextIntoManager()
            }
            .onChange(of: session.profile?.linkedPlayerId) { _, _ in
                syncUserContextIntoManager()
            }
            .onChange(of: session.firebaseUser?.uid) { _, _ in
                syncUserContextIntoManager()
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
            .navigationDestination(isPresented: $showImageQuiz) {
                if let challenge = challengeManager.currentChallenge {
                    WeeklyImageQuizPlayView(challenge: challenge, manager: challengeManager)
                        .environmentObject(session)
                } else {
                    Text("No active challenge.").navigationTitle("Image Quiz")
                }
            }
            .navigationDestination(isPresented: $showPropBets) {
                if let challenge = challengeManager.currentChallenge {
                    PropBetsView(challengeId: challenge.id)
                } else {
                    Text("No active challenge.").navigationTitle("Prop Bets")
                }
            }
            .navigationDestination(isPresented: $showWordle) {
                if let challenge = challengeManager.currentChallenge {
                    WordleView(
                        challengeId: challenge.id,
                        prompt: challenge.title,
                        answer: challenge.wordle?.answer,
                        wordLength: challenge.wordle?.word_length,
                        maxAttempts: challenge.wordle?.max_attempts,
                        isLocked: isLocked(challenge) || wordleFinished()
                    )
                    .environmentObject(challengeManager)
                } else {
                    Text("No active challenge.").navigationTitle("Wordle")
                }
            }
            .navigationDestination(isPresented: $showMultiWordle) {
                if let challenge = challengeManager.currentChallenge {
                    MultiWordleView(challenge: challenge)
                        .environmentObject(challengeManager)
                        .environmentObject(session)
                } else {
                    Text("No active challenge.").navigationTitle("Triple Wordle")
                }
            }
            .navigationDestination(isPresented: $showPhotoChallenge) {
                if let challenge = challengeManager.currentChallenge {
                    PhotoChallengeView(challenge: challenge)
                        .environmentObject(session)
                } else {
                    Text("No active challenge.").navigationTitle("Photo Challenge")
                }
            }
            .navigationDestination(isPresented: $showScavengerHunt) {
                if let challenge = challengeManager.currentChallenge {
                    ScavengerHuntView(challenge: challenge)
                        .environmentObject(session)
                } else {
                    Text("No active challenge.").navigationTitle("Scavenger Hunt")
                }
            }
            .navigationDestination(isPresented: $showConnections) {
                if let challenge = challengeManager.currentChallenge {
                    ConnectionsView(challenge: challenge)
                        .environmentObject(session)
                } else {
                    Text("No active challenge.").navigationTitle("Connections")
                }
            }
            .navigationDestination(isPresented: $showHalfwayChallenge) {
                if let challenge = challengeManager.currentChallenge {
                    HalfwayChallengeView(challenge: challenge)
                        .environmentObject(session)
                } else {
                    Text("No active challenge.").navigationTitle("Halfway Challenge")
                }
            }
            .navigationDestination(isPresented: $showPropBetsAdmin) {
                if let challenge = challengeManager.currentChallenge {
                    PropBetsAdminGradingView(challenge: challenge)
                } else {
                    Text("No active challenge.").navigationTitle("Grade Props")
                }
            }
            .navigationDestination(isPresented: $showPhotoAdmin) {
                if let challenge = challengeManager.currentChallenge {
                    PhotoChallengeAdminView(challenge: challenge)
                } else {
                    Text("No active challenge.").navigationTitle("Photo Winners")
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
        let locked = isLocked(challenge)
        let finishedWordle = wordleFinished()

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard(challenge)

                if challenge.type == .quiz {
                    Button { showQuiz = true } label: {
                        Text(quizButtonTitle(for: challenge)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Text("You’ll have 5 minutes once you start.")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }

                if challenge.isImageQuiz {
                    Button { showImageQuiz = true } label: {
                        Text(imageQuizButtonTitle(for: challenge)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Text(locked ? "Answers are locked." : "Type each Pixar character name from the image.")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }

                if challenge.type == .prop_bets {
                    Button { showPropBets = true } label: {
                        Text(propBetsButtonTitle(for: challenge)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Text(locked ? "Picks are locked." : "You can change picks any time before kickoff.")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }

                if challenge.isWordle {
                    Button {
                        guard !finishedWordle else { return }
                        showWordle = true
                    } label: {
                        Text(wordleButtonTitle(for: challenge)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(finishedWordle)

                    Text(finishedWordle ? "Completed — you can’t re-enter this week’s Wordle." :
                            (locked ? "Locked." : "Progress saves after each guess."))
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }

                if challenge.type == .multi_wordle {
                    Button { showMultiWordle = true } label: {
                        Text(locked ? "View Triple Wordle (Locked)" : "Play Triple Wordle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Text(locked ? "Submissions are closed." : "Solve all three words for max points.")
                        .foregroundStyle(.secondary).font(.footnote)
                }

                if challenge.type == .photo_challenge {
                    Button { showPhotoChallenge = true } label: {
                        Text(locked ? "View Photos (Locked)" : "Submit Photos")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Text(locked ? "Submissions are closed." : "Upload a photo for each prompt.")
                        .foregroundStyle(.secondary).font(.footnote)
                }

                if challenge.type == .scavenger_hunt {
                    Button { showScavengerHunt = true } label: {
                        Text(locked ? "View Hunt (Locked)" : "Start Scavenger Hunt")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Text(locked ? "Submissions are closed." : "Find each item and upload photo proof.")
                        .foregroundStyle(.secondary).font(.footnote)
                }

                if challenge.type == .halfway_challenge {
                    Button { showHalfwayChallenge = true } label: {
                        Text("Enter the Halfway Challenge")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Text("5 mini-games, 6 pts each. Complete a round to unlock the next.")
                        .foregroundStyle(.secondary).font(.footnote)
                }

                if challenge.type == .connections {
                    Button { showConnections = true } label: {
                        Text(locked ? "View Connections (Locked)" : "Play Connections")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Text(locked ? "Submissions are closed." : "Group four words that share a connection.")
                        .foregroundStyle(.secondary).font(.footnote)
                }

                if challenge.type == .prop_bets {
                    if let summary = challengeManager.propBetsPickSummary, summary.hasSubmitted {
                        propBetsSubmissionCard(summary, challenge: challenge)
                    } else {
                        noSubmissionCard
                    }
                } else if challenge.isWordle {
                    if let sub = challengeManager.lastSubmission, sub.isWordleFinished {
                        wordleSubmissionCard(sub, maxAttempts: challenge.wordle?.max_attempts ?? 6)
                    } else {
                        noSubmissionCard
                    }
                } else {
                    if let last = challengeManager.lastSubmission {
                        lastSubmissionCard(last)
                    } else {
                        noSubmissionCard
                    }
                }

                // MARK: - Owner-only admin section
                if isOwnerAccount {
                    adminCard(challenge)
                }
            }
            .padding()
        }
    }

    private func adminCard(_ challenge: WeeklyChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.orange)
                Text("Admin")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }

            if challenge.type == .prop_bets {
                Button {
                    showPropBetsAdmin = true
                } label: {
                    Label("Grade Prop Bets", systemImage: "checkmark.seal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }

            if challenge.type == .photo_challenge {
                Button {
                    showPhotoAdmin = true
                } label: {
                    Label("Select Photo Winners", systemImage: "trophy")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
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

    private func lastSubmissionCard(_ submission: WeeklyChallengeSubmission) -> some View {
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

    private func wordleSubmissionCard(_ submission: WeeklyChallengeSubmission, maxAttempts: Int) -> some View {
        let attempts = submission.wordleAttempts ?? maxAttempts
        let solved = submission.wordleSolved ?? ((submission.score ?? 0) > 0)
        let points = submission.score ?? 0

        let resultText: String = {
            if solved {
                return "✅ Correct in \(attempts) \(attempts == 1 ? "guess" : "guesses")"
            } else {
                return "❌ Out of tries"
            }
        }()

        return VStack(alignment: .leading, spacing: 10) {
            Text("Weekly challenge completed")
                .font(.headline)

            Text(resultText)
                .foregroundStyle(.primary)

            Text("Points: \(points)")
                .foregroundStyle(.secondary)

            Text("Submitted \(submission.submittedAt.formatted(date: .abbreviated, time: .shortened))")
                .foregroundStyle(.secondary)
                .font(.footnote)
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

        return VStack(alignment: .leading, spacing: 10) {
            Text("Your submission")
                .font(.headline)

            Text(submittedText)
                .foregroundStyle(.secondary)

            Text("Picks submitted: \(summary.selections.count)")
                .foregroundStyle(.primary)

            Text(isLocked(challenge) ? "Locked." : "You can still update picks until kickoff.")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
