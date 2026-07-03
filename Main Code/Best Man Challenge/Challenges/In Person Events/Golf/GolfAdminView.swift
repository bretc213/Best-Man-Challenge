//
//  GolfAdminView.swift
//  Best Man Challenge
//

import SwiftUI

struct GolfAdminView: View {
    @ObservedObject var store: GolfEventStore

    // Sim score input: playerId → text
    @State private var simInput: [String: String] = [:]
    // Scramble score input: teamId → text
    @State private var scrambleInput: [String: String] = [:]

    // Team preview (before saving) — re-flippable
    @State private var pendingRanked: [GolfSimEntry] = []
    @State private var pendingTeams: [GolfTeamAssignment] = []
    @State private var showTeamPreview = false

    @State private var isSaving = false
    @State private var isFinalizing = false
    @State private var isResetting = false
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var showResetConfirm = false

    private var state: GolfEventState { store.eventState }

    private var resetWarning: String {
        if state.isFinalized {
            return "This will:\n• Clear all sim scores, teams, and scramble scores\n• Remove BMC points from point_awards\n• Reverse player total_points on the leaderboard\n\nThis cannot be undone."
        } else {
            return "This will clear all sim scores, teams, and scramble scores. No BMC points have been awarded yet so nothing will be reversed on the leaderboard.\n\nThis cannot be undone."
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── Reset (testing) ─────────────────────────────────────
                Button {
                    showResetConfirm = true
                } label: {
                    Label(isResetting ? "Resetting…" : "Restart / Reset All Data", systemImage: "arrow.counterclockwise")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.8))
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(isResetting || isSaving || isFinalizing)
                .confirmationDialog(
                    "Reset Golf Event?",
                    isPresented: $showResetConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Yes, Reset Everything", role: .destructive) {
                        Task { await resetEvent() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(resetWarning)
                }

                Divider().padding(.horizontal)

                // ── Step 1: Sim Scores ──────────────────────────────────
                sectionHeader("1 · Simulator Scores", systemImage: "figure.golf")

                ForEach(store.allPlayers) { player in
                    HStack {
                        Text(player.displayName)
                            .font(.subheadline)
                        Spacer()
                        TextField("Score (e.g. +3 or -2)", text: bindingFor(player.id, in: $simInput))
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal)
                }

                saveSimButton

                Divider().padding(.horizontal)

                // ── Step 2: Teams ───────────────────────────────────────
                sectionHeader("2 · Teams", systemImage: "person.2.fill")

                if state.teamsGenerated {
                    teamList(state.teams)
                    reGenerateButton
                } else if !state.simScores.isEmpty {
                    generateTeamsButton
                } else {
                    Text("Save sim scores first.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
                }

                Divider().padding(.horizontal)

                // ── Step 3: Scramble Scores ─────────────────────────────
                sectionHeader("3 · Scramble Scores", systemImage: "flag.fill")

                if state.teamsGenerated {
                    ForEach(state.teams) { team in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(team.playerAName)")
                                Text("\(team.playerBName)")
                            }
                            .font(.subheadline)
                            Spacer()
                            TextField("Score", text: bindingFor(team.id, in: $scrambleInput))
                                .keyboardType(.numbersAndPunctuation)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.horizontal)
                    }
                    saveScrambleButton
                } else {
                    Text("Generate and save teams first.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
                }

                Divider().padding(.horizontal)

                // ── Step 4: Finalize ────────────────────────────────────
                sectionHeader("4 · Finalize Event", systemImage: "checkmark.seal.fill")

                if state.isFinalized {
                    Label("Event finalized", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .padding(.horizontal)
                } else if !state.scrambleScores.isEmpty && state.teamsGenerated {
                    finalizeButton
                } else {
                    Text("Complete all steps above to finalize.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
                }

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .background(Color.background)
        .onAppear { populateInputs() }
        .alert("Golf Admin", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(alertMessage ?? "") }
        .sheet(isPresented: $showTeamPreview) { teamPreviewSheet }
    }

    // MARK: - Section header

    @ViewBuilder
    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage).foregroundStyle(Color.accent)
            Text(title).font(.headline)
            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Team list

    @ViewBuilder
    private func teamList(_ teams: [GolfTeamAssignment]) -> some View {
        ForEach(teams) { team in
            HStack {
                Text(team.id.uppercased()).font(.caption.bold()).foregroundStyle(.secondary).frame(width: 28)
                Text("\(team.playerAName) & \(team.playerBName)").font(.subheadline)
                Spacer()
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Buttons

    private var saveSimButton: some View {
        actionButton(label: "Save Sim Scores", color: .blue) {
            await saveSimScores()
        }
    }

    private var generateTeamsButton: some View {
        actionButton(label: "Generate Teams", color: .purple) {
            buildPendingTeams()
            showTeamPreview = true
        }
    }

    private var reGenerateButton: some View {
        actionButton(label: "Re-Generate Teams", color: .orange) {
            buildPendingTeams()
            showTeamPreview = true
        }
    }

    private var saveScrambleButton: some View {
        actionButton(label: "Save Scramble Scores", color: .blue) {
            await saveScrambleScores()
        }
    }

    private var finalizeButton: some View {
        actionButton(label: isFinalizing ? "Finalizing…" : "Finalize & Award BMC Points", color: .green) {
            await finalizeEvent()
        }
    }

    @ViewBuilder
    private func actionButton(label: String, color: Color, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(label)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color.opacity(0.85))
                .foregroundStyle(.white)
                .cornerRadius(10)
        }
        .padding(.horizontal)
        .disabled(isSaving || isFinalizing)
    }

    // MARK: - Team preview sheet (coin flip)

    private var teamPreviewSheet: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Flip teams to re-randomize any ties.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.horizontal)

                ForEach(Array(pendingTeams.enumerated()), id: \.element.id) { i, team in
                    HStack {
                        Text("Team \(i + 1)").font(.caption.bold()).foregroundStyle(.secondary).frame(width: 60)
                        Text("\(team.playerAName) & \(team.playerBName)").font(.subheadline)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                Button("🪙 Flip / Re-randomize Ties") {
                    buildPendingTeams()
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .navigationTitle("Team Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Teams") {
                        showTeamPreview = false
                        Task { await commitTeams() }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showTeamPreview = false }
                }
            }
        }
    }

    // MARK: - Actions

    private func buildPendingTeams() {
        pendingRanked = store.rankSimEntries()   // shuffles within ties each call
        pendingTeams = store.buildTeams(from: pendingRanked)
    }

    private func populateInputs() {
        for (pid, score) in store.eventState.simScores {
            simInput[pid] = formatScore(score)
        }
        for (tid, score) in store.eventState.scrambleScores {
            scrambleInput[tid] = formatScore(score)
        }
    }

    private func saveSimScores() async {
        let parsed = parseScores(simInput)
        guard !parsed.isEmpty else {
            alertMessage = "Enter at least one score (use +3, -2, E, or 0)."
            showAlert = true
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.saveSimScores(parsed)
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func commitTeams() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.saveTeams(pendingTeams)
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func saveScrambleScores() async {
        let parsed = parseScores(scrambleInput)
        guard !parsed.isEmpty else {
            alertMessage = "Enter at least one scramble score."
            showAlert = true
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.saveScrambleScores(parsed)
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func finalizeEvent() async {
        isFinalizing = true
        defer { isFinalizing = false }
        do {
            try await store.finalizeEvent()
            alertMessage = "Event finalized! BMC points awarded and written to point_awards."
            showAlert = true
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func resetEvent() async {
        isResetting = true
        defer { isResetting = false }
        do {
            try await store.resetEvent()
            simInput = [:]
            scrambleInput = [:]
            alertMessage = "Golf event reset. All data cleared\(state.isFinalized ? " and BMC points reversed" : "")."
            showAlert = true
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    // MARK: - Helpers

    private func bindingFor(_ key: String, in dict: Binding<[String: String]>) -> Binding<String> {
        Binding(
            get: { dict.wrappedValue[key] ?? "" },
            set: { dict.wrappedValue[key] = $0 }
        )
    }

    /// Parses "+3", "-2", "E", "0" → Int
    private func parseScores(_ input: [String: String]) -> [String: Int] {
        input.compactMapValues { raw -> Int? in
            let t = raw.trimmingCharacters(in: .whitespaces)
            if t.uppercased() == "E" { return 0 }
            return Int(t)
        }
    }

    private func formatScore(_ score: Int) -> String {
        if score == 0 { return "E" }
        return score > 0 ? "+\(score)" : "\(score)"
    }
}
