//
//  PhotoChallengeAdminView.swift
//  Best Man Challenge
//
//  Owner-only admin view for selecting photo challenge winners.
//
//  LAYOUT (prompt-first):
//   • Root: list of prompts → shows photo count + current winner name
//   • Tap prompt → PhotoPromptSubmissionsView (all photos for that prompt)
//   • Long-press a photo → select that player as the prompt winner
//     (clears previous winner for that prompt automatically)
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

    private func syncScore(challengeId: String, uid: String) async {
        do {
            let snap = try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("photo_submissions")
                .document(uid)
                .getDocument()

            guard let data = snap.data() else { return }
            let sub = PhotoChallengeStore.parseSubmission(uid: uid, data: data)
            let score = sub.photos.count * 2 + sub.bonusWinners.filter { $0.value }.count

            let targetId = sub.linkedPlayerId ?? uid
            try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("submissions")
                .document(targetId)
                .setData([
                    "uid": uid,
                    "linked_player_id": sub.linkedPlayerId as Any,
                    "display_name": sub.displayName as Any,
                    "score": score,
                    "updated_at": FieldValue.serverTimestamp()
                ], merge: true)
        } catch {
            print("⚠️ syncScore failed:", error.localizedDescription)
        }
    }
}
