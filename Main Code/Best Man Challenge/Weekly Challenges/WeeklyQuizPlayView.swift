import SwiftUI

struct WeeklyQuizPlayView: View {
    let challenge: WeeklyChallenge
    @ObservedObject var manager: WeeklyChallengeManager

    @EnvironmentObject var session: SessionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(challenge.title)
                .font(.title2.bold())

            if let description = challenge.description.isEmpty ? nil : challenge.description {
                Text(description)
                    .foregroundStyle(.secondary)
            }

            Divider().opacity(0.3)

            // ✅ Main quiz UI
            if let quiz = challenge.quiz,
               let questions = quiz.questions,
               !questions.isEmpty {

                WeeklyQuizChallengeView(
                    challenge: challenge,
                    lastSubmission: manager.lastSubmission,
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
        .padding()
        .navigationTitle("Weekly Quiz")
        .navigationBarTitleDisplayMode(.inline)
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
        if isRefOrAdmin {
            return true      // ✅ Amanda / commish path
        }
        return hasLinkedPlayer // normal players
    }

    /// Show the red warning only for players who actually need linking.
    private var showsLinkWarning: Bool {
        !canSubmit && !isRefOrAdmin
    }
}
