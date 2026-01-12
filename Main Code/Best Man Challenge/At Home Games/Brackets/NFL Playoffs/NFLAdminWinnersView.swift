//
//  NFLAdminWinnersView.swift
//  Best Man Challenge
//
//  Admin tool: set/clear winners for matchups.
//

import SwiftUI
import FirebaseFirestore

struct NFLAdminWinnersView: View {
    @ObservedObject var store: NFLPlayoffsPicksStore
    let session: SessionStore

    @State private var selectedRound: BracketRound = .wildcard
    @State private var isSaving: Bool = false
    @State private var toast: String?

    private let rounds: [BracketRound] = [.wildcard, .divisional, .conference, .superBowl]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Admin")
                .font(.title2.bold())

            Text("Set winners to score everyone’s picks. Updates should reflect in the leaderboard immediately.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Picker("Round", selection: $selectedRound) {
                ForEach(rounds, id: \.self) { r in
                    Text(roundTitle(r)).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .onAppear {
                selectedRound = BracketRound(rawValue: store.roundId) ?? .wildcard
            }
            .onChange(of: selectedRound) { _, newValue in
                store.setRound(newValue.rawValue)
            }

            if let msg = toast {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.isLoading {
                ProgressView("Loading matchups...")
                    .padding(.top, 8)

            } else if let err = store.errorMessage {
                Text("Couldn’t load: \(err)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

            } else if store.matchups.isEmpty {
                Text("No matchups found for this round.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(store.matchups, id: \.id) { matchup in
                            AdminMatchupWinnerCard(
                                matchup: matchup,
                                isSaving: isSaving,
                                onSetWinner: { teamId in
                                    Task { await setWinner(matchup: matchup, winnerTeamId: teamId) }
                                },
                                onClearWinner: {
                                    Task { await clearWinner(matchup: matchup) }
                                }
                            )
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }
            }
        }
        .padding(.top, 8)
        .padding(.horizontal)
    }

    // MARK: - Firestore writes

    @MainActor
    private func setWinner(matchup: BracketMatchup, winnerTeamId: String) async {
        guard !winnerTeamId.isEmpty else { return }
        isSaving = true
        toast = nil

        do {
            let db = Firestore.firestore()
            try await db.collection("brackets")
                .document(store.bracketId)
                .collection("matchups")
                .document(matchup.id)
                .setData(
                    [
                        "winnerTeamId": winnerTeamId,
                        "decidedAt": Timestamp(date: Date())
                    ],
                    merge: true
                )

            toast = "Saved winner for game \(matchup.index)."
        } catch {
            toast = "Failed to save: \(error.localizedDescription)"
        }

        isSaving = false
    }

    @MainActor
    private func clearWinner(matchup: BracketMatchup) async {
        isSaving = true
        toast = nil

        do {
            let db = Firestore.firestore()
            try await db.collection("brackets")
                .document(store.bracketId)
                .collection("matchups")
                .document(matchup.id)
                .setData(
                    [
                        "winnerTeamId": FieldValue.delete(),
                        "decidedAt": FieldValue.delete()
                    ],
                    merge: true
                )

            toast = "Cleared winner for game \(matchup.index)."
        } catch {
            toast = "Failed to clear: \(error.localizedDescription)"
        }

        isSaving = false
    }

    private func roundTitle(_ r: BracketRound) -> String {
        switch r {
        case .wildcard: return "Wild Card"
        case .divisional: return "Divisional"
        case .conference: return "Conference"
        case .superBowl: return "Super Bowl"
        }
    }
}

// MARK: - Card

private struct AdminMatchupWinnerCard: View {
    let matchup: BracketMatchup
    let isSaving: Bool
    let onSetWinner: (String) -> Void
    let onClearWinner: () -> Void

    private var winnerId: String? { matchup.winnerTeamId }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text(matchupLabel())
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if winnerId != nil {
                    Text("WINNER SET")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.20))
                        .foregroundStyle(Color.green)
                        .clipShape(Capsule())
                } else {
                    Text("NO WINNER")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                winnerButton(team: matchup.away, isWinner: winnerId == matchup.away.id) {
                    onSetWinner(matchup.away.id)
                }

                Text("@")
                    .foregroundStyle(.secondary)

                winnerButton(team: matchup.home, isWinner: winnerId == matchup.home.id) {
                    onSetWinner(matchup.home.id)
                }
            }

            HStack {
                if let winnerId {
                    Text("Current: \(winnerName(for: winnerId))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Tap a team to set the winner.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(role: .destructive) {
                    onClearWinner()
                } label: {
                    Text("Clear")
                }
                .buttonStyle(.bordered)
                .disabled(isSaving || winnerId == nil)
            }
        }
        .cardStyle()
        .opacity(isSaving ? 0.85 : 1.0)
    }

    private func winnerButton(team: MatchupTeam, isWinner: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(isWinner ? Color.green.opacity(0.22) : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(isWinner ? 0.55 : 0.18), lineWidth: isWinner ? 2 : 1)
                    )

                Group {
                    if let asset = team.logoAsset, !asset.isEmpty {
                        Image(asset)
                            .resizable()
                            .scaledToFit()
                            .padding(14)
                    } else {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.accent)
                    }
                }

                if isWinner {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.green)
                                .padding(10)
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: 120, height: 92)
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .accessibilityLabel(Text("Set winner: \(team.name)"))
    }

    private func matchupLabel() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: matchup.startsAt)
    }

    private func winnerName(for teamId: String) -> String {
        if matchup.away.id == teamId { return matchup.away.name }
        if matchup.home.id == teamId { return matchup.home.name }
        return teamId
    }
}
