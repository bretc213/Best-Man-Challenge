//
//  MurderMysteryLocationsView.swift
//  Best Man Challenge
//
//  "Dead in the Dust" — investigation locations + escape-room challenges
//

import SwiftUI

struct MurderMysteryLocationsView: View {
    @ObservedObject var store: MurderMysteryStore

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(MurderMysteryData.locations) { location in
                    if location.unlocksWeek <= store.currentWeek {
                        NavigationLink {
                            MMLocationDetailView(location: location, store: store)
                        } label: {
                            openLocationCard(location)
                        }
                        .buttonStyle(.plain)
                    } else {
                        lockedLocationCard(location)
                    }
                }
            }
            .padding(16)
        }
        .background(Color.background)
    }

    private func openLocationCard(_ location: InvestigationLocation) -> some View {
        let solvedCount = location.challenges.filter { store.isChallengeComplete($0.id) }.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accent)
                Text(location.name)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(solvedCount)/\(location.challenges.count) solved")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(solvedCount == location.challenges.count ? .green : .secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(location.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 6) {
                ForEach(location.challenges) { challenge in
                    mmDifficultyBadge(challenge.difficulty, solved: store.isChallengeComplete(challenge.id))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.1)))
    }

    private func lockedLocationCard(_ location: InvestigationLocation) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Unlocks Week \(location.unlocksWeek)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
        .opacity(0.6)
    }
}

// MARK: - Shared badge

@ViewBuilder
func mmDifficultyBadge(_ difficulty: ChallengeDifficulty, solved: Bool) -> some View {
    HStack(spacing: 3) {
        if solved {
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .bold))
        }
        Text(difficulty.label)
            .font(.caption2.weight(.bold))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(Capsule().fill(difficulty.badgeColor.opacity(solved ? 0.35 : 0.18)))
    .foregroundStyle(difficulty.badgeColor)
}

// MARK: - Location detail

struct MMLocationDetailView: View {
    let location: InvestigationLocation
    @ObservedObject var store: MurderMysteryStore

    var body: some View {
        ThemedScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(location.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(location.challenges) { challenge in
                        MMChallengeCard(challenge: challenge, store: store)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Challenge card

struct MMChallengeCard: View {
    let challenge: Challenge
    @ObservedObject var store: MurderMysteryStore

    @State private var textAnswer = ""
    @State private var selectedOption: String?
    @State private var feedback: Feedback?

    private enum Feedback {
        case correct, wrong
    }

    private var isSolved: Bool { store.isChallengeComplete(challenge.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(challenge.name)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                mmDifficultyBadge(challenge.difficulty, solved: isSolved)
                Text("\(challenge.points) pts")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.accent)
            }

            Text(challenge.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if isSolved {
                solvedView
            } else {
                puzzleView
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(isSolved ? Color.green.opacity(0.4) : Color.white.opacity(0.1)))
    }

    // MARK: - Solved

    private var solvedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Solved", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.green)
            Text(challenge.rewardText)
                .font(.footnote)
                .foregroundStyle(Color.textPrimary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.1)))
        }
    }

    // MARK: - Puzzle

    @ViewBuilder
    private var puzzleView: some View {
        switch challenge.type {
        case .multipleChoice(let options):
            VStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selectedOption = option
                        feedback = nil
                    } label: {
                        HStack {
                            Image(systemName: selectedOption == option ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(selectedOption == option ? Color.accent : .secondary)
                            Text(option)
                                .font(.subheadline)
                                .foregroundStyle(Color.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(selectedOption == option ? 0.12 : 0.05)))
                    }
                    .buttonStyle(.plain)
                }
            }
            submitButton(enabled: selectedOption != nil) {
                submit(selectedOption ?? "")
            }

        case .textInput(let placeholder, let hint):
            TextField(placeholder, text: $textAnswer)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.subheadline.monospaced())
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                .onChange(of: textAnswer) { _, _ in feedback = nil }
            Text("Hint: \(hint)")
                .font(.caption)
                .foregroundStyle(.secondary)
            submitButton(enabled: !textAnswer.trimmingCharacters(in: .whitespaces).isEmpty) {
                submit(textAnswer)
            }
        }

        if let feedback {
            feedbackBanner(feedback)
        }
    }

    private func submitButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Submit")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(enabled ? Color.accent : Color.white.opacity(0.1)))
                .foregroundStyle(enabled ? Color.black : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func submit(_ answer: String) {
        if challenge.isCorrect(answer) {
            store.markChallengeComplete(id: challenge.id, pts: challenge.points)
            feedback = .correct
        } else {
            feedback = .wrong
        }
    }

    private func feedbackBanner(_ feedback: Feedback) -> some View {
        let correct = feedback == .correct
        return HStack(spacing: 8) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(correct ? "Correct! +\(challenge.points) pts" : "Not quite. Check the drops again.")
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(correct ? .green : .red)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill((correct ? Color.green : Color.red).opacity(0.12)))
    }
}
