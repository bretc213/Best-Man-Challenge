//
//  SoftballBracketPicksView.swift
//  Best Man Challenge
//

import SwiftUI

struct SoftballBracketPicksView: View {
    @ObservedObject var store: SoftballBracketStore
    let session: SessionStore

    @State private var draft: SoftballBracketPicks?
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let _ = draft {
                    let draftBinding = Binding<SoftballBracketPicks>(
                        get: {
                            draft ?? .empty(
                                submitterId: SoftballBracketStore.submitterId(session: session),
                                displayName: SoftballBracketStore.displayName(session: session)
                            )
                        },
                        set: { draft = $0 }
                    )

                    regionalSection(picks: draftBinding)
                    superRegionalSection(picks: draftBinding)
                    finalistsSection(picks: draftBinding)
                    championSection(picks: draftBinding)
                    saveButton(picks: draftBinding.wrappedValue)
                } else {
                    ProgressView("Loading picks...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }
            }
            .padding()
        }
        .navigationTitle("Softball Picks")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { resetDraftIfNeeded() }
        .onChange(of: store.myPicks) { _ in resetDraftIfNeeded() }
        .alert("Softball Bracket", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.config.title)
                .font(.title2.bold())
            Text(store.config.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if store.isLocked {
                Text("Locked — picks are view only.")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }
        }
    }

    private func regionalSection(picks: Binding<SoftballBracketPicks>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("1. Pick 16 Regional Winners")

            if store.config.sortedRegionals.isEmpty {
                Text("No regionals loaded yet. Check the WCWS seeder/data.")
                    .foregroundStyle(.secondary)
            }

            ForEach(store.config.sortedRegionals) { regional in
                VStack(alignment: .leading, spacing: 8) {
                    Text("#\(regional.nationalSeed) Regional")
                        .font(.headline)
                    Text(regional.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(regional.sortedTeams) { team in
                            pickButton(
                                title: display(team),
                                isSelected: picks.wrappedValue.regionalWinners[regional.id] == team.id,
                                isDisabled: store.isLocked
                            ) {
                                picks.wrappedValue.regionalWinners[regional.id] = team.id
                                clearDownstreamPicks(&picks.wrappedValue)
                            }
                        }
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func superRegionalSection(picks: Binding<SoftballBracketPicks>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("2. Pick 8 Super Regional Winners")

            ForEach(SoftballBracketConfig.superRegionalPairings, id: \.0) { pair in
                let id = SoftballBracketHelpers.superRegionalId(seedA: pair.0, seedB: pair.1)
                let teamA = regionalPickedTeam(seed: pair.0, picks: picks.wrappedValue)
                let teamB = regionalPickedTeam(seed: pair.1, picks: picks.wrappedValue)

                VStack(alignment: .leading, spacing: 8) {
                    Text("#\(pair.0) winner vs #\(pair.1) winner")
                        .font(.headline)

                    HStack(spacing: 10) {
                        superPickButton(team: teamA, id: id, picks: picks)
                        superPickButton(team: teamB, id: id, picks: picks)
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func finalistsSection(picks: Binding<SoftballBracketPicks>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("3. Pick 2 Championship Series Teams")
            let teams = superRegionalPickedTeams(picks: picks.wrappedValue)
            if teams.count < 8 {
                Text("Pick all 8 Super Regional winners first.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(teams) { team in
                    pickButton(
                        title: display(team),
                        isSelected: picks.wrappedValue.finalists.contains(team.id),
                        isDisabled: store.isLocked
                    ) {
                        if picks.wrappedValue.finalists.contains(team.id) {
                            picks.wrappedValue.finalists.removeAll { $0 == team.id }
                            if picks.wrappedValue.champion == team.id { picks.wrappedValue.champion = nil }
                        } else if picks.wrappedValue.finalists.count < 2 {
                            picks.wrappedValue.finalists.append(team.id)
                        } else {
                            alert("You can only pick 2 finalists.")
                        }
                    }
                }
            }
        }
    }

    private func championSection(picks: Binding<SoftballBracketPicks>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("4. Pick Champion")
            if picks.wrappedValue.finalists.count < 2 {
                Text("Pick exactly 2 finalists first.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                ForEach(picks.wrappedValue.finalists, id: \.self) { teamId in
                    let team = SoftballBracketHelpers.team(teamId, config: store.config)
                    pickButton(
                        title: team?.name ?? teamId,
                        isSelected: picks.wrappedValue.champion == teamId,
                        isDisabled: store.isLocked
                    ) {
                        picks.wrappedValue.champion = teamId
                    }
                }
            }
        }
    }

    private func saveButton(picks: SoftballBracketPicks) -> some View {
        Button {
            Task { await save(picks) }
        } label: {
            HStack {
                Spacer()
                if isSaving { ProgressView() }
                Text(store.isLocked ? "Bracket Locked" : "Save Softball Picks")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(store.isLocked ? Color.gray.opacity(0.3) : Color.blue.opacity(0.9))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(store.isLocked || isSaving)
        .padding(.top, 8)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline.bold())
            .padding(.top, 8)
    }

    private func pickButton(title: String, isSelected: Bool, isDisabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(8)
                .background(isSelected ? Color.green.opacity(0.85) : Color.secondary.opacity(0.14))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
    }

    private func superPickButton(team: SoftballTeam?, id: String, picks: Binding<SoftballBracketPicks>) -> some View {
        pickButton(
            title: team.map(display) ?? "TBD",
            isSelected: team != nil && picks.wrappedValue.superRegionalWinners[id] == team?.id,
            isDisabled: store.isLocked || team == nil
        ) {
            guard let team else { return }
            picks.wrappedValue.superRegionalWinners[id] = team.id
            picks.wrappedValue.finalists = []
            picks.wrappedValue.champion = nil
        }
    }

    private func display(_ team: SoftballTeam) -> String {
        if let seed = team.seedLabel, !seed.isEmpty { return "\(seed) \(team.name)" }
        return team.name
    }

    private func regionalPickedTeam(seed: Int, picks: SoftballBracketPicks) -> SoftballTeam? {
        guard let regional = store.config.regional(seed: seed),
              let teamId = picks.regionalWinners[regional.id] else { return nil }
        return regional.teams.first { $0.id == teamId }
    }

    private func superRegionalPickedTeams(picks: SoftballBracketPicks) -> [SoftballTeam] {
        SoftballBracketConfig.superRegionalPairings.compactMap { pair in
            let id = SoftballBracketHelpers.superRegionalId(seedA: pair.0, seedB: pair.1)
            return SoftballBracketHelpers.team(picks.superRegionalWinners[id], config: store.config)
        }
    }

    private func clearDownstreamPicks(_ picks: inout SoftballBracketPicks) {
        var validSuperWinners = Set<String>()

        for pair in SoftballBracketConfig.superRegionalPairings {
            if let teamA = regionalPickedTeam(seed: pair.0, picks: picks) { validSuperWinners.insert(teamA.id) }
            if let teamB = regionalPickedTeam(seed: pair.1, picks: picks) { validSuperWinners.insert(teamB.id) }
        }

        picks.superRegionalWinners = picks.superRegionalWinners.filter { validSuperWinners.contains($0.value) }
        let superWinners = Set(superRegionalPickedTeams(picks: picks).map(\.id))
        picks.finalists.removeAll { !superWinners.contains($0) }
        if let champion = picks.champion, !picks.finalists.contains(champion) {
            picks.champion = nil
        }
    }

    private func resetDraftIfNeeded() {
        if let myPicks = store.myPicks {
            draft = myPicks
        } else {
            draft = .empty(
                submitterId: SoftballBracketStore.submitterId(session: session),
                displayName: SoftballBracketStore.displayName(session: session)
            )
        }
    }

    private func save(_ picks: SoftballBracketPicks) async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await store.savePicks(picks)
            alert("Softball picks saved.")
        } catch {
            alert(error.localizedDescription)
        }
    }

    private func alert(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}
