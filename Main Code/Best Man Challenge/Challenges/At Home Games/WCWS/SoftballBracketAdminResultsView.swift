//
//  SoftballBracketAdminResultsView.swift
//  Best Man Challenge
//

import SwiftUI
import FirebaseFirestore

struct SoftballBracketAdminResultsView: View {
    @ObservedObject var store: SoftballBracketStore

    @State private var draft = SoftballBracketResults.empty
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Admin Results")
                        .font(.title2.bold())
                    Text("Set official winners here. Leaderboard updates live from these results.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                statusControls
                regionalResultsSection
                superRegionalResultsSection
                finalistResultsSection
                championResultsSection
                saveButton
            }
            .padding()
        }
        .navigationTitle("Softball Admin")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { draft = store.results }
        .onChange(of: store.results) { newValue in
            draft = newValue
        }
        .alert("Softball Admin", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private var statusControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bracket Status")
                .font(.headline)
            HStack {
                statusButton("Open", status: "open")
                statusButton("Locked", status: "locked")
                statusButton("Finalized", status: "finalized")
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statusButton(_ label: String, status: String) -> some View {
        Button(label) {
            Task {
                do {
                    try await store.updateStatus(status)
                    alert("Status set to \(label).")
                } catch {
                    alert(error.localizedDescription)
                }
            }
        }
        .font(.caption.bold())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(store.config.status == status ? Color.green.opacity(0.85) : Color.secondary.opacity(0.16))
        .foregroundStyle(store.config.status == status ? .white : .primary)
        .clipShape(Capsule())
    }

    private var regionalResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Regional Winners")

            if store.config.sortedRegionals.isEmpty {
                Text("No regionals loaded yet. Check the seeder/data.")
                    .foregroundStyle(.secondary)
            }

            ForEach(store.config.sortedRegionals) { regional in
                VStack(alignment: .leading, spacing: 8) {
                    Text("#\(regional.nationalSeed) — \(regional.title)")
                        .font(.headline)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(regional.sortedTeams) { team in
                            resultButton(
                                title: display(team),
                                selected: draft.regionalWinners[regional.id] == team.id
                            ) {
                                draft.regionalWinners[regional.id] = team.id
                                clearInvalidSuperResults()
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

    private var superRegionalResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Super Regional Winners")
            ForEach(SoftballBracketConfig.superRegionalPairings, id: \.0) { pair in
                let id = SoftballBracketHelpers.superRegionalId(seedA: pair.0, seedB: pair.1)
                let teamA = officialRegionalWinner(seed: pair.0)
                let teamB = officialRegionalWinner(seed: pair.1)

                VStack(alignment: .leading, spacing: 8) {
                    Text("#\(pair.0) winner vs #\(pair.1) winner")
                        .font(.headline)
                    HStack(spacing: 10) {
                        resultButton(
                            title: teamA.map(display) ?? "TBD",
                            selected: draft.superRegionalWinners[id] == teamA?.id,
                            disabled: teamA == nil
                        ) {
                            if let teamA {
                                draft.superRegionalWinners[id] = teamA.id
                                clearInvalidFinalists()
                            }
                        }

                        resultButton(
                            title: teamB.map(display) ?? "TBD",
                            selected: draft.superRegionalWinners[id] == teamB?.id,
                            disabled: teamB == nil
                        ) {
                            if let teamB {
                                draft.superRegionalWinners[id] = teamB.id
                                clearInvalidFinalists()
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

    private var finalistResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Championship Series Teams")
            Text("Select exactly 2 WCWS finalists.")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(officialSuperRegionalWinners()) { team in
                    resultButton(title: display(team), selected: draft.finalists.contains(team.id)) {
                        if draft.finalists.contains(team.id) {
                            draft.finalists.removeAll { $0 == team.id }
                            if draft.champion == team.id { draft.champion = nil }
                        } else if draft.finalists.count < 2 {
                            draft.finalists.append(team.id)
                        } else {
                            alert("Only 2 finalists can be selected.")
                        }
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var championResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Champion")
            HStack(spacing: 10) {
                ForEach(draft.finalists, id: \.self) { teamId in
                    let teamName = SoftballBracketHelpers.teamName(teamId, config: store.config)
                    resultButton(title: teamName, selected: draft.champion == teamId) {
                        draft.champion = teamId
                        draft.finalizedAt = Timestamp(date: Date())
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var saveButton: some View {
        Button {
            Task { await saveResults() }
        } label: {
            HStack {
                Spacer()
                if isSaving { ProgressView() }
                Text("Save Official Results")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.9))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(isSaving)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.headline.bold())
    }

    private func resultButton(title: String, selected: Bool, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 46)
                .padding(8)
                .background(selected ? Color.green.opacity(0.85) : Color.secondary.opacity(0.14))
                .foregroundStyle(selected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private func display(_ team: SoftballTeam) -> String {
        if let seed = team.seedLabel, !seed.isEmpty { return "\(seed) \(team.name)" }
        return team.name
    }

    private func officialRegionalWinner(seed: Int) -> SoftballTeam? {
        guard let regional = store.config.regional(seed: seed),
              let teamId = draft.regionalWinners[regional.id] else { return nil }
        return regional.teams.first { $0.id == teamId }
    }

    private func officialSuperRegionalWinners() -> [SoftballTeam] {
        SoftballBracketConfig.superRegionalPairings.compactMap { pair in
            let id = SoftballBracketHelpers.superRegionalId(seedA: pair.0, seedB: pair.1)
            return SoftballBracketHelpers.team(draft.superRegionalWinners[id], config: store.config)
        }
    }

    private func clearInvalidSuperResults() {
        for pair in SoftballBracketConfig.superRegionalPairings {
            let id = SoftballBracketHelpers.superRegionalId(seedA: pair.0, seedB: pair.1)
            let allowed = [officialRegionalWinner(seed: pair.0)?.id, officialRegionalWinner(seed: pair.1)?.id]
            if let current = draft.superRegionalWinners[id], !allowed.contains(current) {
                draft.superRegionalWinners.removeValue(forKey: id)
            }
        }
        clearInvalidFinalists()
    }

    private func clearInvalidFinalists() {
        let allowed = Set(officialSuperRegionalWinners().map(\.id))
        draft.finalists.removeAll { !allowed.contains($0) }
        if let champ = draft.champion, !draft.finalists.contains(champ) {
            draft.champion = nil
        }
    }

    private func saveResults() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await store.saveResults(draft)
            alert("Official results saved.")
        } catch {
            alert(error.localizedDescription)
        }
    }

    private func alert(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}
