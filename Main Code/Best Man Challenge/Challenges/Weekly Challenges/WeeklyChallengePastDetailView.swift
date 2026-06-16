//
//  WeeklyChallengePastDetailView.swift
//  Best Man Challenge
//
//  Read-only archive view for a finalized weekly challenge.
//  Shows: challenge info, the current user's submission & score,
//  revealed correct answers (by type), and the week's standings.
//

import SwiftUI
import FirebaseFirestore

struct WeeklyChallengePastDetailView: View {
    let challenge: WeeklyChallenge
    @EnvironmentObject var session: SessionStore

    @StateObject private var detailStore    = WeeklyChallengePastDetailStore()
    @StateObject private var leaderboard    = WeeklyChallengeLeaderboardStore()

    var body: some View {
        ThemedScreen {
            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    resultsCard
                    answersSection
                    standingsSection
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Week \(challenge.week)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            leaderboard.startListening(weekId: challenge.id)
            if let pid = session.profile?.linkedPlayerId, !pid.isEmpty {
                Task { await detailStore.load(challengeId: challenge.id, submitterId: pid) }
            }
        }
        .onDisappear { leaderboard.stopListening() }
    }

    // ─────────────────────────────────────────
    // MARK: Header Card
    // ─────────────────────────────────────────

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("WEEK \(challenge.week)")
                    .font(.caption.bold())
                    .tracking(1)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.accent)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())

                Spacer()

                Text(challenge.type.displayName)
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.accent.opacity(0.18))
                    .foregroundStyle(Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Text(challenge.title)
                .font(.title3.bold())
                .foregroundStyle(Color.textPrimary)

            if !challenge.description.isEmpty {
                Text(challenge.description)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }

            if let start = challenge.startDate, let end = challenge.endDate {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text("\(start.formatted(date: .abbreviated, time: .omitted)) – \(end.formatted(date: .abbreviated, time: .omitted))")
                }
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
            }
        }
        .padding()
        .background(Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // ─────────────────────────────────────────
    // MARK: Results Card
    // ─────────────────────────────────────────

    @ViewBuilder
    private var resultsCard: some View {
        if detailStore.isLoading {
            HStack {
                ProgressView().tint(Color.accent)
                Text("Loading your results…")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))

        } else if let sub = detailStore.submission {
            VStack(alignment: .leading, spacing: 12) {
                Label("Your Results", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(Color.accent)

                HStack(alignment: .bottom, spacing: 6) {
                    if let score = sub.score {
                        Text("\(score)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.accent)
                        Text(sub.maxScore.map { "/ \(String($0)) pts" } ?? "pts")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                            .padding(.bottom, 6)
                    }

                    Spacer()

                    // Quick result badge
                    resultBadge(for: sub)
                }

                Divider().background(Color.textSecondary.opacity(0.3))

                Text("Submitted \(sub.submittedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            .padding()
            .background(Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))

        } else {
            HStack(spacing: 10) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(Color.textSecondary)
                Text("You didn't submit this week")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
            }
            .padding()
            .background(Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private func resultBadge(for sub: WeeklyChallengeSubmission) -> some View {
        switch challenge.type {
        case .wordle, .multi_wordle:
            if let solved = sub.wordleSolved {
                statusPill(
                    solved ? "Solved" : "Not Solved",
                    icon: solved ? "checkmark.circle.fill" : "x.circle.fill",
                    color: solved ? .green : .red
                )
            }
        case .riddle where challenge.isWordle:
            if let solved = sub.wordleSolved {
                statusPill(
                    solved ? "Solved" : "Not Solved",
                    icon: solved ? "checkmark.circle.fill" : "x.circle.fill",
                    color: solved ? .green : .red
                )
            }
        case .riddle:
            if let correct = sub.isCorrect {
                statusPill(
                    correct ? "Correct" : "Incorrect",
                    icon: correct ? "checkmark.circle.fill" : "x.circle.fill",
                    color: correct ? .green : .red
                )
            }
        default:
            EmptyView()
        }
    }

    private func statusPill(_ label: String, icon: String, color: Color) -> some View {
        Label(label, systemImage: icon)
            .font(.subheadline.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    // ─────────────────────────────────────────
    // MARK: Answers Section (type-specific)
    // ─────────────────────────────────────────

    @ViewBuilder
    private var answersSection: some View {
        switch challenge.type {
        case .quiz:
            quizAnswers
        case .image_quiz:
            imageQuizAnswers
        case .wordle:
            wordleAnswer
        case .multi_wordle:
            multiWordleAnswers
        case .riddle where challenge.isWordle:
            wordleAnswer
        case .riddle:
            riddleAnswer
        case .connections:
            connectionsAnswers
        case .prop_bets:
            noteCard(icon: "die.face.3.fill",
                     text: "Prop bet results are graded by the commissioner.")
        case .photo_challenge:
            noteCard(icon: "camera.fill",
                     text: "Photo challenge winners are chosen by the judge.")
        case .scavenger_hunt:
            scavengerHuntItems
        case .creative:
            noteCard(icon: "pencil.and.outline",
                     text: "Creative submissions are reviewed manually.")
        case .minesweeper:
            noteCard(icon: "flag.fill",
                     text: "Minesweeper results were scored at submission time.")
        case .halfway_challenge:
            noteCard(icon: "trophy.fill",
                     text: "Halfway challenge results were scored at submission time.")
        }
    }

    // ── Quiz ──────────────────────────────────

    @ViewBuilder
    private var quizAnswers: some View {
        if let questions = challenge.quiz?.questions, !questions.isEmpty {
            sectionContainer(title: "Answers", icon: "questionmark.circle.fill") {
                VStack(spacing: 10) {
                    ForEach(questions) { q in
                        quizQuestionCard(q)
                    }
                }
            }
        }
    }

    private func quizQuestionCard(_ q: WeeklyQuizQuestion) -> some View {
        let userIdx   = detailStore.submission?.answers?[q.id]
        let correctIdx = q.correct_index

        return VStack(alignment: .leading, spacing: 8) {
            Text(q.prompt)
                .font(.subheadline.bold())
                .foregroundStyle(Color.textPrimary)

            ForEach(Array(q.options.enumerated()), id: \.offset) { idx, option in
                let isCorrect = correctIdx == idx
                let isUser    = userIdx == idx
                let showBg    = isCorrect || isUser

                HStack(spacing: 8) {
                    Image(systemName: isCorrect
                          ? "checkmark.circle.fill"
                          : (isUser ? "x.circle.fill" : "circle"))
                        .foregroundStyle(isCorrect ? .green : (isUser ? .red : Color.textSecondary))

                    Text(option)
                        .font(.subheadline)
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    if isUser && !isCorrect {
                        Text("Your pick")
                            .font(.caption2.bold())
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isCorrect
                              ? Color.green.opacity(0.14)
                              : (isUser ? Color.red.opacity(0.12) : Color.clear))
                )
            }
        }
        .padding(12)
        .background(Color.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // ── Image Quiz ────────────────────────────

    @ViewBuilder
    private var imageQuizAnswers: some View {
        if let questions = challenge.quiz?.image_questions, !questions.isEmpty {
            sectionContainer(title: "Answers", icon: "photo.fill") {
                VStack(spacing: 10) {
                    ForEach(questions) { q in
                        imageQuizCard(q)
                    }
                }
            }
        }
    }

    private func imageQuizCard(_ q: WeeklyImageQuizQuestion) -> some View {
        let userAnswer = detailStore.submission?.textAnswers?[q.id]
        let isCorrect  = detailStore.submission?.breakdown?[q.id]

        return VStack(alignment: .leading, spacing: 6) {
            Text(q.prompt)
                .font(.subheadline.bold())
                .foregroundStyle(Color.textPrimary)

            if let answer = q.answer {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Answer: \(answer)")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }

            if let ua = userAnswer {
                HStack(spacing: 6) {
                    if let correct = isCorrect {
                        Image(systemName: correct ? "checkmark.circle.fill" : "x.circle.fill")
                            .foregroundStyle(correct ? .green : .red)
                    }
                    Text("Your answer: \(ua)")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(12)
        .background(Color.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // ── Wordle ────────────────────────────────

    @ViewBuilder
    private var wordleAnswer: some View {
        if let ans = challenge.wordleAnswer {
            sectionContainer(title: "The Word", icon: "w.circle.fill") {
                Text(ans.uppercased())
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.accent)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
    }

    // ── Multi-Wordle ──────────────────────────

    @ViewBuilder
    private var multiWordleAnswers: some View {
        if let words = challenge.multi_wordle?.words, !words.isEmpty {
            sectionContainer(title: "The Words", icon: "w.circle.fill") {
                VStack(spacing: 12) {
                    ForEach(words) { w in
                        HStack {
                            if let label = w.label {
                                Text(label)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Text(w.answer.uppercased())
                                .font(.system(.title3, design: .monospaced).bold())
                                .foregroundStyle(Color.accent)
                        }
                        .padding(10)
                        .background(Color.background.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    // ── Riddle ────────────────────────────────

    @ViewBuilder
    private var riddleAnswer: some View {
        if let ans = challenge.answer, !ans.isEmpty {
            sectionContainer(title: "The Answer", icon: "lightbulb.fill") {
                Text(ans)
                    .font(.title3.bold())
                    .foregroundStyle(Color.accent)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
    }

    // ── Connections ───────────────────────────

    @ViewBuilder
    private var connectionsAnswers: some View {
        if let config = challenge.connections_config {
            sectionContainer(title: "Categories", icon: "square.grid.2x2.fill") {
                VStack(spacing: 10) {
                    ForEach(config.categories.sorted { $0.color.order < $1.color.order }) { cat in
                        connectionsCard(cat)
                    }
                }
            }
        }
    }

    private func connectionsCard(_ cat: ConnectionsCategory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(cat.color.swiftUIColor)
                    .frame(width: 10, height: 10)
                Text(cat.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(cat.point_value) pt\(cat.point_value == 1 ? "" : "s")")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accent)
            }
            Text(cat.words.joined(separator: "  ·  "))
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(10)
        .background(cat.color.swiftUIColor.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(cat.color.swiftUIColor.opacity(0.35), lineWidth: 1)
        )
    }

    // ── Scavenger Hunt ────────────────────────

    @ViewBuilder
    private var scavengerHuntItems: some View {
        if let config = challenge.scavenger_hunt {
            sectionContainer(title: "Items", icon: "map.fill") {
                VStack(spacing: 8) {
                    ForEach(config.items) { item in
                        HStack(spacing: 10) {
                            Text(item.emoji)
                                .font(.title3)
                            Text(item.clue)
                                .font(.subheadline)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text("\(item.point_value) pt\(item.point_value == 1 ? "" : "s")")
                                .font(.caption.bold())
                                .foregroundStyle(Color.accent)
                        }
                        .padding(10)
                        .background(Color.background.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────
    // MARK: Standings Section
    // ─────────────────────────────────────────

    private var standingsSection: some View {
        sectionContainer(title: "Weekly Standings", icon: "trophy.fill") {
            if leaderboard.standings.isEmpty {
                Text("No submissions this week.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(leaderboard.standings.enumerated()), id: \.element.id) { idx, s in
                        standingRow(rank: idx + 1, standing: s)

                        if idx < leaderboard.standings.count - 1 {
                            Divider()
                                .background(Color.textSecondary.opacity(0.2))
                                .padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    private func standingRow(rank: Int, standing: WeeklyChallengeStanding) -> some View {
        let isMe = standing.id == session.profile?.linkedPlayerId

        return HStack(spacing: 12) {
            // Rank
            Text("#\(rank)")
                .font(.caption.bold())
                .foregroundStyle(rank <= 3 ? Color.accent : Color.textSecondary)
                .frame(width: 28, alignment: .leading)

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(standing.displayName)
                    .font(.subheadline.weight(isMe ? .bold : .regular))
                    .foregroundStyle(isMe ? Color.accent : Color.textPrimary)

                if !standing.hasSubmitted {
                    Text("No submission")
                        .font(.caption2)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer()

            // Score
            Text("\(standing.points) pts")
                .font(.subheadline.bold())
                .foregroundStyle(standing.hasSubmitted ? Color.textPrimary : Color.textSecondary)

            // "You" badge
            if isMe {
                Text("You")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Color.accent.opacity(0.2))
                    .foregroundStyle(Color.accent)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 10)
    }

    // ─────────────────────────────────────────
    // MARK: Helpers
    // ─────────────────────────────────────────

    @ViewBuilder
    private func sectionContainer<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(Color.accent)

            content()
        }
        .padding()
        .background(Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func noteCard(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.accent)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
        }
        .padding()
        .background(Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// ─────────────────────────────────────────────────────────
// MARK: - Helpers on existing types
// ─────────────────────────────────────────────────────────

private extension ChallengeType {
    var displayName: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private extension ConnectionsColor {
    var swiftUIColor: Color {
        switch self {
        case .yellow: return Color(red: 0.95, green: 0.80, blue: 0.15)
        case .green:  return Color(red: 0.28, green: 0.78, blue: 0.35)
        case .blue:   return Color(red: 0.28, green: 0.60, blue: 0.95)
        case .purple: return Color(red: 0.68, green: 0.32, blue: 0.90)
        }
    }
}
