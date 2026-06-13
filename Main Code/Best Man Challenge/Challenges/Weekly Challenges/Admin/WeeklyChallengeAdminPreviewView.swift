//
//  WeeklyChallengeAdminPreviewView.swift
//  Best Man Challenge
//
//  Admin test/preview: opens any weekly challenge game engine regardless of is_active.
//

import SwiftUI
import FirebaseAuth

struct WeeklyChallengeAdminPreviewView: View {
    let challenge: WeeklyChallenge
    @EnvironmentObject var session: SessionStore

    // Fresh manager in preview mode (no Firestore listener started)
    @StateObject private var manager = WeeklyChallengeManager(autoStart: false)

    @State private var showWordle           = false
    @State private var showMultiWordle      = false
    @State private var showPhotoChallenge   = false
    @State private var showScavengerHunt    = false
    @State private var showConnections      = false
    @State private var showQuiz             = false
    @State private var showImageQuiz        = false
    @State private var showPropBets         = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Hidden NavigationLinks (old API — works inside NavigationView)
                navLinks

                // Info header
                adminHeaderCard

                // Game launch button
                launchSection

                Text("⚠️ Preview mode — submissions go to Firestore like normal. Useful for testing engines before a week goes live.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("W\(challenge.week) Preview")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            manager.previewChallenge(challenge)
            manager.setUserContext(
                uid: Auth.auth().currentUser?.uid,
                linkedPlayerId: session.profile?.linkedPlayerId,
                displayName: session.profile?.displayName
            )
        }
    }

    // MARK: - Hidden NavigationLinks (NavigationView-compatible)

    @ViewBuilder
    private var navLinks: some View {
        Group {
            NavigationLink(destination:
                WordleView(
                    challengeId: challenge.id,
                    prompt: challenge.title,
                    answer: challenge.wordleAnswer,
                    wordLength: challenge.wordleWordLength,
                    maxAttempts: challenge.wordleMaxAttempts,
                    isLocked: false
                )
                .environmentObject(manager),
                isActive: $showWordle
            ) { EmptyView() }

            NavigationLink(destination:
                MultiWordleView(challenge: challenge)
                    .environmentObject(manager)
                    .environmentObject(session),
                isActive: $showMultiWordle
            ) { EmptyView() }

            NavigationLink(destination:
                PhotoChallengeView(challenge: challenge)
                    .environmentObject(session),
                isActive: $showPhotoChallenge
            ) { EmptyView() }

            NavigationLink(destination:
                ScavengerHuntView(challenge: challenge)
                    .environmentObject(session),
                isActive: $showScavengerHunt
            ) { EmptyView() }

            NavigationLink(destination:
                ConnectionsView(challenge: challenge)
                    .environmentObject(session),
                isActive: $showConnections
            ) { EmptyView() }

            NavigationLink(destination:
                WeeklyQuizPlayView(challenge: challenge, manager: manager),
                isActive: $showQuiz
            ) { EmptyView() }

            NavigationLink(destination:
                WeeklyImageQuizPlayView(challenge: challenge, manager: manager)
                    .environmentObject(session),
                isActive: $showImageQuiz
            ) { EmptyView() }

            NavigationLink(destination:
                PropBetsView(challengeId: challenge.id),
                isActive: $showPropBets
            ) { EmptyView() }
        }
        // Hidden — zero size
        .frame(width: 0, height: 0)
        .hidden()
    }

    // MARK: - Admin info card

    private var adminHeaderCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Week \(challenge.week)")
                    .font(.headline)
                Spacer()
                Text(challenge.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            Text(challenge.title).font(.title3.bold())
            Text(challenge.description).font(.subheadline).foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if let start = challenge.startDate {
                    infoChip("Starts", start.formatted(date: .abbreviated, time: .omitted))
                }
                if let end = challenge.endDate {
                    infoChip("Ends", end.formatted(date: .abbreviated, time: .omitted))
                }
                infoChip("ID", challenge.id)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func infoChip(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.bold()).lineLimit(1)
        }
    }

    // MARK: - Launch section

    @ViewBuilder
    private var launchSection: some View {
        VStack(spacing: 10) {
            switch challenge.type {
            case .wordle, .riddle where challenge.isWordle:
                launchButton("Play Wordle", icon: "w.circle.fill") { showWordle = true }

            case .multi_wordle:
                launchButton("Play Triple Wordle", icon: "w.circle.fill") { showMultiWordle = true }

            case .photo_challenge:
                launchButton("Open Photo Challenge", icon: "camera.fill") { showPhotoChallenge = true }

            case .scavenger_hunt:
                launchButton("Open Scavenger Hunt", icon: "map.fill") { showScavengerHunt = true }

            case .connections:
                launchButton("Play Connections", icon: "square.grid.2x2.fill") { showConnections = true }

            case .quiz, .riddle:
                launchButton("Start Quiz", icon: "questionmark.circle.fill") { showQuiz = true }

            case .image_quiz:
                launchButton("Start Image Quiz", icon: "photo.fill") { showImageQuiz = true }

            case .prop_bets:
                launchButton("Make Picks", icon: "die.face.3.fill") { showPropBets = true }

            case .creative:
                Text("Creative submission engine not yet built.")
                    .font(.subheadline).foregroundStyle(.secondary).padding()

            case .minesweeper:
                Text("Minesweeper engine not yet built.")
                    .font(.subheadline).foregroundStyle(.secondary).padding()
            }
        }
        .padding(.horizontal)
    }

    private func launchButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}
