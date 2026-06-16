//
//  NFLPickEmAdminView.swift
//  Best Man Challenge
//
//  Admin panel: enter game results, award weekly BMC bonus, add/edit games.
//

import SwiftUI

struct NFLPickEmAdminView: View {
    @ObservedObject var store: NFLPickEmStore
    let session: SessionStore

    @State private var selectedWeek: Int = 1
    @State private var isWorking = false
    @State private var alertMessage: String? = nil
    @State private var showAlert = false
    @State private var showAddGame = false

    private var weekGames: [NFLPickEmGame] {
        store.games(for: selectedWeek).sorted { $0.kickoffTime < $1.kickoffTime }
    }

    private var allWeeks: [Int] {
        store.availableWeeks.isEmpty ? Array(1...16) : store.availableWeeks
    }

    private var bonusApplied: Bool {
        store.appliedWeekBonuses.contains(selectedWeek)
    }

    private var weekFullyDecided: Bool {
        let games = weekGames
        return !games.isEmpty && games.allSatisfy { $0.isFinal }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                adminHeader
                weekSelector
                bonusSection
                gamesSection
                addGameButton
                NFLPickEmSeederView(store: store)
            }
            .padding()
        }
        .alert("Result", isPresented: $showAlert, presenting: alertMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
        .sheet(isPresented: $showAddGame) {
            AddGameSheet(week: selectedWeek, store: store) {
                showAddGame = false
            }
        }
    }

    // MARK: - Subviews

    private var adminHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Admin — NFL Pick 'Em")
                    .font(.title3.bold())
                Text("Enter results · Award bonuses · Manage games")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var weekSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(allWeeks, id: \.self) { week in
                    Button {
                        selectedWeek = week
                    } label: {
                        let hasDecided = store.games(for: week).contains { $0.isFinal }
                        Text("Wk \(week)")
                            .font(.caption.weight(selectedWeek == week ? .bold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedWeek == week ? Color.accentColor :
                                hasDecided ? Color.green.opacity(0.15) :
                                Color(UIColor.secondarySystemBackground)
                            )
                            .foregroundStyle(selectedWeek == week ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var bonusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Week \(selectedWeek) BMC Bonus")
                .font(.headline)

            if bonusApplied {
                Label("Bonus already applied for Week \(selectedWeek)", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            } else if weekFullyDecided {
                VStack(alignment: .leading, spacing: 6) {
                    // Preview winners
                    let weekRows = weekScorePreview()
                    if !weekRows.isEmpty {
                        let maxScore = weekRows.map { $0.correct }.max() ?? 0
                        let winners = weekRows.filter { $0.correct == maxScore }

                        Text("Winner\(winners.count > 1 ? "s" : ""): \(winners.map { $0.name }.joined(separator: ", "))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("\(maxScore) correct picks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        Task { await applyBonus() }
                    } label: {
                        Label(
                            isWorking ? "Applying…" : "Apply +1 BMC Bonus Point",
                            systemImage: "trophy.fill"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking)
                }
            } else {
                Text("All Week \(selectedWeek) games must be final before awarding the bonus.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Week \(selectedWeek) Games")
                .font(.headline)

            if weekGames.isEmpty {
                Text("No games seeded for Week \(selectedWeek) yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(weekGames) { game in
                    AdminGameRow(game: game, store: store)
                }
            }
        }
    }

    private var addGameButton: some View {
        Button {
            showAddGame = true
        } label: {
            Label("Add Game to Week \(selectedWeek)", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Helpers

    private func weekScorePreview() -> [(name: String, correct: Int)] {
        let finalGames = weekGames.filter { $0.isFinal }
        return store.allEntries.map { entry in
            let correct = finalGames.filter { g in
                guard let w = g.winnerId else { return false }
                return entry.picks[g.id] == w
            }.count
            return (entry.displayName, correct)
        }
        .sorted { $0.correct > $1.correct }
    }

    private func applyBonus() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await store.applyWeeklyBonus(week: selectedWeek)
            alertMessage = "Week \(selectedWeek) bonus applied! Winners earned +1 BMC point."
        } catch {
            alertMessage = "Error: \(error.localizedDescription)"
        }
        showAlert = true
    }
}

// MARK: - Admin Game Row

private struct AdminGameRow: View {
    let game: NFLPickEmGame
    @ObservedObject var store: NFLPickEmStore

    @State private var isSettingWinner = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(kickoffString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if game.isFinal {
                    Text("FINAL")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                } else if game.isLocked {
                    Text("IN PROGRESS")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                } else {
                    Text("Upcoming")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                // Away
                ResultButton(
                    label: game.awayTeam.nickname,
                    logoAsset: game.awayTeam.logoAsset,
                    isWinner: game.winnerId == game.awayTeam.id
                ) {
                    Task { await setWinner(game.awayTeam.id) }
                }

                Text("@")
                    .foregroundStyle(.secondary)
                    .font(.caption.weight(.semibold))

                // Home
                ResultButton(
                    label: game.homeTeam.nickname,
                    logoAsset: game.homeTeam.logoAsset,
                    isWinner: game.winnerId == game.homeTeam.id
                ) {
                    Task { await setWinner(game.homeTeam.id) }
                }

                // Clear result
                if game.isFinal {
                    Button {
                        Task { await setWinner(nil) }
                    } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func setWinner(_ teamId: String?) async {
        guard !isSettingWinner else { return }
        isSettingWinner = true
        defer { isSettingWinner = false }
        do {
            try await store.setWinner(gameId: game.id, winnerId: teamId)
        } catch {
            print("❌ setWinner error:", error)
        }
    }

    private var kickoffString: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d · h:mm a"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f.string(from: game.kickoffTime) + " ET"
    }
}

private struct ResultButton: View {
    let label: String
    let logoAsset: String
    let isWinner: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if UIImage(named: logoAsset) != nil {
                    Image(logoAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                }
                Text(label)
                    .font(.caption.weight(isWinner ? .bold : .regular))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                isWinner
                ? Color.green.opacity(0.20)
                : Color(UIColor.secondarySystemBackground)
            )
            .foregroundStyle(isWinner ? .green : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(isWinner ? Color.green.opacity(0.5) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Game Sheet

struct AddGameSheet: View {
    let week: Int
    @ObservedObject var store: NFLPickEmStore
    let onDone: () -> Void

    @State private var awayTeamId: String = ""
    @State private var homeTeamId: String = ""
    @State private var kickoffDate: Date = Date()
    @State private var isSaving = false
    @State private var errorMsg: String? = nil

    private let teams = NFLPickEmTeam.allTeams.sorted { $0.fullName < $1.fullName }

    var body: some View {
        NavigationView {
            Form {
                Section("Week \(week) Game Details") {
                    Picker("Away Team", selection: $awayTeamId) {
                        Text("Select").tag("")
                        ForEach(teams) { team in
                            Text(team.fullName).tag(team.id)
                        }
                    }

                    Picker("Home Team", selection: $homeTeamId) {
                        Text("Select").tag("")
                        ForEach(teams) { team in
                            Text(team.fullName).tag(team.id)
                        }
                    }

                    DatePicker("Kickoff (ET)", selection: $kickoffDate, displayedComponents: [.date, .hourAndMinute])
                }

                if let err = errorMsg {
                    Section {
                        Text(err).foregroundStyle(.red)
                    }
                }

                Section {
                    Button(isSaving ? "Saving…" : "Add Game") {
                        Task { await saveGame() }
                    }
                    .disabled(awayTeamId.isEmpty || homeTeamId.isEmpty || awayTeamId == homeTeamId || isSaving)
                }
            }
            .navigationTitle("Add Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone() }
                }
            }
        }
    }

    private func saveGame() async {
        guard !awayTeamId.isEmpty, !homeTeamId.isEmpty,
              let awayTeam = NFLPickEmTeam.team(for: awayTeamId),
              let homeTeam = NFLPickEmTeam.team(for: homeTeamId)
        else {
            errorMsg = "Please select both teams."
            return
        }

        guard awayTeamId != homeTeamId else {
            errorMsg = "Away and home teams must be different."
            return
        }

        isSaving = true
        defer { isSaving = false }

        // Build a deterministic gameId
        let dateStr = ISO8601DateFormatter().string(from: kickoffDate).prefix(10)
        let gameId = "2026_w\(String(format: "%02d", week))_\(awayTeamId)_\(homeTeamId)"

        let game = NFLPickEmGame(
            id: gameId,
            week: week,
            awayTeam: awayTeam,
            homeTeam: homeTeam,
            kickoffTime: kickoffDate,
            winnerId: nil
        )

        do {
            try await store.upsertGame(game)
            onDone()
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
