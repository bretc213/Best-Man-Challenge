//
//  PhotoChallengeAdminView.swift
//  Best Man Challenge
//

import SwiftUI
import FirebaseFirestore

/// Admin view — lets judge (Amanda / Bret) review all submissions
/// and mark a winner per prompt category.
struct PhotoChallengeAdminView: View {
    let challenge: WeeklyChallenge
    @StateObject private var vm = PhotoChallengeAdminVM()
    @State private var expandedUser: String?    // uid being expanded

    private var config: WeeklyChallengePhotoConfig? { challenge.photo_challenge }

    var body: some View {
        List {
            if vm.submissions.isEmpty && !vm.isLoading {
                ContentUnavailableView("No submissions yet",
                                       systemImage: "photo.stack")
            }

            ForEach(vm.submissions) { sub in
                Section {
                    submissionRow(sub)
                } header: {
                    Text(sub.displayName ?? sub.uid)
                }
            }
        }
        .navigationTitle("Photo Admin")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if vm.isLoading { ProgressView() } }
        .onAppear  { vm.load(challengeId: challenge.id) }
        .onDisappear { vm.stop() }
        .alert("Error", isPresented: .init(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Per-user submission row

    @ViewBuilder
    private func submissionRow(_ sub: PhotoSubmission) -> some View {
        let prompts = config?.prompts ?? []
        ForEach(prompts) { prompt in
            if let entry = sub.photos[prompt.id] {
                VStack(alignment: .leading, spacing: 10) {
                    // Photo
                    if let url = URL(string: entry.url) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            default:
                                ProgressView().frame(height: 200)
                            }
                        }
                    }

                    HStack {
                        Label("\(prompt.emoji) \(prompt.label)", systemImage: "")
                            .font(.subheadline.bold())
                        Spacer()
                        // Toggle winner
                        let isWinner = sub.bonusWinners[prompt.id] == true
                        Button {
                            Task {
                                await vm.toggleWinner(
                                    challengeId: challenge.id,
                                    userId: sub.uid,
                                    promptId: prompt.id,
                                    currentlyWinner: isWinner
                                )
                            }
                        } label: {
                            Label(isWinner ? "Winner ✓" : "Set Winner",
                                  systemImage: isWinner ? "trophy.fill" : "trophy")
                                .font(.caption.bold())
                                .foregroundStyle(isWinner ? .yellow : .secondary)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 4)
            }
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
    private var store = PhotoChallengeStore()

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
                self.submissions = snap.documents.compactMap { doc in
                    guard let data = doc.data() as? [String: Any] else { return nil }
                    return PhotoChallengeStore.parseSubmission(uid: doc.documentID, data: doc.data())
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    func toggleWinner(challengeId: String, userId: String, promptId: String, currentlyWinner: Bool) async {
        await store.setBonusWinner(
            challengeId: challengeId,
            userId: userId,
            promptId: promptId,
            isWinner: !currentlyWinner
        )
    }
}
