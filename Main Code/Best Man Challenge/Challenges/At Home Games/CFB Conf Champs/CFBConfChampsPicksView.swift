//
//  CFBConfChampsPicksView.swift
//  Best Man Challenge
//
//  Phase 1 (Preseason) and Phase 2 (Champ Week) player pick screens.
//

import SwiftUI

// MARK: - Phase 1: Preseason Picks

struct CFBPreseasonPicksView: View {
    @ObservedObject var store: CFBConfChampsStore
    let session: SessionStore

    @State private var editingConf: CFBConference? = nil
    @State private var toast: String? = nil

    private var powerConfs: [CFBConference] { store.conferences.filter { $0.tier == .power } }
    private var otherConfs: [CFBConference] { store.conferences.filter { $0.tier == .nonPower } }

    var body: some View {
        Group {
            if store.isLoading && store.conferences.isEmpty {
                ProgressView("Loading…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        header

                        sectionLabel("Power 4 — worth more")
                        ForEach(powerConfs) { conf in confRow(conf) }

                        sectionLabel("Group of 5")
                        ForEach(otherConfs) { conf in confRow(conf) }
                    }
                    .padding()
                }
            }
        }
        .sheet(item: $editingConf) { conf in
            CFBPreseasonEditorSheet(
                store: store,
                conference: conf,
                onDone: { editingConf = nil }
            )
        }
        .overlay(toastOverlay, alignment: .bottom)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preseason Predictions")
                .font(.title3.bold())
            Text("For each conference, pick the two teams that reach the title game and the champion. Power 4: 3 pts per correct finalist, +5 champion. Group of 5: 1 pt per finalist, +2 champion. Locks at the first Power-4 game.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let lock = store.conferences.first?.phase1LockAt {
                Label(lockLabel(lock), systemImage: store.conferences.first?.isPhase1Locked == true ? "lock.fill" : "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(store.conferences.first?.isPhase1Locked == true ? .red : .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    private func confRow(_ conf: CFBConference) -> some View {
        let pick = store.myPhase1[conf.id]
        let locked = conf.isPhase1Locked
        return Button {
            editingConf = conf
        } label: {
            VStack(spacing: 10) {
                HStack {
                    Text(conf.name).font(.headline)
                    Spacer()
                    Text("max \(pointsString(conf.maxPoints))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if locked {
                        Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.red)
                    } else {
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                    }
                }

                if let pick, !pick.finalistIds.isEmpty {
                    HStack(spacing: 14) {
                        ForEach(pick.finalistIds, id: \.self) { tid in
                            let team = CFBData.team(for: tid)
                            HStack(spacing: 6) {
                                CFBTeamLogo(team: team, size: 26)
                                Text(team?.name ?? tid).font(.caption)
                                if pick.championId == tid {
                                    Image(systemName: "crown.fill")
                                        .font(.caption2).foregroundStyle(.yellow)
                                }
                            }
                        }
                        Spacer()
                    }
                } else {
                    HStack {
                        Text("No pick yet — tap to predict")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast {
            Text(toast)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Material.thick).clipShape(Capsule())
                .padding(.bottom, 20)
        }
    }

    private func lockLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        let locked = store.conferences.first?.isPhase1Locked == true
        return (locked ? "Locked " : "Locks ") + f.string(from: date)
    }
}

// MARK: - Phase 1 Editor Sheet

struct CFBPreseasonEditorSheet: View {
    @ObservedObject var store: CFBConfChampsStore
    let conference: CFBConference
    let onDone: () -> Void

    @State private var finalists: [String] = []
    @State private var champion: String? = nil
    @State private var saving = false
    @State private var errorText: String? = nil

    private var locked: Bool { conference.isPhase1Locked }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                instructions
                List {
                    ForEach(conference.teams) { team in
                        teamRow(team)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle(conference.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(locked || saving)
                }
            }
            .alert("Couldn't save", isPresented: .constant(errorText != nil)) {
                Button("OK") { errorText = nil }
            } message: { Text(errorText ?? "") }
            .onAppear {
                finalists = store.myPhase1[conference.id]?.finalistIds ?? []
                champion = store.myPhase1[conference.id]?.championId
            }
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(locked
                 ? "Picks are locked — the season has started."
                 : "Tap up to 2 finalists, then tap the crown to set your champion.")
                .font(.footnote)
                .foregroundStyle(locked ? .red : .secondary)
            HStack {
                Text("Finalists: \(finalists.count)/2").font(.caption.weight(.semibold))
                Spacer()
                if let champion, let t = CFBData.team(for: champion) {
                    Label(t.name, systemImage: "crown.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.yellow)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
    }

    private func teamRow(_ team: CFBTeam) -> some View {
        let isFinalist = finalists.contains(team.id)
        let isChampion = champion == team.id
        return HStack(spacing: 12) {
            CFBTeamLogo(team: team, size: 34)
            Text(team.name).font(.subheadline.weight(isFinalist ? .semibold : .regular))
            Spacer()

            if isFinalist {
                Button {
                    champion = isChampion ? nil : team.id
                } label: {
                    Image(systemName: isChampion ? "crown.fill" : "crown")
                        .foregroundStyle(isChampion ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(locked)
            }

            Image(systemName: isFinalist ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isFinalist ? Color.accentColor : .secondary.opacity(0.4))
        }
        .contentShape(Rectangle())
        .onTapGesture { toggleFinalist(team.id) }
        .opacity(locked ? 0.6 : 1)
    }

    private func toggleFinalist(_ id: String) {
        guard !locked else { return }
        if finalists.contains(id) {
            finalists.removeAll { $0 == id }
            if champion == id { champion = nil }
        } else if finalists.count < 2 {
            finalists.append(id)
        } else {
            // replace the older selection to keep it fluid
            let removed = finalists.removeFirst()
            if champion == removed { champion = nil }
            finalists.append(id)
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            // Champion must be one of the finalists.
            let champ = (champion != nil && finalists.contains(champion!)) ? champion : nil
            try await store.setPhase1(confId: conference.id, finalistIds: finalists, championId: champ)
            onDone()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - Phase 2: Champ Week Picks

struct CFBChampWeekPicksView: View {
    @ObservedObject var store: CFBConfChampsStore
    let session: SessionStore

    @State private var toast: String? = nil

    private var liveConfs: [CFBConference] {
        store.conferences.filter { $0.matchupSet }
    }
    private var pendingConfs: [CFBConference] {
        store.conferences.filter { !$0.matchupSet }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header

                if liveConfs.isEmpty {
                    ContentUnavailableView(
                        "No matchups posted yet",
                        systemImage: "clock",
                        description: Text("Once a conference's two title-game teams are set, you'll pick the winner here.")
                    )
                    .padding(.top, 30)
                } else {
                    ForEach(liveConfs) { conf in matchupCard(conf) }
                }

                if !pendingConfs.isEmpty {
                    Text("Waiting on matchups: \(pendingConfs.map { $0.name }.joined(separator: ", "))")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
        .overlay(toastOverlay, alignment: .bottom)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Championship Week")
                .font(.title3.bold())
            Text("Pick the winner of each title game. Power 4: 2 pts. Group of 5: 1 pt. Each locks at kickoff.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func matchupCard(_ conf: CFBConference) -> some View {
        let myPick = store.myPhase2[conf.id]
        let champ = conf.championId
        let locked = conf.isPhase2Locked
        let teams = conf.finalists
        return VStack(spacing: 10) {
            HStack {
                Text(conf.name).font(.headline)
                Spacer()
                if champ != nil {
                    Label("Final", systemImage: "checkmark.seal.fill")
                        .font(.caption2.weight(.semibold)).foregroundStyle(.green)
                } else if locked {
                    Text("LOCKED").font(.caption2.bold())
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.red.opacity(0.15)).foregroundStyle(.red)
                        .clipShape(Capsule())
                } else {
                    Text("Locks at kickoff").font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                ForEach(teams) { team in
                    winnerButton(conf: conf, team: team, myPick: myPick, champ: champ, locked: locked)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func winnerButton(conf: CFBConference, team: CFBTeam, myPick: String?, champ: String?, locked: Bool) -> some View {
        let isSelected = myPick == team.id
        let hasResult = champ != nil
        let isCorrect = hasResult && isSelected && myPick == champ
        let isWrong = hasResult && isSelected && myPick != champ
        let isWinner = champ == team.id

        let bg: Color = {
            if isCorrect { return .green.opacity(0.25) }
            if isWrong { return .red.opacity(0.20) }
            if isWinner && !isSelected { return .green.opacity(0.10) }
            if isSelected { return .accentColor.opacity(0.15) }
            return Color(UIColor.systemBackground)
        }()

        return Button {
            guard !locked else { return }
            Task { await pick(conf: conf, team: team) }
        } label: {
            VStack(spacing: 8) {
                CFBTeamLogo(team: team, size: 54)
                Text(team.name)
                    .font(.caption.weight(isSelected ? .bold : .regular))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(locked)
    }

    private func pick(conf: CFBConference, team: CFBTeam) async {
        do {
            try await store.setPhase2(confId: conf.id, winnerId: team.id)
            show("Pick saved ✓")
        } catch {
            show(error.localizedDescription)
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast {
            Text(toast)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Material.thick).clipShape(Capsule())
                .padding(.bottom, 20)
        }
    }

    private func show(_ msg: String) {
        toast = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { toast = nil }
    }
}

// MARK: - Helpers

func pointsString(_ p: Double) -> String {
    p == floor(p) ? String(Int(p)) : String(format: "%.1f", p)
}
