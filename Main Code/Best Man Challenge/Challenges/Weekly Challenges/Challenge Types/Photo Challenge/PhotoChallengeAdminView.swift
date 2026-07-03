//
//  PhotoChallengeAdminView.swift
//  Best Man Challenge
//
//  Two separate admin flows:
//
//  1. PhotoChallengeAdminView (prompt-first) — select category winners
//     Root: list of prompts → tap → all photos for that prompt → long-press → pick winner
//
//  2. PhotoChallengeGraderView (player-first) — validate/invalidate submissions
//     Root: list of players → tap → all their photos → long-press → Valid/Invalid
//

import SwiftUI
import FirebaseFirestore

// MARK: - Root prompt list

struct PhotoChallengeAdminView: View {
    let challenge: WeeklyChallenge

    @StateObject private var vm = PhotoChallengeAdminVM()

    private var prompts: [PhotoChallengePrompt] {
        challenge.photo_challenge?.prompts ?? []
    }

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
                ForEach(prompts) { prompt in
                    NavigationLink {
                        PhotoPromptSubmissionsView(
                            challenge: challenge,
                            prompt: prompt,
                            submissions: vm.submissions,
                            vm: vm
                        )
                    } label: {
                        promptRow(prompt)
                    }
                }
            }
        }
        .navigationTitle("Photo Winners — W\(challenge.week)")
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

    private func promptRow(_ prompt: PhotoChallengePrompt) -> some View {
        let submittedCount = vm.submissions.filter { $0.photos[prompt.id] != nil }.count
        let winner = vm.submissions.first(where: { $0.bonusWinners[prompt.id] == true })

        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(prompt.emoji)
                    .font(.title2)
                Text(prompt.label)
                    .font(.headline)
                Spacer()
                if winner != nil {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                        .font(.subheadline)
                }
            }

            HStack(spacing: 12) {
                Text("\(submittedCount) photo\(submittedCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let w = winner {
                    Text("Winner: \(w.displayName ?? w.uid)")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Per-prompt submissions grid (long-press to select winner)

struct PhotoPromptSubmissionsView: View {
    let challenge: WeeklyChallenge
    let prompt: PhotoChallengePrompt
    let submissions: [PhotoSubmission]
    @ObservedObject var vm: PhotoChallengeAdminVM

    /// Submissions that have a photo for this prompt
    private var promptSubmissions: [PhotoSubmission] {
        submissions.filter { $0.photos[prompt.id] != nil }
    }

    @State private var confirmingWinner: PhotoSubmission?
    @State private var savingUID: String?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Current winner banner
                if let winner = submissions.first(where: { $0.bonusWinners[prompt.id] == true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                        Text("Winner: \(winner.displayName ?? winner.uid)")
                            .font(.subheadline.bold())
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                }

                Text("Long-press a photo to select that person as winner.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if promptSubmissions.isEmpty {
                    ContentUnavailableView(
                        "No photos submitted",
                        systemImage: "photo",
                        description: Text("Nobody has submitted for this prompt yet.")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(promptSubmissions) { sub in
                            photoCell(sub)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 12)
        }
        .navigationTitle("\(prompt.emoji) \(prompt.label)")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Select Winner",
            isPresented: Binding(get: { confirmingWinner != nil }, set: { if !$0 { confirmingWinner = nil } }),
            titleVisibility: .visible
        ) {
            if let pending = confirmingWinner {
                Button("Set \(pending.displayName ?? pending.uid) as Winner") {
                    Task {
                        savingUID = pending.uid
                        await vm.setWinner(
                            challengeId: challenge.id,
                            promptId: prompt.id,
                            winnerUID: pending.uid,
                            allSubmissions: promptSubmissions
                        )
                        savingUID = nil
                    }
                }
                if submissions.first(where: { $0.bonusWinners[prompt.id] == true })?.uid == pending.uid {
                    Button("Remove Winner", role: .destructive) {
                        Task {
                            savingUID = pending.uid
                            await vm.clearWinner(
                                challengeId: challenge.id,
                                promptId: prompt.id,
                                uid: pending.uid
                            )
                            savingUID = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) { confirmingWinner = nil }
            }
        } message: {
            if let pending = confirmingWinner {
                Text("Set \(pending.displayName ?? pending.uid) as the winner for \(prompt.emoji) \(prompt.label)?")
            }
        }
    }

    private func photoCell(_ sub: PhotoSubmission) -> some View {
        let isWinner = sub.bonusWinners[prompt.id] == true
        let isSaving = savingUID == sub.uid
        let entry = sub.photos[prompt.id]!

        return ZStack(alignment: .bottom) {
            if let url = URL(string: entry.url) {
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
                            .overlay { Image(systemName: "exclamationmark.triangle").foregroundStyle(.secondary) }
                    default:
                        Color.secondary.opacity(0.15)
                            .frame(height: 180)
                            .overlay { ProgressView() }
                    }
                }
            }

            // Name + winner badge overlay
            HStack {
                Text(sub.displayName ?? sub.uid)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                if isWinner {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
                if isSaving {
                    ProgressView().scaleEffect(0.6)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(.black.opacity(0.55))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isWinner ? Color.yellow : Color.clear, lineWidth: 3)
        )
        .onLongPressGesture {
            confirmingWinner = sub
        }
    }
}

// MARK: - ViewModel

@MainActor
final class PhotoChallengeAdminVM: ObservableObject {
    @Published var submissions: [PhotoSubmission] = []
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
                self.submissions = snap.documents.map {
                    PhotoChallengeStore.parseSubmission(uid: $0.documentID, data: $0.data())
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Set winner (clears previous winner for this prompt first)

    func setWinner(
        challengeId: String,
        promptId: String,
        winnerUID: String,
        allSubmissions: [PhotoSubmission]
    ) async {
        // Clear any existing winner for this prompt
        let currentWinners = allSubmissions.filter { $0.bonusWinners[promptId] == true && $0.uid != winnerUID }
        for sub in currentWinners {
            await clearWinner(challengeId: challengeId, promptId: promptId, uid: sub.uid)
        }

        // Set new winner
        do {
            try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("photo_submissions")
                .document(winnerUID)
                .setData(["bonus_winners": [promptId: true]], merge: true)

            await syncScore(challengeId: challengeId, uid: winnerUID)
        } catch {
            errorMessage = "Failed to set winner: \(error.localizedDescription)"
        }
    }

    func clearWinner(challengeId: String, promptId: String, uid: String) async {
        do {
            try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("photo_submissions")
                .document(uid)
                .setData(["bonus_winners": [promptId: false]], merge: true)

            await syncScore(challengeId: challengeId, uid: uid)
        } catch {
            errorMessage = "Failed to clear winner: \(error.localizedDescription)"
        }
    }

    // MARK: - Sync total score to submissions/

    func syncScore(challengeId: String, uid: String) async {
        do {
            let submissionSnap = try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("photo_submissions")
                .document(uid)
                .getDocument()

            guard let data = submissionSnap.data() else { return }
            let sub = PhotoChallengeStore.parseSubmission(uid: uid, data: data)

            // Fetch points_per_submission from the challenge document
            let challengeSnap = try? await db.collection("weekly_challenges")
                .document(challengeId)
                .getDocument()
            let ptsPerSub: Int = {
                if let raw = challengeSnap?.data()?["photo_challenge"] as? [String: Any],
                   let pts = raw["points_per_submission"] as? Int { return pts }
                return 2
            }()

            let score        = sub.validatedBaseScore(pointsPerSubmission: ptsPerSub)
                             + sub.bonusScore(bonusPointsPerWinner: 1)
            let pendingScore = sub.pendingCount() * ptsPerSub
            let targetId     = sub.linkedPlayerId ?? uid

            try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("submissions")
                .document(targetId)
                .setData([
                    "uid": uid,
                    "linked_player_id": sub.linkedPlayerId as Any,
                    "display_name": sub.displayName as Any,
                    "score": score,
                    "pending_score": pendingScore,
                    "updated_at": FieldValue.serverTimestamp()
                ], merge: true)
        } catch {
            print("⚠️ syncScore failed:", error.localizedDescription)
        }
    }
}

// MARK: - =========================================================
// MARK: - PhotoChallengeGraderView (player-first: Valid / Invalid)
// MARK: - =========================================================

struct PhotoChallengeGraderView: View {
    let challenge: WeeklyChallenge

    @StateObject private var vm = PhotoChallengeAdminVM()

    private var config: WeeklyChallengePhotoConfig? { challenge.photo_challenge }

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
                ForEach(vm.submissions.filter { !$0.photos.isEmpty }) { sub in
                    NavigationLink {
                        if let config {
                            PhotoPlayerGraderView(
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
        .navigationTitle("Grade Submissions — W\(challenge.week)")
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

    private func playerRow(_ sub: PhotoSubmission) -> some View {
        let config = self.config
        let ptsPerSub = config?.points_per_submission ?? 2
        let confirmed = sub.validatedBaseScore(pointsPerSubmission: ptsPerSub)
        let pending   = sub.pendingCount()

        return VStack(alignment: .leading, spacing: 3) {
            Text(sub.displayName ?? sub.uid)
                .font(.headline)
            HStack(spacing: 12) {
                Text("\(sub.photos.count) photo\(sub.photos.count == 1 ? "" : "s") submitted")
                    .font(.caption).foregroundStyle(.secondary)
                if confirmed > 0 {
                    Text("✅ \(confirmed) pts")
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

// MARK: - Per-player photo grading view

struct PhotoPlayerGraderView: View {
    let challenge: WeeklyChallenge
    let submission: PhotoSubmission
    let config: WeeklyChallengePhotoConfig
    @ObservedObject var vm: PhotoChallengeAdminVM

    private var live: PhotoSubmission? {
        vm.submissions.first { $0.uid == submission.uid }
    }

    @State private var confirmingPromptId: String?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var submittedPrompts: [PhotoChallengePrompt] {
        config.prompts.filter { live?.photos[$0.id] != nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                if let sub = live {
                    scoreBanner(sub)
                }

                Text("Long-press a photo to mark it Valid or Invalid.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal)

                if submittedPrompts.isEmpty {
                    ContentUnavailableView(
                        "No photos submitted",
                        systemImage: "photo",
                        description: Text("This player hasn't submitted any photos yet.")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(submittedPrompts) { prompt in
                            if let entry = live?.photos[prompt.id] {
                                photoCell(prompt: prompt, entry: entry, sub: live)
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
            "Grade Photo",
            isPresented: Binding(
                get: { confirmingPromptId != nil },
                set: { if !$0 { confirmingPromptId = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let promptId = confirmingPromptId,
               let prompt = config.prompts.first(where: { $0.id == promptId }) {
                let currentStatus = live?.photoStatuses[promptId] ?? "pending"

                if currentStatus != "valid" {
                    Button("✅ Mark Valid") {
                        Task {
                            await vm.setPhotoStatus(
                                challengeId: challenge.id,
                                uid: submission.uid,
                                promptId: promptId,
                                config: config
                            )
                        }
                        confirmingPromptId = nil
                    }
                }
                if currentStatus != "invalid" {
                    Button("❌ Mark Invalid", role: .destructive) {
                        Task {
                            await vm.setPhotoStatus(
                                challengeId: challenge.id,
                                uid: submission.uid,
                                promptId: promptId,
                                config: config,
                                status: "invalid"
                            )
                        }
                        confirmingPromptId = nil
                    }
                }
                if currentStatus != "pending" {
                    Button("⏳ Reset to Pending") {
                        Task {
                            await vm.setPhotoStatus(
                                challengeId: challenge.id,
                                uid: submission.uid,
                                promptId: promptId,
                                config: config,
                                status: "pending"
                            )
                        }
                        confirmingPromptId = nil
                    }
                }
                Button("Cancel", role: .cancel) { confirmingPromptId = nil }
            }
        } message: {
            if let promptId = confirmingPromptId,
               let prompt = config.prompts.first(where: { $0.id == promptId }) {
                Text("\(prompt.emoji) \(prompt.label)")
            }
        }
    }

    private func scoreBanner(_ sub: PhotoSubmission) -> some View {
        let confirmed = sub.validatedBaseScore(pointsPerSubmission: config.points_per_submission)
            + sub.bonusScore(bonusPointsPerWinner: config.bonus_points_per_winner)
        let pending   = sub.pendingCount()

        return HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("\(confirmed)")
                    .font(.title2.bold()).foregroundStyle(.green)
                Text("confirmed").font(.caption).foregroundStyle(.secondary)
            }
            Divider().frame(height: 36)
            VStack(spacing: 2) {
                Text("\(pending)")
                    .font(.title2.bold()).foregroundStyle(.orange)
                Text("pending").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func photoCell(prompt: PhotoChallengePrompt, entry: PhotoEntry, sub: PhotoSubmission?) -> some View {
        let status   = sub?.photoStatuses[prompt.id] ?? "pending"
        let isWinner = sub?.bonusWinners[prompt.id] == true

        return ZStack(alignment: .bottom) {
            if let url = URL(string: entry.url) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill().frame(height: 180).clipped()
                    case .failure:
                        Color.secondary.opacity(0.2).frame(height: 180)
                            .overlay { Image(systemName: "exclamationmark.triangle").foregroundStyle(.secondary) }
                    default:
                        Color.secondary.opacity(0.15).frame(height: 180)
                            .overlay { ProgressView() }
                    }
                }
            }

            HStack {
                Text("\(prompt.emoji) \(prompt.label)")
                    .font(.caption.bold()).foregroundStyle(.white).lineLimit(1)
                Spacer()
                if isWinner {
                    Image(systemName: "trophy.fill").foregroundStyle(.yellow).font(.caption)
                }
                statusIcon(status)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(.black.opacity(0.60))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusBorderColor(status), lineWidth: 3)
        )
        .onLongPressGesture {
            confirmingPromptId = prompt.id
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

// MARK: - PhotoChallengeAdminVM extension (setPhotoStatus)

extension PhotoChallengeAdminVM {

    func setPhotoStatus(
        challengeId: String,
        uid: String,
        promptId: String,
        config: WeeklyChallengePhotoConfig,
        status: String = "valid"
    ) async {
        do {
            let db = Firestore.firestore()
            try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("photo_submissions")
                .document(uid)
                .setData(["photo_statuses": [promptId: status]], merge: true)

            await syncScore(challengeId: challengeId, uid: uid)
        } catch {
            errorMessage = "Failed to grade: \(error.localizedDescription)"
        }
    }
}
