//
//  HalfwayChallengeView.swift
//  Best Man Challenge
//
//  Hub for Week 25 — shows all 5 rounds with lock/unlock state.
//  Complete a round to unlock the next one.
//

import SwiftUI

struct HalfwayChallengeView: View {
    let challenge: WeeklyChallenge

    @StateObject private var store = HalfwayChallengeStore()
    @EnvironmentObject var session: SessionStore

    @State private var showResetConfirm = false

    private var isOwner: Bool {
        session.profile?.role == "owner" || session.profile?.role == "commish"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                headerCard

                // Score progress
                progressCard

                // Round list
                ForEach(store.rounds) { round in
                    roundCard(round)
                }

                // Owner reset button
                if isOwner {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Reset My Test Submissions", systemImage: "arrow.counterclockwise")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                }
            }
            .padding()
        }
        .navigationTitle("Halfway Point 🏆")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.load(challenge: challenge) }
        .onDisappear { store.stop() }
        .confirmationDialog("Reset all progress for this challenge?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset My Submissions", role: .destructive) {
                Task { await store.resetMySubmissions() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes your game_state and submission doc. Use for testing only.")
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Week 25: Halfway Point Challenge")
                .font(.title2.bold())
            Text("Five mini-games. Complete each to unlock the next. 6 pts per round — 30 pts total.")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Progress

    private var progressCard: some View {
        let done = store.completedRounds.count
        let total = store.rounds.count

        return VStack(spacing: 10) {
            HStack {
                Text("\(done)/\(total) Rounds Complete")
                    .font(.headline)
                Spacer()
                Text("\(store.score) pts")
                    .font(.headline)
                    .foregroundStyle(.yellow)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.yellow)
                        .frame(width: total > 0 ? geo.size.width * CGFloat(done) / CGFloat(total) : 0,
                               height: 10)
                        .animation(.easeInOut, value: done)
                }
            }
            .frame(height: 10)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Round card

    @ViewBuilder
    private func roundCard(_ round: HalfwayRound) -> some View {
        let isComplete = store.completedRounds.contains(round.id)
        let isUnlocked = store.isUnlocked(round)

        NavigationLink {
            destinationView(for: round)
        } label: {
            HStack(spacing: 14) {
                // Icon / status
                ZStack {
                    Circle()
                        .fill(isComplete ? Color.green.opacity(0.2) :
                              isUnlocked ? Color.accentColor.opacity(0.15) :
                              Color.secondary.opacity(0.1))
                        .frame(width: 52, height: 52)
                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    } else if isUnlocked {
                        Text(round.emoji)
                            .font(.title2)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Round \(round.position)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if isComplete {
                            Text("DONE")
                                .font(.caption2.bold())
                                .foregroundStyle(.green)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    Text(round.title)
                        .font(.headline)
                        .foregroundStyle(isUnlocked || isComplete ? .primary : .secondary)
                    Text(round.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if isUnlocked && !isComplete {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }
            .padding(14)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .opacity(isUnlocked || isComplete ? 1 : 0.5)
        }
        .disabled(!isUnlocked || isComplete)
        .buttonStyle(.plain)
    }

    // MARK: - Navigation destinations

    @ViewBuilder
    private func destinationView(for round: HalfwayRound) -> some View {
        switch round.id {
        case "round1":
            RideTheBusView(challenge: challenge, store: store)
        case "round2":
            BlackjackView(challenge: challenge, store: store)
        case "round3":
            YahtzeeLiteView(challenge: challenge, store: store)
        case "round4":
            MemoryGameView(challenge: challenge, store: store)
        case "round5":
            MastermindView(challenge: challenge, store: store)
        default:
            Text("Unknown round").navigationTitle(round.title)
        }
    }
}
