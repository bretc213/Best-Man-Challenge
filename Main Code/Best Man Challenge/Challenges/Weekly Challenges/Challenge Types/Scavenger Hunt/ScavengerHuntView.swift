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
    @State private var previews: [String: UIImage] = [:]

    private var config: WeeklyChallengeScavengerHuntConfig? { challenge.scavenger_hunt }

    private var isLocked: Bool {
        if let end = challenge.endDate { return Date() >= end }
        return challenge.isLocked
    }

    private var linkedPlayerId: String? { session.profile?.linkedPlayerId }
    private var displayName: String? { session.profile?.displayName }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                headerCard

                if let config {
                    if let note = config.authenticity_note {
                        authenticityCard(note)
                    }
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

    // MARK: - Authenticity disclaimer

    private func authenticityCard(_ note: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.subheadline)
            Text(note)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - How it works

    private func howItWorksCard(_ config: WeeklyChallengeScavengerHuntConfig) -> some View {
        let sub = store.submission
        let confirmed  = sub?.validatedScore(bonusItemId: config.bonus_item_id) ?? 0
        let pending    = sub?.pendingCount() ?? 0
        let total      = config.items.count

        return VStack(alignment: .leading, spacing: 6) {
            Label("How it works", systemImage: "map.fill").font(.headline).foregroundStyle(.accent)
            Text("Find each item and snap a photo as proof.")
            Text("\(config.points_per_item) pt per item · \(confirmed) pts confirmed · \(pending) pending review")
                .font(.caption).foregroundStyle(.secondary)
            if let bonusId = config.bonus_item_id,
               config.items.first(where: { $0.id == bonusId })?.bonus_eligible == true {
                Text("Item 10 earns a bonus point if both Bret & Amanda are in the photo.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("\(confirmed)/\(total) items validated")
                .font(.caption).foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Items list

    private func itemsSection(_ config: WeeklyChallengeScavengerHuntConfig) -> some View {
        let sorted = config.items.sorted { ($0.position ?? 99) < ($1.position ?? 99) }
        return VStack(spacing: 12) {
            ForEach(sorted) { item in
                itemCard(item: item, config: config)
            }
        }
    }

    private func itemCard(item: ScavengerHuntItem, config: WeeklyChallengeScavengerHuntConfig) -> some View {
        let existingURL = store.submission?.completedItems[item.id]
        let status      = store.submission?.itemStatuses[item.id]
        let isSubmitted = existingURL != nil
        let preview     = previews[item.id]
        let isUploading = store.isUploading && store.uploadingItemId == item.id
        let isBonusItem = item.bonus_eligible == true

        return VStack(alignment: .leading, spacing: 10) {

            // Item header row
            HStack(spacing: 10) {
                Text(item.emoji).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.clue).font(.subheadline)
                    if let bonusClue = item.bonus_clue, isBonusItem {
                        Text(bonusClue)
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.82, green: 0.66, blue: 0.22))
                    }
                }
                Spacer()
                statusBadge(status: status, isSubmitted: isSubmitted)
            }

            // Bonus subjects selector (item 10 only)
            if isBonusItem && isSubmitted && !isLocked {
                subjectsSelector(item: item, config: config)
            }

            // Photo preview
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

            // Upload button
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
                        Text(isSubmitted ? "Replace Photo" : "Upload Proof")
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

            // Status hint
            if let status {
                statusHint(status)
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

    // MARK: - Subjects selector (item 10 bonus)

    private func subjectsSelector(item: ScavengerHuntItem, config: WeeklyChallengeScavengerHuntConfig) -> some View {
        let current = store.submission?.item10Subjects ?? ""

        return VStack(alignment: .leading, spacing: 8) {
            Text("Who's in this photo?")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                subjectButton("Bret only", value: "bret", current: current, item: item, config: config)
                subjectButton("Amanda only", value: "amanda", current: current, item: item, config: config)
                subjectButton("Both 🎉", value: "both", current: current, item: item, config: config)
            }
        }
        .padding(.vertical, 4)
    }

    private func subjectButton(
        _ label: String,
        value: String,
        current: String,
        item: ScavengerHuntItem,
        config: WeeklyChallengeScavengerHuntConfig
    ) -> some View {
        let isSelected = current == value
        let gold = Color(red: 0.82, green: 0.66, blue: 0.22)

        return Button {
            Task {
                await store.setSubjects(
                    challengeId: challenge.id,
                    itemId: item.id,
                    subjects: value
                )
            }
        } label: {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(isSelected ? gold : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? gold.opacity(0.15) : Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? gold : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
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
    private func statusHint(_ status: String) -> some View {
        switch status {
        case "valid":
            Text("✅ Validated — point awarded")
                .font(.caption).foregroundStyle(.green)
        case "invalid":
            Text("❌ Marked invalid — no point")
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

    // MARK: - Photo selection handler

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

        await MainActor.run { selectedItems[itemId] = nil }
    }
}
