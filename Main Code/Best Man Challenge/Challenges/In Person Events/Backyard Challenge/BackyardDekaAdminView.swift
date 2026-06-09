import SwiftUI

struct BackyardDekaAdminView: View {
    @EnvironmentObject private var store: BackyardChallengeStore

    var body: some View {
        ThemedScreen {
            List {
                Section("Cornhole Deka Admin Input") {
                    ForEach(store.players) { player in
                        NavigationLink {
                            DekaPlayerRoundsView(player: player)
                                .environmentObject(store)
                        } label: {
                            HStack {
                                Text(player.displayName)
                                    .font(.headline)

                                Spacer()

                                Text("\(total(for: player))")
                                    .font(.headline)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }

                Section("Leaderboard") {
                    NavigationLink("View Deka Leaderboard") {
                        BackyardCornholeLeaderboardView(initialTab: .deka)
                            .environmentObject(store)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Cornhole Deka")
        }
    }

    private func total(for player: BackyardPlayer) -> Int {
        (1...10).compactMap { store.dekaRoundScores[$0]?[player.id] }.reduce(0, +)
    }
}

private struct DekaPlayerRoundsView: View {
    let player: BackyardPlayer

    @EnvironmentObject private var store: BackyardChallengeStore

    @State private var inputs: [Int: String] = [:]

    var body: some View {
        ThemedScreen {
            List {
                Section(player.displayName) {
                    ForEach(1...10, id: \.self) { round in
                        HStack {
                            Text("Round \(round)")
                            Spacer()

                            TextField(
                                "Score",
                                text: Binding(
                                    get: {
                                        inputs[round] ?? ""
                                    },
                                    set: {
                                        inputs[round] = $0
                                    }
                                )
                            )
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)

                            Button("Save") {
                                save(round: round)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                Section("Total") {
                    HStack {
                        Text("Deka Total")
                        Spacer()
                        Text("\(total)")
                            .font(.headline)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(player.displayName)
            .onAppear {
                loadInputs()
            }
            .onChange(of: store.dekaRoundScores) { _ in
                loadInputs()
            }
        }
    }

    private var total: Int {
        (1...10).compactMap { store.dekaRoundScores[$0]?[player.id] }.reduce(0, +)
    }

    private func loadInputs() {
        var next: [Int: String] = [:]

        for round in 1...10 {
            if let score = store.dekaRoundScores[round]?[player.id] {
                next[round] = "\(score)"
            }
        }

        inputs = next
    }

    private func save(round: Int) {
        guard let text = inputs[round],
              let score = Int(text)
        else {
            return
        }

        Task {
            await store.saveDekaScore(
                round: round,
                playerId: player.id,
                score: score
            )
        }
    }
}
