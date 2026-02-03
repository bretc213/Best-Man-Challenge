//
//  WeeklyHowToPlayView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/18/26.
//


import SwiftUI

struct WeeklyHowToPlayView: View {
    @EnvironmentObject var manager: WeeklyChallengeManager
    @EnvironmentObject var session: SessionStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                Text("How To Play")
                    .font(.title2.bold())
                    .padding(.top, 6)

                infoCard(
                    title: "1) New challenge each week",
                    body: "When a weekly challenge is active, it will appear under the “This Week” tab."
                )

                infoCard(
                    title: "2) Make your picks / answers",
                    body: "Tap “Start Quiz” to enter your picks. You can edit until the challenge locks."
                )

                infoCard(
                    title: "3) Lock & scoring",
                    body: "Some weeks are scored immediately, and some may be scored after results are finalized. If scoring is pending, you’ll see a note on your submission."
                )

                infoCard(
                    title: "4) Standings",
                    body: "Check the Standings tab to see how everyone did. Refs/admins are shown separately from players."
                )

                infoCard(
                    title: "Ref / Admin note",
                    body: "Refs can submit weekly challenges without being linked to a player. Players must be linked to appear on leaderboards."
                )

                Divider().opacity(0.35)

                HStack {
                    Text("Status")
                        .font(.headline)

                    Spacer()

                    Text(statusText)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)

                if let c = manager.currentChallenge {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Active Challenge")
                            .font(.headline)

                        Text(c.title)
                            .font(.subheadline.weight(.semibold))

                        if !c.description.isEmpty {
                            Text(c.description)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private var statusText: String {
        switch manager.state {
        case .idle: return "Idle"
        case .loading: return "Loading…"
        case .loaded: return "Active"
        case .empty: return "No active challenge"
        case .failed: return "Error"
        }
    }

    private func infoCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            Text(body)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
