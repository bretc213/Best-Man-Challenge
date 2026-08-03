//
//  CFBConfChampsAdminView.swift
//  Best Man Challenge
//
//  Admin: seed the game, post each conference's 2 finalists (launches Champ Week
//  + enables preseason grading), set the winner, and Finalize & Award BMC points.
//

import SwiftUI

struct CFBConfChampsAdminView: View {
    @ObservedObject var store: CFBConfChampsStore
    let session: SessionStore

    @State private var matchupSheetConf: CFBConference? = nil
    @State private var alertMsg: String? = nil
    @State private var showFinalizeConfirm = false
    @State private var isWorking = false

    // Seeder controls
    @State private var phase1Lock: Date = CFBConfChampsSeeder.defaultPhase1Lock
    @State private var seeding = false

    private var isOwner: Bool { (session.profile?.role ?? "").lowercased() == "owner" }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                seederSection

                ForEach(store.conferences) { conf in
                    adminConfCard(conf)
                }

                if isOwner { finalizeSection }
            }
            .padding()
        }
        .sheet(item: $matchupSheetConf) { conf in
            CFBAdminMatchupSheet(store: store, conference: conf) { matchupSheetConf = nil }
        }
        .alert("Result", isPresented: .constant(alertMsg != nil)) {
            Button("OK") { alertMsg = nil }
        } message: { Text(alertMsg ?? "") }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Admin — CFB Conf. Champs").font(.title3.bold())
            Text("Seed · post matchups · set winners · finalize")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Seeder

    private var seederSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Setup").font(.headline)
            DatePicker("Preseason lock (first Power-4 game)",
                       selection: $phase1Lock)
                .font(.subheadline)
            Button {
                Task { await runSeeder() }
            } label: {
                Label(seeding ? "Seeding…" : "Seed / Refresh Conferences",
                      systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .disabled(seeding)
            Text("Creates the tile (Coming Up) and all 10 conferences with their rosters. Safe to re-run — it won't erase posted matchups or player picks.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func runSeeder() async {
        seeding = true
        defer { seeding = false }
        do {
            try await CFBConfChampsSeeder().seedAll(phase1Lock: phase1Lock)
            alertMsg = "Seeded ✓ Tile + 10 conferences written."
        } catch {
            alertMsg = "Seed failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Per-conference admin card

    private func adminConfCard(_ conf: CFBConference) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(conf.name).font(.headline)
                Text(conf.tier.label).font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(conf.tier == .power ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
                Spacer()
            }

            if conf.matchupSet {
                // Matchup posted — set the winner
                HStack(spacing: 10) {
                    ForEach(conf.finalists) { team in
                        Button {
                            Task { await setChampion(conf: conf, team: team) }
                        } label: {
                            HStack(spacing: 6) {
                                CFBTeamLogo(team: team, size: 24)
                                Text(team.name).font(.caption.weight(.semibold))
                                if conf.championId == team.id {
                                    Image(systemName: "crown.fill").font(.caption2).foregroundStyle(.yellow)
                                }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(conf.championId == team.id ? Color.green.opacity(0.2) : Color(UIColor.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(conf.championId == team.id ? Color.green.opacity(0.5) : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(conf.championId == nil ? "Tap a team to set the winner." : "Winner set. Points grade automatically.")
                    .font(.caption2).foregroundStyle(.secondary)

                HStack {
                    Button("Edit Matchup") { matchupSheetConf = conf }
                        .font(.caption)
                    Spacer()
                    Button(role: .destructive) {
                        Task { await clear(conf) }
                    } label: { Text("Clear").font(.caption) }
                }
            } else {
                // No matchup yet
                Text("No matchup posted.").font(.caption).foregroundStyle(.secondary)
                Button {
                    matchupSheetConf = conf
                } label: {
                    Label("Post Finalists → Launch Champ Week", systemImage: "flag.checkered")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func setChampion(conf: CFBConference, team: CFBTeam) async {
        do {
            // toggle off if tapping the current champion
            let newId = conf.championId == team.id ? nil : team.id
            try await store.adminSetChampion(confId: conf.id, championId: newId)
        } catch { alertMsg = error.localizedDescription }
    }

    private func clear(_ conf: CFBConference) async {
        do { try await store.adminClearConference(confId: conf.id) }
        catch { alertMsg = error.localizedDescription }
    }

    // MARK: - Finalize

    private var finalizeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Finalize").font(.headline)
            if store.isFinalized {
                Label("Already finalized — BMC points awarded.", systemImage: "checkmark.seal.fill")
                    .font(.subheadline).foregroundStyle(.green)
            }
            Button {
                showFinalizeConfirm = true
            } label: {
                Label(isWorking ? "Finalizing…" : "Finalize & Award Points",
                      systemImage: "checkmark.seal.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isWorking)
            .confirmationDialog(
                "Convert raw scores to BMC points (golf-payout ties + +3 above Bret)? Idempotent — safe to re-run.",
                isPresented: $showFinalizeConfirm, titleVisibility: .visible
            ) {
                Button("Finalize", role: .destructive) { Task { await finalize() } }
                Button("Cancel", role: .cancel) {}
            }
            Text("Run once all title games are complete and winners are set.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func finalize() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await store.finalizeAndAward()
            alertMsg = "Finalize complete — BMC points awarded."
        } catch {
            alertMsg = "Finalize failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Admin Matchup Sheet (pick 2 finalists + kickoff)

struct CFBAdminMatchupSheet: View {
    @ObservedObject var store: CFBConfChampsStore
    let conference: CFBConference
    let onDone: () -> Void

    @State private var finalists: [String] = []
    @State private var kickoff: Date = CFBAdminMatchupSheet.defaultKickoff
    @State private var saving = false
    @State private var errorText: String? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select the two teams in the \(conference.name) title game, then set kickoff (the Champ Week lock).")
                        .font(.footnote).foregroundStyle(.secondary)
                    DatePicker("Kickoff", selection: $kickoff).font(.subheadline)
                    Text("Finalists: \(finalists.count)/2").font(.caption.weight(.semibold))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemBackground))

                List {
                    ForEach(conference.teams) { team in
                        let isSel = finalists.contains(team.id)
                        HStack(spacing: 12) {
                            CFBTeamLogo(team: team, size: 30)
                            Text(team.name).font(.subheadline.weight(isSel ? .semibold : .regular))
                            Spacer()
                            Image(systemName: isSel ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSel ? Color.accentColor : .secondary.opacity(0.4))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { toggle(team.id) }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle(conference.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { onDone() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Post") { Task { await save() } }
                        .disabled(finalists.count != 2 || saving)
                }
            }
            .alert("Couldn't save", isPresented: .constant(errorText != nil)) {
                Button("OK") { errorText = nil }
            } message: { Text(errorText ?? "") }
            .onAppear {
                finalists = conference.finalistIds
                if let existing = conference.phase2LockAt { kickoff = existing }
            }
        }
    }

    private func toggle(_ id: String) {
        if finalists.contains(id) { finalists.removeAll { $0 == id } }
        else if finalists.count < 2 { finalists.append(id) }
        else { finalists.removeFirst(); finalists.append(id) }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            try await store.adminSetFinalists(confId: conference.id, finalistIds: finalists, phase2Lock: kickoff)
            onDone()
        } catch { errorText = error.localizedDescription }
    }

    static var defaultKickoff: Date {
        // Sat, Dec 5, 2026, 12:00 PM ET (championship weekend).
        var c = DateComponents()
        c.year = 2026; c.month = 12; c.day = 5; c.hour = 12; c.minute = 0
        c.timeZone = TimeZone(identifier: "America/New_York")
        return Calendar(identifier: .gregorian).date(from: c) ?? Date()
    }
}
