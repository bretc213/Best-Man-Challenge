import SwiftUI

struct MLBFuturesSubmissionView: View {
    @ObservedObject var store: MLBFuturesStore
    let userId: String
    let displayName: String
    let board: MLBFuturesPickBoard

    @State private var draft = MLBFuturesSubmissionDraft()
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var didSeedDefaults = false
    @State private var showRules = false
    @State private var showingMyPicks = false

    private var mySubmittedPicks: MLBFuturesPicksDoc? {
        store.existingPick(for: userId, on: board)
    }

    private var locksAtDate: Date? {
        store.meta?.locksAt?.dateValue()
    }

    private var isLocked: Bool {
        store.isLocked
    }

    private var submitButtonTitle: String {
        board.submitButtonTitle(mySubmittedPicks != nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if showingMyPicks, let submitted = mySubmittedPicks {
                myPicksView(submitted)
            } else {
                submissionForm
            }
        }
        .navigationTitle(board.submissionTitle)
        .sheet(isPresented: $showRules) {
            MLBFuturesRulesView()
        }
        .onAppear {
            if !didSeedDefaults {
                draft.seedDefaults()
                normalizeAllDependentSelections()
                didSeedDefaults = true
            }

            hydrateDraftFromExistingPicksIfNeeded()
            showingMyPicks = mySubmittedPicks != nil
        }
        .onChange(of: store.picks.count) { _ in
            syncFromStore()
        }
        .onChange(of: store.adminPicks.count) { _ in
            syncFromStore()
        }
    }

    private func syncFromStore() {
        hydrateDraftFromExistingPicksIfNeeded()
        if mySubmittedPicks != nil {
            showingMyPicks = true
        }
    }

    private var topBar: some View {
        HStack {
            if showingMyPicks {
                if !isLocked {
                    Button {
                        showingMyPicks = false
                    } label: {
                        Label("Back to Submission View", systemImage: "square.and.pencil")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            } else if mySubmittedPicks != nil {
                Button {
                    showingMyPicks = true
                } label: {
                    Label(board.submissionHeaderTitle, systemImage: "checklist")
                        .font(.subheadline.weight(.semibold))
                }
            }

            Spacer()

            Button {
                showRules = true
            } label: {
                Label("Rules", systemImage: "info.circle")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    private var submissionForm: some View {
        Form {
            if let locksAtDate {
                Section {
                    Text(isLocked
                         ? "\(board.lockedMessagePrefix) are locked."
                         : "\(board.lockedMessagePrefix) do not lock until \(formatted(locksAtDate)).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("AL Divisions") {
                divisionEditor(title: "AL East", teams: $draft.alEast)
                divisionEditor(title: "AL Central", teams: $draft.alCentral)
                divisionEditor(title: "AL West", teams: $draft.alWest)
            }

            Section("NL Divisions") {
                divisionEditor(title: "NL East", teams: $draft.nlEast)
                divisionEditor(title: "NL Central", teams: $draft.nlCentral)
                divisionEditor(title: "NL West", teams: $draft.nlWest)
            }

            Section("Seeds") {
                leagueSeedSection(
                    league: .al,
                    seeds: $draft.alSeeds,
                    divisionWinners: [draft.alEast.first, draft.alCentral.first, draft.alWest.first].compactMap { $0 },
                    pool: draft.alEast + draft.alCentral + draft.alWest
                )

                leagueSeedSection(
                    league: .nl,
                    seeds: $draft.nlSeeds,
                    divisionWinners: [draft.nlEast.first, draft.nlCentral.first, draft.nlWest.first].compactMap { $0 },
                    pool: draft.nlEast + draft.nlCentral + draft.nlWest
                )
            }

            Section("Division Series") {
                teamToggleSection(
                    title: "ALDS (choose 4)",
                    selected: $draft.aldsTeams,
                    pool: draft.alSeeds,
                    maxCount: 4
                )

                teamToggleSection(
                    title: "NLDS (choose 4)",
                    selected: $draft.nldsTeams,
                    pool: draft.nlSeeds,
                    maxCount: 4
                )
            }

            Section("Championship Series") {
                teamToggleSection(
                    title: "ALCS (choose 2)",
                    selected: $draft.alcsTeams,
                    pool: draft.aldsTeams,
                    maxCount: 2
                )

                teamToggleSection(
                    title: "NLCS (choose 2)",
                    selected: $draft.nlcsTeams,
                    pool: draft.nldsTeams,
                    maxCount: 2
                )
            }

            Section("World Series") {
                teamToggleSection(
                    title: "World Series Teams (choose 2)",
                    selected: $draft.worldSeriesTeams,
                    pool: draft.alcsTeams + draft.nlcsTeams,
                    maxCount: 2
                )

                Picker("Champion", selection: $draft.worldSeriesWinner) {
                    ForEach(draft.worldSeriesTeams, id: \.self) { teamId in
                        Text(MLBFuturesConstants.teamName(teamId)).tag(teamId)
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(isSubmitting ? "Submitting..." : submitButtonTitle) {
                    submit()
                }
                .disabled(isSubmitting || isLocked)
            }
        }
    }

    private func myPicksView(_ pick: MLBFuturesPicksDoc) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let locksAtDate {
                    Text(isLocked
                         ? "\(board.lockedMessagePrefix) are locked."
                         : "You can still edit until \(formatted(locksAtDate)).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                card {
                    Text(board.submissionHeaderTitle)
                        .font(.title3.bold())
                    divisionView(title: "AL East", teams: pick.alEast)
                    divisionView(title: "AL Central", teams: pick.alCentral)
                    divisionView(title: "AL West", teams: pick.alWest)
                }

                card {
                    divisionView(title: "NL East", teams: pick.nlEast)
                    divisionView(title: "NL Central", teams: pick.nlCentral)
                    divisionView(title: "NL West", teams: pick.nlWest)
                }

                card {
                    numberedListView(title: "AL Seeds", teams: pick.alSeeds)
                    numberedListView(title: "NL Seeds", teams: pick.nlSeeds)
                }

                card {
                    bulletedListView(title: "ALDS", teams: pick.aldsTeams)
                    bulletedListView(title: "NLDS", teams: pick.nldsTeams)
                    bulletedListView(title: "ALCS", teams: pick.alcsTeams)
                    bulletedListView(title: "NLCS", teams: pick.nlcsTeams)
                    bulletedListView(title: "World Series", teams: pick.worldSeriesTeams)
                    championView(teamId: pick.worldSeriesWinner)
                }
            }
            .padding()
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func hydrateDraftFromExistingPicksIfNeeded() {
        guard let existing = mySubmittedPicks else { return }
        draft = MLBFuturesSubmissionDraft(from: existing)
    }

    private func submit() {
        guard !isLocked else { return }

        isSubmitting = true
        errorMessage = nil

        normalizeAllDependentSelections()
        let doc = draft.asPicksDoc(userId: userId, displayName: displayName)

        Task {
            do {
                try await store.submit(picks: doc, on: board)
                await MainActor.run {
                    isSubmitting = false
                    showingMyPicks = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }

    @ViewBuilder
    private func divisionEditor(title: String, teams: Binding<[String]>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ForEach(Array(teams.wrappedValue.enumerated()), id: \.element) { index, teamId in
                HStack {
                    Text("\(index + 1).")
                        .frame(width: 24)

                    Text(MLBFuturesConstants.teamName(teamId))

                    Spacer()

                    if index > 0 {
                        Button("↑") {
                            var copy = teams.wrappedValue
                            copy.swapAt(index, index - 1)
                            teams.wrappedValue = copy
                            reseedAfterDivisionChanges()
                        }
                        .buttonStyle(.borderless)
                    }

                    if index < teams.wrappedValue.count - 1 {
                        Button("↓") {
                            var copy = teams.wrappedValue
                            copy.swapAt(index, index + 1)
                            teams.wrappedValue = copy
                            reseedAfterDivisionChanges()
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func leagueSeedSection(
        league: MLBLeague,
        seeds: Binding<[String]>,
        divisionWinners: [String],
        pool: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(league.displayName) Seeds")
                .font(.headline)

            Text("Seeds 1-3 are limited to your division winners.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(0..<6, id: \.self) { index in
                let allowed = allowedSeedOptions(
                    index: index,
                    divisionWinners: divisionWinners,
                    pool: pool
                )

                Picker(
                    "Seed \(index + 1)",
                    selection: Binding(
                        get: {
                            seeds.wrappedValue.indices.contains(index) ? seeds.wrappedValue[index] : ""
                        },
                        set: { newValue in
                            var copy = seeds.wrappedValue
                            while copy.count < 6 { copy.append("") }

                            updateSeedWithSwap(
                                seeds: &copy,
                                at: index,
                                to: newValue,
                                divisionWinners: divisionWinners,
                                pool: pool
                            )

                            seeds.wrappedValue = copy
                            normalizeAllDependentSelections()
                        }
                    )
                ) {
                    ForEach(allowed, id: \.self) { teamId in
                        Text(MLBFuturesConstants.teamName(teamId)).tag(teamId)
                    }
                }
                .disabled(isLocked)
            }
        }
        .padding(.vertical, 4)
    }

    private func allowedSeedOptions(
        index: Int,
        divisionWinners: [String],
        pool: [String]
    ) -> [String] {
        index < 3 ? divisionWinners : pool.filter { !divisionWinners.contains($0) }
    }

    private func updateSeedWithSwap(
        seeds: inout [String],
        at index: Int,
        to newValue: String,
        divisionWinners: [String],
        pool: [String]
    ) {
        guard !newValue.isEmpty else { return }
        guard seeds.indices.contains(index) else { return }

        let top3Allowed = divisionWinners
        let wildCardAllowed = pool.filter { !divisionWinners.contains($0) }

        let allowedForIndex = index < 3 ? top3Allowed : wildCardAllowed
        guard allowedForIndex.contains(newValue) else { return }

        if let existingIndex = seeds.firstIndex(of: newValue), existingIndex != index {
            let targetIsTop3 = index < 3
            let existingIsTop3 = existingIndex < 3
            guard targetIsTop3 == existingIsTop3 else { return }

            let oldValue = seeds[index]
            seeds[index] = newValue
            seeds[existingIndex] = oldValue
        } else {
            seeds[index] = newValue
        }

        seeds = normalizedSeeds(copy: seeds, divisionWinners: divisionWinners, pool: pool)
    }

    private func normalizedSeeds(copy: [String], divisionWinners: [String], pool: [String]) -> [String] {
        var result = Array(repeating: "", count: 6)

        for index in 0..<min(3, copy.count) {
            let team = copy[index]
            if divisionWinners.contains(team), !result.contains(team) {
                result[index] = team
            }
        }

        let remainingTop3 = divisionWinners.filter { !result.contains($0) }
        var topInsert = 0
        for index in 0..<3 {
            if result[index].isEmpty, topInsert < remainingTop3.count {
                result[index] = remainingTop3[topInsert]
                topInsert += 1
            }
        }

        let wildCards = pool.filter { !divisionWinners.contains($0) }

        for index in 3..<min(6, copy.count) {
            let team = copy[index]
            if wildCards.contains(team), !result.contains(team) {
                result[index] = team
            }
        }

        let remainingWildCards = wildCards.filter { !result.contains($0) }
        var wcInsert = 0
        for index in 3..<6 {
            if result[index].isEmpty, wcInsert < remainingWildCards.count {
                result[index] = remainingWildCards[wcInsert]
                wcInsert += 1
            }
        }

        return result
    }

    private func reseedAfterDivisionChanges() {
        let alWinners = [draft.alEast.first, draft.alCentral.first, draft.alWest.first].compactMap { $0 }
        let nlWinners = [draft.nlEast.first, draft.nlCentral.first, draft.nlWest.first].compactMap { $0 }

        draft.alSeeds = normalizedSeeds(
            copy: draft.alSeeds,
            divisionWinners: alWinners,
            pool: draft.alEast + draft.alCentral + draft.alWest
        )

        draft.nlSeeds = normalizedSeeds(
            copy: draft.nlSeeds,
            divisionWinners: nlWinners,
            pool: draft.nlEast + draft.nlCentral + draft.nlWest
        )

        normalizeAllDependentSelections()
    }

    private func normalizeAllDependentSelections() {
        draft.aldsTeams = pruneSelection(draft.aldsTeams, toAllowedPool: draft.alSeeds, maxCount: 4)
        draft.nldsTeams = pruneSelection(draft.nldsTeams, toAllowedPool: draft.nlSeeds, maxCount: 4)

        draft.alcsTeams = pruneSelection(draft.alcsTeams, toAllowedPool: draft.aldsTeams, maxCount: 2)
        draft.nlcsTeams = pruneSelection(draft.nlcsTeams, toAllowedPool: draft.nldsTeams, maxCount: 2)

        draft.worldSeriesTeams = pruneSelection(
            draft.worldSeriesTeams,
            toAllowedPool: draft.alcsTeams + draft.nlcsTeams,
            maxCount: 2
        )

        if !draft.worldSeriesTeams.contains(draft.worldSeriesWinner) {
            draft.worldSeriesWinner = draft.worldSeriesTeams.first ?? ""
        }
    }

    private func pruneSelection(_ selection: [String], toAllowedPool pool: [String], maxCount: Int) -> [String] {
        var seen = Set<String>()
        let filtered = selection.filter { team in
            guard pool.contains(team) else { return false }
            guard !seen.contains(team) else { return false }
            seen.insert(team)
            return true
        }
        return Array(filtered.prefix(maxCount))
    }

    @ViewBuilder
    private func teamToggleSection(
        title: String,
        selected: Binding<[String]>,
        pool: [String],
        maxCount: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ForEach(pool, id: \.self) { teamId in
                Button {
                    guard !isLocked else { return }

                    var copy = selected.wrappedValue

                    if copy.contains(teamId) {
                        copy.removeAll { $0 == teamId }
                    } else if copy.count < maxCount {
                        copy.append(teamId)
                    }

                    selected.wrappedValue = copy
                    normalizeAllDependentSelections()
                } label: {
                    HStack {
                        Text(MLBFuturesConstants.teamName(teamId))
                        Spacer()
                        Image(systemName: selected.wrappedValue.contains(teamId) ? "checkmark.circle.fill" : "circle")
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLocked)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func divisionView(title: String, teams: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            ForEach(Array(teams.enumerated()), id: \.offset) { index, teamId in
                Text("\(index + 1). \(MLBFuturesConstants.teamName(teamId))")
            }
        }
    }

    @ViewBuilder
    private func numberedListView(title: String, teams: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            ForEach(Array(teams.enumerated()), id: \.offset) { index, teamId in
                Text("\(index + 1). \(MLBFuturesConstants.teamName(teamId))")
            }
        }
    }

    @ViewBuilder
    private func bulletedListView(title: String, teams: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            ForEach(teams, id: \.self) { teamId in
                Text("• \(MLBFuturesConstants.teamName(teamId))")
            }
        }
    }

    @ViewBuilder
    private func championView(teamId: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Champion")
                .font(.headline)

            Text(MLBFuturesConstants.teamName(teamId))
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
