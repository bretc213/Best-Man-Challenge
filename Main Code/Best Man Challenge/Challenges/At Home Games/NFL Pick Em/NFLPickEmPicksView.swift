//
//  NFLPickEmPicksView.swift
//  Best Man Challenge
//

import SwiftUI
import FirebaseAuth

struct NFLPickEmPicksView: View {
    @ObservedObject var store: NFLPickEmStore
    let session: SessionStore

    @State private var selectedWeek: Int = 1
    @State private var toastMessage: String? = nil
    @State private var showToast = false

    private var weekGames: [NFLPickEmGame] {
        store.games(for: selectedWeek)
    }

    private var availableWeeks: [Int] {
        store.availableWeeks.isEmpty ? Array(1...16) : store.availableWeeks
    }

    var body: some View {
        VStack(spacing: 0) {
            // Week Selector
            weekSelectorBar

            if store.isLoading {
                Spacer()
                ProgressView("Loading games…")
                Spacer()
            } else if weekGames.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Games Yet",
                    systemImage: "football",
                    description: Text("Week \(selectedWeek) games haven't been posted yet.")
                )
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        picksHeader
                        ForEach(weekGames) { game in
                            GamePickCard(
                                game: game,
                                myPick: store.myPicks[game.id],
                                onPick: { teamId in
                                    Task { await submitPick(gameId: game.id, teamId: teamId) }
                                }
                            )
                        }

                        weekSummaryRow
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }
        }
        .onAppear {
            selectedWeek = store.currentWeek
        }
        .overlay(toastOverlay, alignment: .bottom)
    }

    // MARK: - Week Selector

    private var weekSelectorBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(availableWeeks, id: \.self) { week in
                        Button {
                            withAnimation { selectedWeek = week }
                        } label: {
                            Text("Wk \(week)")
                                .font(.caption.weight(selectedWeek == week ? .bold : .regular))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    selectedWeek == week
                                    ? Color.accentColor
                                    : Color(UIColor.secondarySystemBackground)
                                )
                                .foregroundStyle(selectedWeek == week ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .id(week)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(UIColor.systemBackground))
            .onChange(of: selectedWeek) { _, week in
                withAnimation { proxy.scrollTo(week, anchor: .center) }
            }
            .onAppear {
                proxy.scrollTo(selectedWeek, anchor: .center)
            }
        }
    }

    // MARK: - Header

    private var picksHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Week \(selectedWeek) Picks")
                .font(.title3.bold())
            Text("Pick before each game kicks off. Each correct pick = 1 point.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - Week Summary

    private var weekSummaryRow: some View {
        let finalGames = weekGames.filter { $0.isFinal }
        let myId = session.profile?.linkedPlayerId ?? ""
        let correct = finalGames.filter { game in
            guard let winner = game.winnerId else { return false }
            return store.myPicks[game.id] == winner
        }.count
        let picked = weekGames.filter { store.myPicks[$0.id] != nil }.count

        return Group {
            if !finalGames.isEmpty || picked > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Week \(selectedWeek) Summary")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if finalGames.isEmpty {
                            Text("\(picked)/\(weekGames.count) picks submitted")
                                .font(.subheadline)
                        } else {
                            Text("\(correct)/\(finalGames.count) correct · \(picked)/\(weekGames.count) picked")
                                .font(.subheadline)
                        }
                    }
                    Spacer()

                    if let row = store.scoreRows.first(where: { $0.linkedPlayerId == myId }),
                       row.weekWins.contains(selectedWeek) {
                        Label("Week Winner", systemImage: "trophy.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.yellow)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if showToast, let msg = toastMessage {
            Text(msg)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Material.thick)
                .clipShape(Capsule())
                .shadow(radius: 4)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Actions

    @MainActor
    private func submitPick(gameId: String, teamId: String) async {
        do {
            try await store.setPick(gameId: gameId, teamId: teamId)
            showToast("Pick saved ✓")
        } catch let error as PickEmError {
            showToast(error.localizedDescription)
        } catch {
            showToast("Failed to save pick")
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showToast = false }
        }
    }
}

// MARK: - Game Pick Card

struct GamePickCard: View {
    let game: NFLPickEmGame
    let myPick: String?
    let onPick: (String) -> Void

    private var isLocked: Bool { game.isLocked }
    private var winnerId: String? { game.winnerId }

    var body: some View {
        VStack(spacing: 10) {
            // Header row: time + lock status
            HStack {
                Text(kickoffString)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if winnerId != nil {
                    Label("Final", systemImage: "checkmark.seal.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                } else if isLocked {
                    Text("LOCKED")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                } else {
                    Text("Locks at kickoff")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Team buttons
            HStack(spacing: 12) {
                teamButton(team: game.awayTeam, role: "Away")
                VStack(spacing: 2) {
                    Text("@")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("vs")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                teamButton(team: game.homeTeam, role: "Home")
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .opacity(isLocked && myPick == nil ? 0.8 : 1.0)
    }

    private func teamButton(team: NFLPickEmTeam, role: String) -> some View {
        let isSelected = myPick == team.id
        let hasWinner = winnerId != nil
        let isCorrect = hasWinner && isSelected && myPick == winnerId
        let isWrong = hasWinner && isSelected && myPick != winnerId
        let isWinner = winnerId == team.id

        let bg: Color = {
            if isCorrect { return .green.opacity(0.25) }
            if isWrong   { return .red.opacity(0.20) }
            if isWinner && !isSelected { return .green.opacity(0.10) }
            if isSelected { return .accentColor.opacity(0.15) }
            return Color(UIColor.systemBackground)
        }()

        let borderColor: Color = {
            if isCorrect { return .green.opacity(0.6) }
            if isWrong   { return .red.opacity(0.5) }
            if isWinner  { return .green.opacity(0.4) }
            if isSelected { return .accentColor.opacity(0.4) }
            return .clear
        }()

        return Button {
            guard !isLocked else { return }
            onPick(team.id)
        } label: {
            VStack(spacing: 6) {
                // Logo
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(bg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(borderColor, lineWidth: 1.5)
                        )

                    if UIImage(named: team.logoAsset) != nil {
                        Image(team.logoAsset)
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                    } else {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }

                    // Checkmark overlay
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16))
                                .foregroundStyle(isSelected ? Color.accentColor : .secondary.opacity(0.4))
                                .padding(6)
                        }
                        Spacer()
                    }
                }
                .frame(width: 110, height: 80)

                // Team name
                Text(team.nickname)
                    .font(.caption.weight(isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Role label
                Text(role)
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .frame(maxWidth: .infinity)
    }

    private var kickoffString: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d · h:mm a"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f.string(from: game.kickoffTime) + " ET"
    }
}
