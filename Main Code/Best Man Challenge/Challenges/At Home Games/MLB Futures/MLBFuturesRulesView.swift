//
//  MLBFuturesRulesView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 3/14/26.
//


import SwiftUI

struct MLBFuturesRulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    rulesSection(
                        title: "How to Play",
                        lines: [
                            "Rank all 5 teams in each of the 6 MLB divisions.",
                            "Pick Seeds 1-6 for both the AL and NL.",
                            "Seeds 1-3 must be your 3 division winners.",
                            "Seeds 4-6 are your wild card teams.",
                            "Pick 4 teams in each league to make the Division Series.",
                            "Pick 2 teams in each league to make the Championship Series.",
                            "Pick the 2 World Series teams and then the champion."
                        ]
                    )

                    rulesSection(
                        title: "Division Scoring",
                        lines: [
                            "Correct place: +3",
                            "Off by 1: +1",
                            "Off by 2: 0",
                            "Off by 3: -1",
                            "Off by 4: -3"
                        ]
                    )

                    rulesSection(
                        title: "Seed Scoring",
                        lines: [
                            "Correct team in correct seed: +5",
                            "Correct playoff team but wrong seed: +3"
                        ]
                    )

                    rulesSection(
                        title: "Round Scoring",
                        lines: [
                            "Division Series team: +5 each",
                            "Championship Series team: +10 each",
                            "World Series team: +15 each",
                            "World Series champion: +20"
                        ]
                    )

                    rulesSection(
                        title: "Live Standings",
                        lines: [
                            "Standings are scored against the current admin-entered MLB standings and playoff field.",
                            "As standings change, later rounds and scores update automatically."
                        ]
                    )
                }
                .padding()
            }
            .navigationTitle("Rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rulesSection(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text(line)
                    }
                }
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
    }
}