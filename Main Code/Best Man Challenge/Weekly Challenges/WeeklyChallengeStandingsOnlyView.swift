//
//  WeeklyChallengeStandingsOnlyView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/8/26.
//


import SwiftUI

struct WeeklyChallengeStandingsOnlyView: View {
    @EnvironmentObject var session: SessionStore

    @ObservedObject var manager: WeeklyChallengeManager
    @ObservedObject var standingsStore: WeeklyChallengeStandingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week Standings")
                .font(.title2.bold())

            switch manager.state {
            case .idle, .loading:
                ProgressView("Loading...")
                    .padding(.top, 8)

            case .empty:
                Text("No weekly challenge active.")
                    .foregroundStyle(.secondary)

            case .failed(let msg):
                Text("Couldn’t load: \(msg)")
                    .foregroundStyle(.secondary)

            case .loaded:
                if let ch = manager.currentChallenge {
                    WeeklyChallengeStandingsView(store: standingsStore)
                        .onAppear {
                            startStandings(for: ch)
                        }
                        .onChange(of: manager.currentChallenge?.id) { _, _ in
                            if let ch2 = manager.currentChallenge {
                                startStandings(for: ch2)
                            } else {
                                standingsStore.stopListening()
                            }
                        }
                } else {
                    Text("No weekly challenge active.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 8)
    }

    private func startStandings(for challenge: WeeklyChallenge) {
        let defaultMax: Int = {
            switch challenge.type {
            case .quiz:
                let qCount = challenge.quiz?.questions?.count ?? 0
                let ppc = challenge.quiz?.points_per_correct ?? 1
                return qCount * ppc
            default:
                return 0
            }
        }()

        standingsStore.startListening(
            weekId: challenge.id,
            defaultMaxScore: defaultMax
        )
    }
}
