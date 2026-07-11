//
//  UnfinalizedChallengesAdminView.swift
//  Best Man Challenge
//
//  Admin hub for past challenges that haven't been finalized yet.
//  Shows challenges where is_finalized == false and end_date < now.
//  Each challenge routes to the appropriate grading UI based on type.
//

import SwiftUI
import FirebaseFirestore

// MARK: - Root list

struct UnfinalizedChallengesAdminView: View {

    @State private var challenges: [WeeklyChallenge] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let gold = Color(red: 0.82, green: 0.66, blue: 0.22)

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading…")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if let err = errorMessage {
                Text(err).foregroundStyle(.red)
            } else if challenges.isEmpty {
                ContentUnavailableView(
                    "All caught up!",
                    systemImage: "checkmark.seal.fill",
                    description: Text("No past challenges are waiting to be finalized.")
                )
            } else {
                Section {
                    ForEach(challenges) { challenge in
                        NavigationLink {
                            PastChallengeAdminDetailView(challenge: challenge)
                        } label: {
                            challengeRow(challenge)
                        }
                    }
                } header: {
                    Text("\(challenges.count) challenge\(challenges.count == 1 ? "" : "s") need attention")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .navigationTitle("Past Challenges")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await load() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task { await load() }
    }

    // MARK: - Row

    private func challengeRow(_ challenge: WeeklyChallenge) -> some View {
        HStack(spacing: 12) {
            // Week badge
            Text("W\(challenge.week)")
                .font(.caption.bold())
                .foregroundStyle(gold)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(gold.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(gold.opacity(0.35), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(challenge.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                HStack(spacing: 6) {
                    typePill(challenge.type)
                    actionCountPill(challenge)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func typePill(_ type: ChallengeType) -> some View {
        Text(type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption2)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color.secondary.opacity(0.12))
            .foregroundStyle(.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func actionCountPill(_ challenge: WeeklyChallenge) -> some View {
        let count = adminActionCount(challenge)
        return Text("\(count) action\(count == 1 ? "" : "s")")
            .font(.caption2)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color.orange.opacity(0.15))
            .foregroundStyle(.orange)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func adminActionCount(_ challenge: WeeklyChallenge) -> Int {
        switch challenge.type {
        case .photo_challenge: return 2   // grade + pick winners
        case .prop_bets:       return 1
        case .scavenger_hunt:  return 1
        default:               return 1
        }
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch all challenges from W23 onwards, filter client-side
            let snap = try await Firestore.firestore()
                .collection("weekly_challenges")
                .whereField("weekInt", isGreaterThanOrEqualTo: 23)
                .order(by: "weekInt", descending: true)
                .getDocuments()

            let now = Date()
            let parsed = snap.documents
                .compactMap { WeeklyChallengeManager.parseWeeklyChallenge(doc: $0) }
                .filter { challenge in
                    let isFinalized = challenge.is_finalized ?? false
                    let isPast      = challenge.endDate.map { $0 < now } ?? false
                    return !isFinalized && isPast
                }

            challenges = parsed
            isLoading  = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading    = false
        }
    }
}

// MARK: - Detail: admin actions for a single past challenge

struct PastChallengeAdminDetailView: View {
    let challenge: WeeklyChallenge

    private let gold = Color(red: 0.82, green: 0.66, blue: 0.22)

    var body: some View {
        List {
            // Challenge info banner
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(challenge.title)
                        .font(.headline)
                    if !challenge.description.isEmpty {
                        Text(challenge.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        typePill(challenge.type)
                        Text("Not finalized")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)

            // Admin actions
            Section("Admin Actions") {
                adminActions
            }
            .listRowBackground(Color.white.opacity(0.06))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .navigationTitle("W\(challenge.week) Admin")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var adminActions: some View {
        switch challenge.type {

        case .photo_challenge:
            NavigationLink {
                PhotoChallengeGraderView(challenge: challenge)
            } label: {
                actionRow(
                    title: "Grade Submissions",
                    subtitle: "Mark each photo Valid or Invalid",
                    icon: "checkmark.seal",
                    color: .green
                )
            }
            NavigationLink {
                PhotoChallengeAdminView(challenge: challenge)
            } label: {
                actionRow(
                    title: "Select Photo Winners",
                    subtitle: "Pick the winner for each prompt",
                    icon: "trophy.fill",
                    color: .yellow
                )
            }

        case .prop_bets:
            NavigationLink {
                PropBetsAdminGradingView(challenge: challenge)
            } label: {
                actionRow(
                    title: "Grade Props",
                    subtitle: "Set correct answers and finalize picks",
                    icon: "list.clipboard.fill",
                    color: .blue
                )
            }

        case .scavenger_hunt:
            NavigationLink {
                ScavengerHuntAdminView(challenge: challenge)
            } label: {
                actionRow(
                    title: "Grade Submissions",
                    subtitle: "Mark scavenger hunt items Valid or Invalid",
                    icon: "checkmark.seal",
                    color: .green
                )
            }

        default:
            Text("No admin tools available for this challenge type.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        }
    }

    // MARK: - Helpers

    private func actionRow(title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func typePill(_ type: ChallengeType) -> some View {
        Text(type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption2)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Color.secondary.opacity(0.12))
            .foregroundStyle(.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
