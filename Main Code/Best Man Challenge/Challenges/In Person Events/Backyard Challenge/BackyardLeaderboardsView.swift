import SwiftUI

enum BackyardLeaderboardMode: Hashable {
    case overall
    case gameGroup(String)
}

struct BackyardLeaderboardsView: View {
    let mode: BackyardLeaderboardMode

    @EnvironmentObject private var store: BackyardChallengeStore

    var body: some View {
        ThemedScreen {
            List {
                switch mode {
                case .overall:
                    Section("Overall Backyard Game Leaderboard") {
                        BackyardLeaderboardList(
                            rows: store.overallLeaderboard(),
                            showThru: false
                        )
                    }

                case .gameGroup(let title):
                    sections(for: title)
                }
            }
            .listStyle(.plain)
            .navigationTitle(title)
        }
    }

    private var title: String {
        switch mode {
        case .overall:
            return "Overall Leaderboard"

        case .gameGroup(let title):
            return "\(title) Leaderboard"
        }
    }

    @ViewBuilder
    private func sections(for title: String) -> some View {
        if title == "Bucket Golf" {
            Section("18 Holes — Individual  ·  Mario Kart ×3") {
                BackyardLeaderboardList(rows: store.golf18Leaderboard(), showThru: false)
            }

            Section("Closest to the Pin  ·  Mario Kart ×1") {
                BackyardLeaderboardList(rows: store.closestToPinLeaderboard(), showThru: false)
            }

            Section("Alt Shot — 9 Holes (Doubles)") {
                BackyardLeaderboardList(rows: store.altShotRows(), showThru: false)
            }

            Section("Combined Total") {
                BackyardLeaderboardList(rows: store.bucketGolfOverallRows(), showThru: false)
            }

        } else if title == "Cornhole" {
            Section("Deka  ·  Mario Kart ×1") {
                BackyardLeaderboardList(rows: store.dekaLeaderboard(), showThru: false)
            }

            Section("Singles Tournament  ·  Mario Kart ×2") {
                BackyardLeaderboardList(rows: store.cornholeSinglesBonusRows(), showThru: false)
            }

            Section("Combined Total") {
                BackyardLeaderboardList(rows: store.cornholeOverallRows(), showThru: false)
            }

        } else if title == "Ladder Ball" {
            Section("Ladder Ball — Final Results") {
                BackyardLeaderboardList(rows: store.ladderBallRows(), showThru: false)
            }

        } else if title == "QB54" {
            Section("QB54 — Final Results") {
                BackyardLeaderboardList(rows: store.qb54Rows(), showThru: false)
            }
        }
    }
}
