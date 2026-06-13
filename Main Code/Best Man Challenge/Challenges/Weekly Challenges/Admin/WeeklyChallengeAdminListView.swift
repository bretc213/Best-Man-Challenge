//
//  WeeklyChallengeAdminListView.swift
//  Best Man Challenge
//
//  Admin-only: browse all W24–W50 challenges and open them in test/preview mode.
//

import SwiftUI
import FirebaseFirestore

struct WeeklyChallengeAdminListView: View {
    @EnvironmentObject var session: SessionStore

    @State private var challenges: [WeeklyChallenge] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading challenges…")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if let err = errorMessage {
                Text(err).foregroundStyle(.red)
            } else {
                ForEach(challenges) { challenge in
                    NavigationLink {
                        WeeklyChallengeAdminPreviewView(challenge: challenge)
                            .environmentObject(session)
                    } label: {
                        rowLabel(challenge)
                    }
                }
            }
        }
        .navigationTitle("Challenge Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await loadChallenges() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task { await loadChallenges() }
    }

    // MARK: - Row

    private func rowLabel(_ challenge: WeeklyChallenge) -> some View {
        HStack(spacing: 12) {
            // Week badge
            Text("W\(challenge.week)")
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(badgeColor(challenge).opacity(0.18))
                .foregroundStyle(badgeColor(challenge))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(challenge.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                HStack(spacing: 6) {
                    typePill(challenge.type)
                    if challenge.is_active == true {
                        Text("LIVE")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
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

    private func badgeColor(_ challenge: WeeklyChallenge) -> Color {
        if challenge.is_active == true { return .green }
        switch challenge.type {
        case .wordle, .multi_wordle:  return .blue
        case .connections:            return .purple
        case .photo_challenge:        return .orange
        case .scavenger_hunt:         return .mint
        case .prop_bets:              return .red
        case .quiz, .image_quiz:      return .indigo
        default:                      return .secondary
        }
    }

    // MARK: - Load

    private func loadChallenges() async {
        isLoading = true
        errorMessage = nil

        do {
            let snap = try await Firestore.firestore()
                .collection("weekly_challenges")
                .whereField("weekInt", isGreaterThanOrEqualTo: 24)
                .whereField("weekInt", isLessThanOrEqualTo: 50)
                .order(by: "weekInt")
                .getDocuments()

            let parsed = snap.documents.compactMap { doc in
                WeeklyChallengeManager.parseWeeklyChallenge(doc: doc)
            }

            challenges = parsed
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
