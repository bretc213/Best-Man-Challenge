import SwiftUI

extension Notification.Name {
    static let weeklyQuizTimeExpired = Notification.Name("weeklyQuizTimeExpired")
}

struct WeeklyQuizPlayView: View {
    let challenge: WeeklyChallenge
    @ObservedObject var manager: WeeklyChallengeManager

    @EnvironmentObject var session: SessionStore

    // MARK: - Timer config
    private let quizDurationSeconds: Int = 5 * 60 // 5 minutes

    @State private var remainingSeconds: Int = 5 * 60
    @State private var timerExpired: Bool = false
    @State private var didAutoSubmit: Bool = false
    @State private var showTimeUpAlert: Bool = false

    // ✅ NEW: gate so we never show "locked" before starting
    @State private var hasStarted: Bool = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text(challenge.title)
                .font(.title2.bold())

            if let description = challenge.description.isEmpty ? nil : challenge.description {
                Text(description)
                    .foregroundStyle(.secondary)
            }

            Divider().opacity(0.3)

            // ✅ If already submitted -> show completed state (no timer, no "locked")
            if manager.lastSubmission != nil {
                WeeklyQuizChallengeView(
                    challenge: challenge,
                    lastSubmission: manager.lastSubmission,
                    onSubmit: { _, _, _ in }
                )

                Spacer()
                returnViewPadding()

            } else {
                // ✅ Not submitted yet

                // PRE-START STATE
                if !hasStarted {
                    Button {
                        startQuiz()
                    } label: {
                        Text("Start Quiz")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Text("You’ll have 5 minutes once you start.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    // ✅ Only show this warning for people who actually need a linked player
                    if showsLinkWarning {
                        Text("You are not linked to a player yet.")
                            .foregroundColor(.red)
                            .font(.footnote)
                            .padding(.top, 4)
                    }

                    Spacer()

                } else {
                    // ACTIVE QUIZ STATE (timer + quiz)

                    // ⏱ Timer bar
                    HStack {
                        Text("⏱ \(formatTime(remainingSeconds)) remaining")
                            .font(.headline)
                            .foregroundColor(remainingSeconds <= 30 ? .red : .primary)

                        Spacer()

                        if timerExpired {
                            Text("Time’s up")
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                    }

                    if let quiz = challenge.quiz,
                       let questions = quiz.questions,
                       !questions.isEmpty {

                        WeeklyQuizChallengeView(
                            challenge: challenge,
                            lastSubmission: manager.lastSubmission,
                            isLocked: timerExpired,
                            onSubmit: { answers, score, maxScore in
                                // ✅ Only enforce linked player for *players*.
                                // Refs/admins are allowed even with no linked_player_id.
                                if !canSubmit {
                                    throw NSError(
                                        domain: "WeeklyChallenge",
                                        code: 99,
                                        userInfo: [NSLocalizedDescriptionKey: "You are not linked to a player yet."]
                                    )
                                }

                                try await manager.submitQuiz(
                                    answers: answers,
                                    score: score,
                                    maxScore: maxScore
                                )
                            }
                        )

                    } else {
                        Text("Quiz not configured.")
                            .foregroundStyle(.secondary)
                    }

                    // ✅ Only show this warning for people who actually need a linked player
                    if showsLinkWarning {
                        Text("You are not linked to a player yet.")
                            .foregroundColor(.red)
                            .font(.footnote)
                            .padding(.top, 4)
                    }

                    Spacer()
                }
            }
        }
        .padding()
        .navigationTitle("Weekly Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // If already submitted, don't allow start state
            if manager.lastSubmission != nil {
                hasStarted = false
                timerExpired = false
            }
        }
        .onReceive(timer) { _ in
            // ✅ timer only runs after Start Quiz is tapped
            guard hasStarted else { return }
            guard manager.lastSubmission == nil else { return } // already submitted
            guard !timerExpired else { return }

            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                timerExpired = true
                autoSubmitIfNeeded()
            }
        }
        .alert("Time’s up", isPresented: $showTimeUpAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your quiz was automatically submitted.")
        }
    }

    // MARK: - Actions

    private func startQuiz() {
        // If they can't submit, still let them view? You said it "allows me in".
        // We'll keep behavior: allow them to start, but submit will be blocked by canSubmit check.
        hasStarted = true
        remainingSeconds = quizDurationSeconds
        timerExpired = false
        didAutoSubmit = false
        showTimeUpAlert = false
    }

    // MARK: - Timer helpers

    private func autoSubmitIfNeeded() {
        guard !didAutoSubmit else { return }
        didAutoSubmit = true

        // Tell the child quiz view to submit whatever it currently has selected.
        NotificationCenter.default.post(name: .weeklyQuizTimeExpired, object: nil)

        // Optional UX feedback
        showTimeUpAlert = true
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Submit rules

    private var role: String {
        (session.profile?.role ?? "").lowercased()
    }

    private var hasLinkedPlayer: Bool {
        let lp = session.profile?.linkedPlayerId ?? ""
        return !lp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Refs/admin-type roles can submit even without a linked player.
    private var isRefOrAdmin: Bool {
        role == "ref" || role == "admin" || role == "commish" || role == "commissioner"
    }

    /// Final gate for whether the submit *should* be allowed.
    private var canSubmit: Bool {
        if isRefOrAdmin { return true }
        return hasLinkedPlayer
    }

    /// Show the red warning only for players who actually need linking.
    private var showsLinkWarning: Bool {
        !canSubmit && !isRefOrAdmin
    }

    // MARK: - Tiny layout helper (keeps compiler happy with early return patterns)
    @ViewBuilder
    private func returnViewPadding() -> some View {
        EmptyView()
    }
}
