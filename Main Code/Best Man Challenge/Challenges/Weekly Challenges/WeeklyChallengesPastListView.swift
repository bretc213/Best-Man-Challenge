//
//  WeeklyChallengesPastListView.swift
//  Best Man Challenge
//

import SwiftUI

struct WeeklyChallengesPastListView: View {
    @ObservedObject var store: WeeklyChallengesHistoryStore
    @EnvironmentObject var session: SessionStore

    var body: some View {
        ThemedScreen {
            Group {
                if store.isLoading {
                    VStack(spacing: 12) {
                        ProgressView().tint(Color.accent)
                        Text("Loading past challenges…")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if let err = store.errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.accent)
                        Text("Couldn't load challenges")
                            .font(.headline)
                            .foregroundStyle(Color.textPrimary)
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if store.pastChallenges.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.accent.opacity(0.6))
                        Text("No past challenges yet.")
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(store.pastChallenges) { ch in
                                NavigationLink {
                                    WeeklyChallengePastDetailView(challenge: ch)
                                        .environmentObject(session)
                                } label: {
                                    pastChallengeRow(ch)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Past Challenges")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear  { store.startListening() }
        .onDisappear { store.stopListening() }
    }

    private func pastChallengeRow(_ ch: WeeklyChallenge) -> some View {
        HStack(spacing: 14) {
            // Week badge
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accent.opacity(0.18))
                    .frame(width: 48, height: 48)
                VStack(spacing: 1) {
                    Text("WK")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.accent.opacity(0.8))
                    Text("\(ch.week)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accent)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(ch.title)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(ch.type.displayName)
                    .font(.caption.bold())
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.accent.opacity(0.12))
                    .foregroundStyle(Color.accent)
                    .clipShape(Capsule())
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(Color.textSecondary)
        }
        .padding(12)
        .background(Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private extension ChallengeType {
    var displayName: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
