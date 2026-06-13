//
//  ScavengerHuntView.swift
//  Best Man Challenge
//

import SwiftUI
import PhotosUI

struct ScavengerHuntView: View {
    let challenge: WeeklyChallenge
    @EnvironmentObject var session: SessionStore

    @StateObject private var store = ScavengerHuntStore()
    @State private var selectedItems: [String: PhotosPickerItem] = [:]
    @State private var previews:       [String: UIImage] = [:]

    private var config: WeeklyChallengeScavengerHuntConfig? { challenge.scavenger_hunt }

    private var isLocked: Bool {
        if let end = challenge.endDate { return Date() >= end }
        return challenge.isLocked
    }

    private var linkedPlayerId: String? { session.profile?.linkedPlayerId }
    private var displayName:    String? { session.profile?.displayName }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                headerCard

                if let config {
                    howItWorksCard(config)
                    itemsSection(config)
                } else {
                    Text("Scavenger hunt not configured.")
                        .foregroundStyle(.secondary)
                        .padding()
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationTitle("Scavenger Hunt")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear  { store.start(challengeId: challenge.id) }
        .onDisappear { store.stop() }
        .alert("Error", isPresented: .init(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(challenge.title).font(.title2.bold())
            Text(challenge.description).font(.subheadline).foregroundStyle(.secondary)
            if isLocked {
                Label("Submissions closed", systemImage: "lock.fill")
                    .font(.footnote).foregroundStyle(.red)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - How it works

    private func howItWorksCard(_ config: WeeklyChallengeScavengerHuntConfig) -> some View {
        let completed = store.submission?.completedItems.count ?? 0
        let total     = config.items.count
        let pts       = store.submission?.score(pointsPerItem: config.points_per_item) ?? 0

        return VStack(alignment: .leading, spacing: 6) {
            Label("How it works", systemImage: "map.fill").font(.headline).foregroundStyle(.accent)
            Text("Find each item and snap a photo as proof.")
            Text("\(config.points_per_item) pt per item · \(completed)/\(total) completed · \(pts) pts earned")
                .font(.caption).foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Items

    private func itemsSection(_ config: WeeklyChallengeScavengerHuntConfig) -> some View {
        VStack(spacing: 12) {
            ForEach(config.items) { item in
                itemCard(item: item, config: config)
            }
        }
    }

    private func itemCard(item: ScavengerHuntItem, config: WeeklyChallengeScavengerHuntConfig) -> some View {
        let isDone       = store.submission?.completedItems[item.id] != nil
        let preview      = previews[item.id]
        let existingURL  = store.submission?.completedItems[item.id]
        let isUploading  = store.isUploading && store.uploadingItemId == item.id

        return VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 10) {
                Text(item.emoji).font(.title2)
                Text(item.clue).font(.subheadline)
                Spacer()
                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }
            }

            // Photo
            if let img = preview {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(maxWidth: .infinity).frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if let urlStr = existingURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .frame(maxWidth: .infinity).frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    default: ProgressView().frame(height: 160)
                    }
                }
            }

            // Button
            if !isLocked {
                PhotosPicker(
                    selection: Binding(
                        get: { selectedItems[item.id] },
                        set: { selectedItems[item.id] = $0 }
                    ),
                    matching: .images
                ) {
                    HStack {
                        if isUploading { ProgressView().scaleEffect(0.8) }
                        Text(isDone ? "Replace Photo" : "Upload Proof")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUploading)
                .onChange(of: selectedItems[item.id]) { _, newItem in
                    guard let newItem else { return }
                    Task { await handleSelection(newItem, itemId: item.id, config: config) }
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Photo selection

    private func handleSelection(_ item: PhotosPickerItem, itemId: String, config: WeeklyChallengeScavengerHuntConfig) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            store.errorMessage = "Couldn't read the selected photo."
            return
        }

        var compressed = data
        if let ui = UIImage(data: data), let jpeg = ui.jpegData(compressionQuality: 0.75) {
            compressed = jpeg
            await MainActor.run { previews[itemId] = ui }
        }

        await store.uploadProof(
            imageData: compressed,
            itemId: itemId,
            challengeId: challenge.id,
            linkedPlayerId: linkedPlayerId,
            displayName: displayName
        )

        await store.syncScore(challengeId: challenge.id, pointsPerItem: config.points_per_item)
        await MainActor.run { selectedItems[itemId] = nil }
    }
}
