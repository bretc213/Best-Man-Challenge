import SwiftUI
import FirebaseFirestore

struct MLBFuturesAdminView: View {
    @ObservedObject var store: MLBFuturesStore

    @State private var divisionState: [String: [String]] = [:]
    @State private var currentALSeeds: [String] = []
    @State private var currentNLSeeds: [String] = []
    @State private var currentALDS: [String] = []
    @State private var currentNLDS: [String] = []
    @State private var currentALCS: [String] = []
    @State private var currentNLCS: [String] = []
    @State private var currentWS: [String] = []
    @State private var currentChampion: String = ""
    @State private var saveMessage: String?

    var body: some View {
        Form {
            ForEach(MLBDivisionKey.allCases) { division in
                Section(division.displayName) {
                    orderEditor(teams: Binding(
                        get: { divisionState[division.rawValue] ?? MLBFuturesConstants.teams(in: division).map(\.id) },
                        set: { divisionState[division.rawValue] = $0 }
                    ))
                }
            }

            Section("Current Seeds") {
                orderedTeamList(title: "AL Seeds", teams: $currentALSeeds)
                orderedTeamList(title: "NL Seeds", teams: $currentNLSeeds)
            }

            Section("Current Postseason") {
                tokenList(title: "ALDS", teams: $currentALDS)
                tokenList(title: "NLDS", teams: $currentNLDS)
                tokenList(title: "ALCS", teams: $currentALCS)
                tokenList(title: "NLCS", teams: $currentNLCS)
                tokenList(title: "World Series", teams: $currentWS)

                Picker("Champion", selection: $currentChampion) {
                    ForEach(currentWS, id: \.self) { teamId in
                        Text(MLBFuturesConstants.teamName(teamId)).tag(teamId)
                    }
                }
            }

            if let saveMessage {
                Section {
                    Text(saveMessage)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Save Admin State") {
                    save()
                }
            }
        }
        .navigationTitle("MLB Futures Admin")
        .onAppear(perform: hydrate)
    }

    private func hydrate() {
        if let state = store.adminState {
            divisionState = state.currentDivisionStandings
            currentALSeeds = state.currentALSeeds
            currentNLSeeds = state.currentNLSeeds
            currentALDS = state.currentALDSTeams
            currentNLDS = state.currentNLDSTeams
            currentALCS = state.currentALCSTeams
            currentNLCS = state.currentNLCSTeams
            currentWS = state.currentWorldSeriesTeams
            currentChampion = state.currentWorldSeriesWinner ?? ""
        } else {
            divisionState = Dictionary(
                uniqueKeysWithValues: MLBDivisionKey.allCases.map {
                    ($0.rawValue, MLBFuturesConstants.teams(in: $0).map(\.id))
                }
            )
            currentALSeeds = []
            currentNLSeeds = []
        }
    }

    @ViewBuilder
    private func orderEditor(teams: Binding<[String]>) -> some View {
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
                    }
                }

                if index < teams.wrappedValue.count - 1 {
                    Button("↓") {
                        var copy = teams.wrappedValue
                        copy.swapAt(index, index + 1)
                        teams.wrappedValue = copy
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func orderedTeamList(title: String, teams: Binding<[String]>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ForEach(Array(teams.wrappedValue.enumerated()), id: \.offset) { index, teamId in
                Text("\(index + 1). \(MLBFuturesConstants.teamName(teamId))")
            }
        }
    }

    @ViewBuilder
    private func tokenList(title: String, teams: Binding<[String]>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(teams.wrappedValue.map(MLBFuturesConstants.teamName).joined(separator: ", "))
                .foregroundStyle(.secondary)
        }
    }

    private func save() {
        let state = MLBFuturesAdminState(
            challengeId: MLBFuturesConstants.challengeId,
            updatedAt: Timestamp(date: Date()),
            updatedBy: nil,
            isFinal: false,
            currentDivisionStandings: divisionState,
            currentALSeeds: currentALSeeds,
            currentNLSeeds: currentNLSeeds,
            currentALDSTeams: currentALDS,
            currentNLDSTeams: currentNLDS,
            currentALCSTeams: currentALCS,
            currentNLCSTeams: currentNLCS,
            currentWorldSeriesTeams: currentWS,
            currentWorldSeriesWinner: currentChampion.isEmpty ? nil : currentChampion
        )

        Task {
            do {
                try await store.saveAdminState(state)
                await MainActor.run {
                    saveMessage = "Saved."
                }
            } catch {
                await MainActor.run {
                    saveMessage = error.localizedDescription
                }
            }
        }
    }
}
