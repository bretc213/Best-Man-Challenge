//
//  ConnectionsView.swift
//  Best Man Challenge
//

import SwiftUI

struct ConnectionsView: View {
    let challenge: WeeklyChallenge
    @EnvironmentObject var session: SessionStore

    @StateObject private var store = ConnectionsStore()
    @State private var lastResult: ConnectionsAttemptResult?
    @State private var showResultBanner = false
    @State private var bannerMessage = ""
    @State private var bannerColor: Color = .green

    private var config: WeeklyChallengeConnectionsConfig? { challenge.connections_config }

    private var isLocked: Bool {
        if let end = challenge.endDate { return Date() >= end }
        return challenge.isLocked
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Result banner
                if showResultBanner {
                    bannerView
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                headerCard

                if let config {
                    scoreRow(config)
                    mistakesRow(config)
                    solvedCategories(config)
                    wordGrid(config)
                    submitButton(config)
                } else {
                    Text("Connections not configured.")
                        .foregroundStyle(.secondary)
                        .padding()
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationTitle("Connections")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let config { store.start(challengeId: challenge.id, config: config) }
        }
        .onDisappear { store.stop() }
        .alert("Error", isPresented: .init(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(challenge.title).font(.title2.bold())
            Text(challenge.description).font(.subheadline).foregroundStyle(.secondary)
            if isLocked {
                Label("Locked", systemImage: "lock.fill")
                    .font(.caption).foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Score & mistakes

    private func scoreRow(_ config: WeeklyChallengeConnectionsConfig) -> some View {
        HStack {
            Label("Score", systemImage: "star.fill")
                .font(.subheadline.bold())
            Spacer()
            Text("\(store.gameState.totalScore(with: config)) pts")
                .font(.subheadline.bold())
                .foregroundStyle(.accent)
        }
        .padding(.horizontal)
    }

    private func mistakesRow(_ config: WeeklyChallengeConnectionsConfig) -> some View {
        HStack {
            Text("Mistakes remaining:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<config.max_mistakes, id: \.self) { i in
                    Circle()
                        .fill(i < (config.max_mistakes - store.gameState.mistakesUsed) ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 12, height: 12)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Solved categories (revealed in order)

    private func solvedCategories(_ config: WeeklyChallengeConnectionsConfig) -> some View {
        VStack(spacing: 8) {
            ForEach(config.categories.sorted(by: { $0.color.order < $1.color.order })) { cat in
                if store.gameState.solvedCategoryIds.contains(cat.id) {
                    solvedCategoryBanner(cat)
                }
            }
        }
        .padding(.horizontal)
    }

    private func solvedCategoryBanner(_ cat: ConnectionsCategory) -> some View {
        VStack(spacing: 4) {
            Text(cat.name)
                .font(.headline.bold())
                .foregroundStyle(.white)
            Text(cat.words.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(colorFor(cat.color))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Word grid

    private func wordGrid(_ config: WeeklyChallengeConnectionsConfig) -> some View {
        let solved = config.categories.flatMap { cat -> [String] in
            store.gameState.solvedCategoryIds.contains(cat.id) ? cat.words : []
        }
        let remaining = store.shuffledWords.filter { !solved.contains($0) }

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                    GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 8) {
            ForEach(remaining, id: \.self) { word in
                wordTile(word, config: config)
            }
        }
        .padding(.horizontal)
    }

    private func wordTile(_ word: String, config: WeeklyChallengeConnectionsConfig) -> some View {
        let isSelected = store.gameState.selectedWords.contains(word)
        let disabled = store.isFinished || isLocked

        return Button {
            guard !disabled else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                store.toggleWord(word)
            }
        } label: {
            Text(word)
                .font(.system(size: 13, weight: .semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(isSelected ? Color.accent : Color.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .scaleEffect(isSelected ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: isSelected)
        }
        .disabled(disabled)
    }

    // MARK: - Submit button

    private func submitButton(_ config: WeeklyChallengeConnectionsConfig) -> some View {
        VStack(spacing: 8) {
            Button {
                Task { await handleSubmit(config: config) }
            } label: {
                Text(store.isSubmitting ? "Checking…" : "Submit")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.gameState.selectedWords.count != 4 || store.isSubmitting || store.isFinished || isLocked)

            if store.isFinished {
                Label(store.gameState.isSolved(with: config) ? "Puzzle Solved! 🎉" : "Game Over",
                      systemImage: store.gameState.isSolved(with: config) ? "checkmark.seal.fill" : "xmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(store.gameState.isSolved(with: config) ? .green : .red)
            }

            Button("Shuffle") {
                withAnimation { store.shuffledWords.shuffle() }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .disabled(store.isFinished)
        }
        .padding(.horizontal)
    }

    // MARK: - Result banner

    private var bannerView: some View {
        Text(bannerMessage)
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(bannerColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
    }

    // MARK: - Handle submit

    private func handleSubmit(config: WeeklyChallengeConnectionsConfig) async {
        let result = await store.submitGuess()
        switch result {
        case .correct(let cat):
            bannerMessage = "✅ \(cat.name)! +\(cat.point_value) pts"
            bannerColor = colorFor(cat.color)
        case .oneAway:
            bannerMessage = "So close! One away…"
            bannerColor = .orange
        case .wrong:
            bannerMessage = "Not quite. Try again!"
            bannerColor = .red
        case .alreadySolved:
            bannerMessage = "Already solved!"
            bannerColor = .secondary
        }

        withAnimation {
            showResultBanner = true
        }
        try? await Task.sleep(nanoseconds: 2_500_000_000)
        withAnimation {
            showResultBanner = false
        }
    }

    // MARK: - Helpers

    private func colorFor(_ color: ConnectionsColor) -> Color {
        switch color {
        case .yellow: return Color(hue: 0.14, saturation: 0.8, brightness: 0.85)
        case .green:  return Color(hue: 0.33, saturation: 0.65, brightness: 0.65)
        case .blue:   return Color(hue: 0.60, saturation: 0.70, brightness: 0.75)
        case .purple: return Color(hue: 0.78, saturation: 0.55, brightness: 0.65)
        }
    }
}
