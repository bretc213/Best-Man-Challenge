//
//  PropBetsView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 2/3/26.
//


import SwiftUI

struct PropBetsView: View {
    let challengeId: String
    @StateObject private var store = PropBetsStore()

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()

            if store.isLoading {
                ProgressView("Loading props...")
                    .foregroundStyle(Color.textPrimary)

            } else if let msg = store.errorMessage {
                VStack(spacing: 12) {
                    Text("Something went wrong")
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary)
                    Text(msg)
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

            } else {
                content
            }
        }
        .navigationTitle(store.challenge?.title ?? "Prop Bets")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: challengeId) {
            store.start(challengeId: challengeId)
        }
        .onDisappear {
            store.stop()
        }
        .safeAreaInset(edge: .bottom) {
            submitBar
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                if let challenge = store.challenge {
                    Text(challenge.description)
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, 16)

                    if store.isLocked {
                        Text("Picks are locked.")
                            .font(.subheadline)
                            .foregroundStyle(Color.red)
                            .padding(.horizontal, 16)
                    } else {
                        Text("You can change picks any time before kickoff.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, 16)

                        if let last = store.lastSubmittedAt {
                            Text("Last submitted: \(last.formatted(date: .abbreviated, time: .shortened))")
                                .font(.footnote)
                                .foregroundStyle(Color.textSecondary)
                                .padding(.horizontal, 16)
                        }
                    }
                }

                ForEach(store.props, id: \.id) { prop in
                    PropCard(
                        prop: prop,
                        selectedOptionId: store.selections[prop.id],
                        isLocked: store.isLocked,
                        onSelect: { optionId in
                            store.selectOption(propId: prop.id, optionId: optionId)
                        }
                    )
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 24)
            }
            .padding(.top, 12)
            .padding(.bottom, 80) // room for sticky bar
        }
    }

    private var submitBar: some View {
        VStack(spacing: 10) {
            Divider().opacity(0.25)

            Button {
                Task { await store.submitPicks() }
            } label: {
                Text(submitTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(submitDisabled)
            .opacity(submitDisabled ? 0.6 : 1.0)

            if store.isLocked {
                Text("Locked at kickoff.")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
            } else if store.isDirty {
                Text("Changes not submitted yet.")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
            } else {
                Text("All set.")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private var submitDisabled: Bool {
        store.isLocked || store.isSubmitting || !store.isDirty
    }

    private var submitTitle: String {
        if store.isSubmitting { return "Submitting..." }
        if store.lastSubmittedAt != nil { return "Update Picks" }
        return "Submit Picks"
    }
}

private struct PropCard: View {
    let prop: PropBet
    let selectedOptionId: String?
    let isLocked: Bool
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(prop.prompt)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                if let line = prop.line, prop.kind == .overUnder {
                    Text("Line: \(formatLine(line))")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            VStack(spacing: 10) {
                ForEach(prop.options.sorted(by: { $0.position < $1.position }), id: \.id) { opt in
                    let isSelected = (selectedOptionId == opt.id)

                    Button {
                        guard !isLocked else { return }
                        onSelect(opt.id)
                    } label: {
                        HStack {
                            Text(opt.label)
                                .font(.subheadline)
                            Spacer()
                            Text(formatOdds(opt.oddsAmerican))
                                .font(.subheadline)
                        }
                        .foregroundStyle(isSelected ? Color.black : Color.textPrimary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(isSelected ? Color.accent : Color.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .opacity(isLocked && !isSelected ? 0.65 : 1.0)
                    }
                    .disabled(isLocked)
                }
            }
        }
        .padding(14)
        .background(Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func formatOdds(_ n: Int?) -> String {
        guard let n else { return "—" }
        return n > 0 ? "+\(n)" : "\(n)"
    }

    private func formatLine(_ x: Double) -> String {
        if x.rounded() == x { return String(Int(x)) }
        return String(format: "%.1f", x)
    }
}
