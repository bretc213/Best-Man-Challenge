//
//  RulesView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/2/26.
//


import SwiftUI

struct RulesView: View {

    var body: some View {
        ThemedScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {

                    titleSection()

                    ruleSection(
                        title: "General Expectations",
                        bullets: [
                            "Show up. Effort matters.",
                            "Perform well and stay consistent across events.",
                            "Some events will be secret and announced day-of.",
                            "Do not help other contestants unless the challenge explicitly allows it."
                        ]
                    )

                    ruleSection(
                        title: "Fair Play",
                        bullets: [
                            "Do not use AI, the internet, or outside help on challenges that prohibit it.",
                            "Any form of cheating may result in point penalties or disqualification."
                        ]
                    )

                    ruleSection(
                        title: "Scoring System",
                        bullets: [
                            "Scoring follows a Mario Kart-style system (e.g. 15, 12, 10, 8, 7, 6, 5, 4, 3, 2, 1).",
                            "In-person events are worth triple points (e.g. 45, 36, 30, 24, 21, 18, 15, 12, 9, 6, 3).",
                            "In-person events will generally be worth more than at-home events."
                        ]
                    )

                    ruleSection(
                        title: "Authority & Rulings",
                        bullets: [
                            "Refs have full authority on day-of rulings based on what they observe.",
                            "The Commissioner has final say on all disputes or rules not previously discussed."
                        ]
                    )

                    ruleSection(
                        title: "Bonus Points",
                        bullets: [
                            "3 bonus points are awarded to anyone who finishes above Bret in an event.",
                            "Ties go to the Groom — no bonus points are awarded in tied results."
                        ]
                    )

                    placeholderSection(
                        title: "Unable to Attend",
                        description: "Details on missed events, make-ups, or penalties will be defined as needed."
                    )

                    placeholderSection(
                        title: "Caught Cheating",
                        description: "Penalties will range from point deductions to full disqualification depending on severity."
                    )

                }
                .padding()
            }
            .navigationTitle("Rules")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Sections

    private func titleSection() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Best Man Challenge Rules")
                .font(.title2)
                .bold()

            Text("Read carefully. Compete fairly. Have fun.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func ruleSection(title: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ForEach(bullets, id: \.self) { bullet in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text(bullet)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.body)
            }
        }
        .cardStyle()
    }

    private func placeholderSection(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }
}

#Preview {
    NavigationView {
        RulesView()
    }
}
