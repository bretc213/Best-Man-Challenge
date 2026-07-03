//
//  ScavengerHuntAdminView.swift
//  Best Man Challenge
//
//  Admin grading flow:
//   • Root: list of players who have submitted (submission count, validated count)
//   • Tap player → ScavengerHuntPlayerGraderView (all their submitted items)
//   • Long-press item photo → mark Valid or Invalid
//   • Score syncs to submissions/ after each grade
//

import SwiftUI
import FirebaseFirestore

// MARK: - Root: player list

struct ScavengerHuntAdminView: View {
    let challenge: WeeklyChallenge

    @StateObject private var vm = ScavengerHuntAdminVM()

    private var config: WeeklyChallengeScavengerHuntConfig? { challenge.scavenger_hunt }

    var body: some View {
        List {
            if vm.isLoading {
                HStack {
                    ProgressView()
                    Text("Loading submissions…").foregroundStyle(.secondary)
                }
            } else if vm.submissions.isEmpty {
                ContentUnavailableView("No submissions yet", systemImage: "photo.stack")
            } else {
                ForEach(vm.submissions) { sub in
                    NavigationLink {
                        if let config {
                            ScavengerHuntPlayerGraderView(
                                challenge: challenge,
                                submission: sub,
                                config: config,
                                vm: vm
                            )
                        }
                    } label: {
                        playerRow(sub)
                    }
                }
            }
        }
        .navigationTitle("Grade Hunt — W\(challenge.week)")
        .navigationBarTitleDisplayMode(.inline)
        .task { vm.load(challengeId: challenge.id) }
        .onDisappear { vm.stop() }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private func playerRow(_ sub: ScavengerHuntSubmission) -> some View {
        let submitted  = sub.completedItems.count
        let validated  = sub.validatedScore(bonusItemId: challenge.scavenger_hunt?.bonus_item_id)
        let pending    = sub.pendingCount()

        return VStack(alignment: .leading, spacing: 3) {
            Text(sub.displayName ?? sub.uid)
                .font(.headline)
            HStack(spacing: 12) {
                Text("\(submitted) photo\(submitted == 1 ? "" : "s") submitted")
                    .font(.caption).foregroundStyle(.secondary)
                if validated > 0 {
                    Text("✅ \(validated) pts")
                        .font(.caption).foregroundStyle(.green)
                }
                if pending > 0 {
                    Text("⏳ \(pending) pending")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Per-player grading view

struct ScavengerHuntPlayerGraderView: View {
    let challenge: WeeklyChallenge
    let submission: ScavengerHuntSubmission
    let config: WeeklyChallengeScavengerHuntConfig
    @ObservedObject var vm: ScavengerHuntAdminVM

    // Mirror of this submission that updates as vm.submissions changes
    private var live: ScavengerHuntSubmission? {
        vm.submissions.first { $0.uid == submission.uid }
    }

    @State private var confirmingItemId: String?
    @State private var pendingStatus: String = "valid"

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var sortedItems: [ScavengerHuntItem] {
        config.items
            .filter { live?.completedItems[$0.id] != nil }
            .sorted { ($0.position ?? 99) < ($1.position ?? 99) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Score summary banner
                if let sub = live {
                    scoreBanner(sub)
                }

                Text("Long-press a photo to grade it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if sortedItems.isEmpty {
                    ContentUnavailableView(
                        "No photos submitted",
                        systemImage: "photo",
                        description: Text("This player hasn't submitted anything yet.")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(sortedItems) { item in
                            if let urlStr = live?.completedItems[item.id] {
                                photoCell(item: item, urlStr: urlStr, sub: live)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 12)
        }
        .navigationTitle(live?.displayName ?? submission.uid)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Grade Submission",
            isPresented: Binding(
                get: { confirmingItemId != nil },
                set: { if !$0 { confirmingItemId = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let itemId = confirmingItemId,
               let item = config.items.first(where: { $0.id == itemId }) {
                let currentStatus = live?.itemStatuses[itemId] ?? "pending"

                if currentStatus != "valid" {
                    Button("✅ Mark Valid") {
                        Task {
                            await vm.setItemStatus(
                                challengeId: challenge.id,
                                uid: submission.uid,
                                itemId: itemId,
                                status: "valid",
                                bonusItemId: config.bonus_item_id
                            )
                        }
                        confirmingItemId = nil
                    }
                }
                if currentStatus != "invalid" {
                    Button("❌ Mark Invalid", role: .destructive) {
                        Task {
                            await vm.setItemStatus(
                                challengeId: challenge.id,
                                uid: submission.uid,
                                itemId: itemId,
                                status: "invalid",
                                bonusItemId: config.bonus_item_id
                            )
                        }
                        confirmingItemId = nil
                    }
                }
                if currentStatus != "pending" {
                    Button("⏳ Reset to Pending") {
                        Task {
                            await vm.setItemStatus(
                                challengeId: challenge.id,
                                uid: submission.uid,
                                itemId: itemId,
                                status: "pending",
                                bonusItemId: config.bonus_item_id
                            )
                        }
                        confirmingItemId = nil
                    }
                }
                Button("Cancel", role: .cancel) { confirmingItemId = nil }
            }
        } message: {
            if let itemId = confirmingItemId,
               let item = config.items.first(where: { $0.id == itemId }) {
                let bonusNote = item.bonus_eligible == true
                    ? " (Item 10 — bonus if both in photo: \(live?.item10Subjects ?? "not set"))"
                    : ""
                Text("\(item.emoji) \(item.clue)\(bonusNote)")
            }
        }
    }

    // MARK: - Score banner

    private func scoreBanner(_ sub: ScavengerHuntSubmission) -> some View {
        let confirmed = sub.validatedScore(bonusItemId: config.bonus_item_id)
        let pending   = sub.pendingCount()

        return HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("\(confirmed)")
                    .font(.title2.bold())
                    .foregroundStyle(.green)
                Text("confirmed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider().frame(height: 36)
            VStack(spacing: 2) {
                Text("\(pending)")
                    .font(.title2.bold())
                    .foregroundStyle(.orange)
                Text("pending")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Photo cell

    private func photoCell(item: ScavengerHuntItem, urlStr: String, sub: ScavengerHuntSubmission?) -> some View {
        let status    = sub?.itemStatuses[item.id] ?? "pending"
        let isBonusItem = item.bonus_eligible == true
        let subjects  = sub?.item10Subjects

        return ZStack(alignment: .bottom) {
            if let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipped()
                    case .failure:
                        Color.secondary.opacity(0.2)
                            .frame(height: 180)
                            .overlay {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.secondary)
                            }
                    default:
                        Color.secondary.opacity(0.15)
                            .frame(height: 180)
                            .overlay { ProgressView() }
                    }
                }
            }

            // Bottom overlay: name + status
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("\(item.emoji) \(item.clue)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    statusIcon(status)
                }
                if isBonusItem, let subjects {
                    Text("Subjects: \(subjects)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.black.opacity(0.60))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusBorderColor(status), lineWidth: 3)
        )
        .onLongPressGesture {
            confirmingItemId = item.id
        }
    }

    @ViewBuilder
    private func statusIcon(_ status: String) -> some View {
        switch status {
        case "valid":
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
        case "invalid":
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red).font(.caption)
        default:
            Image(systemName: "clock.fill").foregroundStyle(.orange).font(.caption)
        }
    }

    private func statusBorderColor(_ status: String) -> Color {
        switch status {
        case "valid":   return .green
        case "invalid": return .red
        default:        return .orange.opacity(0.6)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class ScavengerHuntAdminVM: ObservableObject {
    @Published var submissions: [ScavengerHuntSubmission] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit { listener?.remove() }

    func load(challengeId: String) {
        isLoading = true
        listener?.remove()
        listener = db.collection("weekly_challenges")
            .document(challengeId)
            .collection("photo_submissions")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                self.isLoading = false
                if let err { self.errorMessage = err.localizedDescription; return }
                guard let snap else { return }
                self.submissions = snap.documents
                    .map { ScavengerHuntStore.parseSubmission(uid: $0.documentID, data: $0.data()) }
                    .filter { !$0.completedItems.isEmpty }
                    .sorted { ($0.displayName ?? $0.uid) < ($1.displayName ?? $1.uid) }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    func setItemStatus(
        challengeId: String,
        uid: String,
        itemId: String,
        status: String,
        bonusItemId: String?
    ) async {
        do {
            try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("photo_submissions")
                .document(uid)
                .setData(["item_statuses": [itemId: status]], merge: true)

            // Sync score
            let snap = try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("photo_submissions")
                .document(uid)
                .getDocument()

            guard let data = snap.data() else { return }
            let sub = ScavengerHuntStore.parseSubmission(uid: uid, data: data)
            let score        = sub.validatedScore(bonusItemId: bonusItemId)
            let pendingCount = sub.pendingCount()
            let linkedId     = sub.linkedPlayerId ?? uid

            try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("submissions")
                .document(linkedId)
                .setData([
                    "uid": uid,
                    "linked_player_id": sub.linkedPlayerId as Any,
                    "display_name": sub.displayName as Any,
                    "score": score,
                    "pending_score": pendingCount,
                    "updated_at": FieldValue.serverTimestamp()
                ], merge: true)

        } catch {
            errorMessage = "Failed to update: \(error.localizedDescription)"
        }
    }
}
