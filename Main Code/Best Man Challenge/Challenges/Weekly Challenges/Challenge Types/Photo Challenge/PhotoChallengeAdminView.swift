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
import FirebaseStorage
import FirebaseAuth
import PhotosUI

// MARK: - Full-screen photo helpers

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct FullScreenPhotoView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure:
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                default:
                    ProgressView()
                }
            }
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
        }
        .onTapGesture { dismiss() }
    }
}

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
    @State private var fullScreenPhoto: IdentifiableURL?

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
        .fullScreenCover(item: $fullScreenPhoto) { item in
            FullScreenPhotoView(url: item.url)
        }
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
        .onTapGesture {
            if let url = URL(string: entry.url) {
                fullScreenPhoto = IdentifiableURL(url: url)
            }
        }
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
    @State private var showAdminSubmit = false

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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAdminSubmit = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showAdminSubmit) {
            AdminPhotoSubmitView(challenge: challenge, vm: vm)
        }
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
    @State private var fullScreenPhoto: IdentifiableURL?

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
        .fullScreenCover(item: $fullScreenPhoto) { item in
            FullScreenPhotoView(url: item.url)
        }
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
        .onTapGesture {
            if let url = URL(string: entry.url) {
                fullScreenPhoto = IdentifiableURL(url: url)
            }
        }
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

// MARK: - Admin Submit on Behalf

struct AdminPhotoSubmitView: View {
    let challenge: WeeklyChallenge
    @ObservedObject var vm: PhotoChallengeAdminVM
    @Environment(\.dismiss) private var dismiss

    private struct PlayerRecord: Identifiable {
        let id: String          // Firebase UID
        let linkedPlayerId: String
        let displayName: String
    }

    @State private var players: [PlayerRecord] = []
    @State private var selectedUID: String = ""
    @State private var selectedPromptId: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var prompts: [PhotoChallengePrompt] { challenge.photo_challenge?.prompts ?? [] }

    var body: some View {
        NavigationStack {
            Form {
                Section("Player") {
                    if players.isEmpty {
                        HStack {
                            ProgressView().scaleEffect(0.7)
                            Text("Loading players…").foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("Select Player", selection: $selectedUID) {
                            Text("Choose a player").tag("")
                            ForEach(players) { player in
                                Text(player.displayName).tag(player.id)
                            }
                        }
                    }
                }

                Section("Prompt") {
                    Picker("Select Prompt", selection: $selectedPromptId) {
                        Text("Choose a prompt").tag("")
                        ForEach(prompts) { prompt in
                            Text("\(prompt.emoji) \(prompt.label)").tag(prompt.id)
                        }
                    }
                }

                Section("Photo") {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label(
                            selectedItem == nil ? "Select Photo" : "Photo Selected ✓",
                            systemImage: "photo.badge.plus"
                        )
                    }
                }

                if let err = errorMessage {
                    Section {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }
                if let suc = successMessage {
                    Section {
                        Text(suc).foregroundStyle(.green).font(.caption)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if isUploading {
                                ProgressView().scaleEffect(0.7)
                            }
                            Text(isUploading ? "Uploading…" : "Submit on Behalf")
                                .bold()
                        }
                    }
                    .disabled(selectedUID.isEmpty || selectedPromptId.isEmpty || selectedItem == nil || isUploading)
                }
            }
            .navigationTitle("Submit on Behalf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await loadPlayers() }
        }
    }

    // MARK: - Load players from users collection

    private func loadPlayers() async {
        let db = Firestore.firestore()
        do {
            let snap = try await db.collection("users").getDocuments()
            let loaded: [PlayerRecord] = snap.documents.compactMap { doc in
                let data = doc.data()
                guard let linkedPlayerId = data["linked_player_id"] as? String,
                      !linkedPlayerId.isEmpty else { return nil }
                let displayName = data["display_name"] as? String ?? linkedPlayerId
                return PlayerRecord(
                    id: doc.documentID,
                    linkedPlayerId: linkedPlayerId,
                    displayName: displayName
                )
            }
            .sorted { $0.displayName < $1.displayName }
            players = loaded
        } catch {
            errorMessage = "Failed to load players: \(error.localizedDescription)"
        }
    }

    // MARK: - Upload + write exactly like a real player submission

    private func submit() async {
        guard !selectedUID.isEmpty,
              !selectedPromptId.isEmpty,
              let item = selectedItem else { return }

        isUploading = true
        errorMessage = nil
        successMessage = nil
        defer { isUploading = false }

        guard let imageData = try? await item.loadTransferable(type: Data.self) else {
            errorMessage = "Failed to load image data."
            return
        }

        let player = players.first { $0.id == selectedUID }
        let linkedPlayerId = player?.linkedPlayerId
        let displayName    = player?.displayName
        let playerUID      = selectedUID
        let challengeId    = challenge.id
        let promptId       = selectedPromptId

        // Upload to Firebase Storage (same path as a real player upload)
        let cleanUID  = playerUID.replacingOccurrences(of: "/", with: "_")
        let cleanCId  = challengeId.replacingOccurrences(of: "/", with: "_")
        let fileName  = "\(UUID().uuidString).jpg"
        let path      = "weekly_challenge_photos/\(cleanCId)/\(cleanUID)/\(promptId)/\(fileName)"
        let storageRef = Storage.storage().reference().child(path)

        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"

        do {
            _ = try await storageRef.putDataAsync(imageData, metadata: meta)
        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
            return
        }

        let downloadURL: URL
        do {
            downloadURL = try await storageRef.downloadURL()
        } catch {
            errorMessage = "Failed to get download URL: \(error.localizedDescription)"
            return
        }

        // Write to Firestore — identical to PhotoChallengeStore.uploadPhoto
        let db = Firestore.firestore()
        do {
            let docRef = db.collection("weekly_challenges")
                .document(challengeId)
                .collection("photo_submissions")
                .document(playerUID)

            let photoData: [String: Any] = [
                "url": downloadURL.absoluteString,
                "submitted_at": Timestamp(date: Date())
            ]

            try await docRef.setData([
                "uid": playerUID,
                "linked_player_id": linkedPlayerId as Any,
                "display_name": displayName as Any,
                "submitted_at": FieldValue.serverTimestamp(),
                "photos": [promptId: photoData],
                "photo_statuses": [promptId: "pending"]
            ], merge: true)

            successMessage = "✅ Submitted for \(displayName ?? playerUID)"
            selectedItem = nil
        } catch {
            errorMessage = "Firestore write failed: \(error.localizedDescription)"
        }
    }
}
