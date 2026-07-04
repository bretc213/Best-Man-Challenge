//
//  MurderMysterySuspectsView.swift
//  Best Man Challenge
//
//  "Dead in the Dust" — suspect grid + dossier sheets
//

import SwiftUI

struct MurderMysterySuspectsView: View {
    @State private var selected: Suspect?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(MurderMysteryData.suspects) { suspect in
                    Button {
                        selected = suspect
                    } label: {
                        suspectCard(suspect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Color.background)
        .sheet(item: $selected) { suspect in
            MMSuspectDossierView(suspect: suspect)
        }
    }

    private func suspectCard(_ suspect: Suspect) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(suspect.accentColor)
                    .frame(width: 56, height: 56)
                Text(suspect.initials)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
            Text(suspect.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            Text(suspect.role)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(String(suspect.bio.prefix(100)) + "…")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
            Text("See full dossier →")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(suspect.accentColor.opacity(0.5)))
    }
}

// MARK: - Dossier

struct MMSuspectDossierView: View {
    let suspect: Suspect
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(suspect.accentColor)
                                    .frame(width: 64, height: 64)
                                Text(suspect.initials)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(suspect.name)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Color.textPrimary)
                                Text(suspect.role)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(suspect.bio)
                            .font(.subheadline)
                            .foregroundStyle(Color.textPrimary)

                        VStack(spacing: 0) {
                            ForEach(Array(suspect.details.enumerated()), id: \.offset) { _, detail in
                                HStack(alignment: .top) {
                                    Text(detail.label)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 96, alignment: .leading)
                                    Text(detail.value)
                                        .font(.footnote)
                                        .foregroundStyle(Color.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 8)
                                Divider().overlay(Color.white.opacity(0.08))
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))

                        Text("They remain a suspect until the case is closed.")
                            .font(.caption.italic())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Dossier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
