//
//  PhotoChallengeView.swift
//  Best Man Challenge
//

import SwiftUI
import PhotosUI

struct PhotoChallengeView: View {
    let challenge: WeeklyChallenge
    @EnvironmentObject var session: SessionStore

    @StateObject private var store = PhotoChallengeStore()
    @State private var selectedItems: [String: PhotosPickerItem] = [:]  // promptId -> item
    @State private var previewImages: [String: UIImage] = [:]           // promptId -> local preview

    private var config: WeeklyChallengePhotoConfig? { challenge.photo_challenge }

    private var isLocked: Bool {
        if let end = challenge.endDate { return Date() >= end }
        return challenge.isLocked
    }

    private var linkedPlayerId: String? { session.profile?.linkedPlayerId }
    private var displayName: String?    { session.profile?.displayName }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                headerCard

                if let config {
                    scoringRulesCard(config)
                    promptsSection(config)
                } else {
                    Text("Photo challenge not configured.")
                        .foregroundStyle(.secondary)
                        .padding()
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationTitle("Photo Challenge")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear  { store.start(challengeId: challenge.id) }
        .onDisappear { store.stop() }
        .alert("Error", isPresented: .init(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(challenge.title)
                .font(.title2.bold())
            Text(challenge.description)
                .foregroundStyle(.secondary)
                .font(.subheadline)

            if isLocked {
                Label("Submissions are closed", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Scoring rules card

    private func scoringRulesCard(_ config: WeeklyChallengePhotoConfig) -> some View {
        let confirmed = store.submission?.validatedBaseScore(pointsPerSubmission: config.points_per_submission) ?? 0
        let pending   = store.submission?.pendingCount() ?? 0
        let bonus     = store.submission?.bonusScore(bonusPointsPerWinner: config.bonus_points_per_winner) ?? 0

        return VStack(alignment: .leading, spacing: 6) {
            Label("How it works", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(Color.accent)

            Text("• \(config.points_per_submission) points for each validated photo")
            Text("• You must be in your photo")
                .foregroundStyle(.orange)
            Text("• \(config.bonus_points_per_winner) bonus point per category — \(config.judge_name ?? "judge") picks the winner")
            Text("• Points are confirmed after review")
                .foregroundStyle(.secondary)

            if let sub = store.submission, !sub.photos.isEmpty {
                Divider()
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("\(confirmed + bonus)")
                            .font(.title3.bold()).foregroundStyle(.green)
                        Text("confirmed").font(.caption).foregroundStyle(.secondary)
                    }
                    if pending > 0 {
                        VStack(spacing: 2) {
                            Text("\(pending * config.points_per_submission)")
                                .font(.title3.bold()).foregroundStyle(.orange)
                            Text("pending").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Prompts

    private func promptsSection(_ config: WeeklyChallengePhotoConfig) -> some View {
        VStack(spacing: 16) {
            ForEach(config.prompts) { prompt in
                promptCard(prompt: prompt, config: config)
            }
        }
    }

    private func promptCard(prompt: PhotoChallengePrompt, config: WeeklyChallengePhotoConfig) -> some View {
        let existingEntry = store.submission?.photos[prompt.id]
        let previewImage  = previewImages[prompt.id]
        let isUploading   = store.isUploading && store.uploadingPromptId == prompt.id
        let isWinner      = store.submission?.bonusWinners[prompt.id] == true
        let status        = store.submission?.photoStatuses[prompt.id]
        let isSubmitted   = existingEntry != nil

        return VStack(alignment: .leading, spacing: 12) {

            // Prompt header
            HStack {
                Text(prompt.emoji).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(prompt.label).font(.headline)
                    Text(prompt.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isWinner {
                    Label("Winner!", systemImage: "trophy.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)
                }
                statusBadge(status: status, isSubmitted: isSubmitted)
            }

            // Photo display or placeholder
            if let img = previewImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let url = existingEntry?.url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        photoPlaceholder(label: "Failed to load")
                    default:
                        ProgressView().frame(maxWidth: .infinity).frame(height: 180)
                    }
                }
            } else {
                photoPlaceholder(label: "No photo yet")
            }

            // Pick / replace button
            if !isLocked {
                PhotosPicker(
                    selection: Binding(
                        get: { selectedItems[prompt.id] },
                        set: { selectedItems[prompt.id] = $0 }
                    ),
                    matching: .images
                ) {
                    HStack {
                        if isUploading {
                            ProgressView().scaleEffect(0.8)
                        }
                        Text(existingEntry != nil ? "Replace Photo" : "Add Photo")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUploading)
                .onChange(of: selectedItems[prompt.id]) { _, item in
                    guard let item else { return }
                    Task { await handlePhotoSelection(item: item, promptId: prompt.id) }
                }
            }

            // Status hint
            if let status {
                statusHint(status, config: config)
            } else if isSubmitted {
                Text("⏳ Submitted — pending review")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor(status: status, isSubmitted: isSubmitted), lineWidth: 1.5)
        )
    }

    // MARK: - Status helpers

    @ViewBuilder
    private func statusBadge(status: String?, isSubmitted: Bool) -> some View {
        if let status {
            switch status {
            case "valid":
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green).font(.title3)
            case "invalid":
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red).font(.title3)
            default:
                if isSubmitted {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.orange).font(.title3)
                }
            }
        } else if isSubmitted {
            Image(systemName: "clock.fill")
                .foregroundStyle(.orange).font(.title3)
        }
    }

    @ViewBuilder
    private func statusHint(_ status: String, config: WeeklyChallengePhotoConfig) -> some View {
        switch status {
        case "valid":
            Text("✅ Validated — \(config.points_per_submission) pts awarded")
                .font(.caption).foregroundStyle(.green)
        case "invalid":
            Text("❌ Marked invalid — no points")
                .font(.caption).foregroundStyle(.red)
        default:
            Text("⏳ Submitted — pending review")
                .font(.caption).foregroundStyle(.orange)
        }
    }

    private func borderColor(status: String?, isSubmitted: Bool) -> Color {
        guard isSubmitted else { return .clear }
        switch status {
        case "valid":   return .green.opacity(0.5)
        case "invalid": return .red.opacity(0.5)
        default:        return .orange.opacity(0.4)
        }
    }

    private func photoPlaceholder(label: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.12))
                .frame(maxWidth: .infinity)
                .frame(height: 140)
            VStack(spacing: 6) {
                Image(systemName: "camera.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Photo selection handler

    private func handlePhotoSelection(item: PhotosPickerItem, promptId: String) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            store.errorMessage = "Couldn't read the selected photo."
            return
        }

        let compressed: Data
        if let uiImage = UIImage(data: data),
           let jpeg = uiImage.jpegData(compressionQuality: 0.75) {
            compressed = jpeg
            await MainActor.run { previewImages[promptId] = uiImage }
        } else {
            compressed = data
        }

        await store.uploadPhoto(
            imageData: compressed,
            promptId: promptId,
            challengeId: challenge.id,
            linkedPlayerId: linkedPlayerId,
            displayName: displayName
        )

        await MainActor.run { selectedItems[promptId] = nil }
    }
}
