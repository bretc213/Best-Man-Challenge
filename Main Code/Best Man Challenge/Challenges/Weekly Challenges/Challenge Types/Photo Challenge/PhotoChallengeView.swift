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

                // Header
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
        VStack(alignment: .leading, spacing: 6) {
            Label("How it works", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(Color.accent)

            Text("• \(config.points_per_submission) points for each photo submitted")
            Text("• \(config.bonus_points_per_winner) bonus point per category — \(config.judge_name ?? "judge") picks the winner")
            Text("• Max \(config.prompts.count * config.points_per_submission + config.prompts.count * config.bonus_points_per_winner) points total")
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

                if existingEntry != nil {
                    Text("✅ Submitted · \(config.points_per_submission) pts earned")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            } else if existingEntry != nil {
                Text("✅ Submitted")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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

        // Compress to ~1 MB JPEG
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

        // Clear the picker selection so re-selecting same photo fires onChange again
        await MainActor.run { selectedItems[promptId] = nil }
    }
}
