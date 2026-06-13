//
//  PhotoChallengeStore.swift
//  Best Man Challenge
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import SwiftUI

// MARK: - Data models for runtime use

struct PhotoEntry {
    let url: String
    let submittedAt: Date
}

struct PhotoSubmission: Identifiable {
    let id: String              // userId / linked player id
    let uid: String
    let linkedPlayerId: String?
    let displayName: String?
    let submittedAt: Date?
    var photos: [String: PhotoEntry]        // promptId -> PhotoEntry
    var bonusWinners: [String: Bool]        // promptId -> true (admin sets)

    func baseScore(pointsPerSubmission: Int) -> Int {
        photos.count * pointsPerSubmission
    }

    func bonusScore(bonusPointsPerWinner: Int) -> Int {
        bonusWinners.filter { $0.value }.count * bonusPointsPerWinner
    }

    func totalScore(config: WeeklyChallengePhotoConfig) -> Int {
        baseScore(pointsPerSubmission: config.points_per_submission) +
        bonusScore(bonusPointsPerWinner: config.bonus_points_per_winner)
    }
}

// MARK: - Store

@MainActor
final class PhotoChallengeStore: ObservableObject {

    @Published var submission: PhotoSubmission?
    @Published var isUploading: Bool = false
    @Published var uploadingPromptId: String?
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var currentChallengeId: String?

    deinit { listener?.remove() }

    func start(challengeId: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        currentChallengeId = challengeId
        listener?.remove()

        let ref = db.collection("weekly_challenges")
            .document(challengeId)
            .collection("photo_submissions")
            .document(uid)

        listener = ref.addSnapshotListener { [weak self] snap, err in
            guard let self else { return }
            if let err { Task { @MainActor in self.errorMessage = err.localizedDescription }; return }
            guard let snap, snap.exists, let data = snap.data() else {
                Task { @MainActor in self.submission = nil }
                return
            }
            Task { @MainActor in self.submission = Self.parseSubmission(uid: uid, data: data) }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
        currentChallengeId = nil
    }

    // MARK: - Upload a single photo for one prompt

    func uploadPhoto(
        imageData: Data,
        promptId: String,
        challengeId: String,
        linkedPlayerId: String?,
        displayName: String?
    ) async {
        guard !isUploading else { return }
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Not logged in."
            return
        }

        isUploading = true
        uploadingPromptId = promptId
        errorMessage = nil
        defer {
            isUploading = false
            uploadingPromptId = nil
        }

        do {
            // 1) Upload to Firebase Storage
            let cleanUid  = uid.replacingOccurrences(of: "/", with: "_")
            let cleanCId  = challengeId.replacingOccurrences(of: "/", with: "_")
            let fileName  = "\(UUID().uuidString).jpg"
            let path      = "weekly_challenge_photos/\(cleanCId)/\(cleanUid)/\(promptId)/\(fileName)"
            let ref       = Storage.storage().reference().child(path)

            let meta = StorageMetadata()
            meta.contentType = "image/jpeg"
            _ = try await ref.putDataAsync(imageData, metadata: meta)
            let downloadURL = try await ref.downloadURL()

            // 2) Write URL + timestamp to Firestore
            let docRef = db.collection("weekly_challenges")
                .document(challengeId)
                .collection("photo_submissions")
                .document(uid)

            let photoData: [String: Any] = [
                "url": downloadURL.absoluteString,
                "submitted_at": Timestamp(date: Date())
            ]

            try await docRef.setData([
                "uid": uid,
                "linked_player_id": linkedPlayerId as Any,
                "display_name": displayName as Any,
                "submitted_at": FieldValue.serverTimestamp(),
                "photos": [promptId: photoData]
            ], merge: true)

        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Admin: set bonus winner for a category

    func setBonusWinner(challengeId: String, userId: String, promptId: String, isWinner: Bool) async {
        do {
            let docRef = db.collection("weekly_challenges")
                .document(challengeId)
                .collection("photo_submissions")
                .document(userId)

            try await docRef.setData(
                ["bonus_winners": [promptId: isWinner]],
                merge: true
            )

            // Also write total score to submissions collection so leaderboard picks it up
            await syncScoreToSubmissions(challengeId: challengeId, userId: userId)

        } catch {
            errorMessage = "Failed to set winner: \(error.localizedDescription)"
        }
    }

    private func syncScoreToSubmissions(challengeId: String, userId: String) async {
        do {
            let snap = try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("photo_submissions")
                .document(userId)
                .getDocument()

            guard let data = snap.data() else { return }
            let sub = Self.parseSubmission(uid: userId, data: data)
            let pts  = sub.photos.count * 2 + sub.bonusWinners.filter { $0.value }.count

            let linkedId = sub.linkedPlayerId ?? userId
            try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("submissions")
                .document(linkedId)
                .setData([
                    "uid": userId,
                    "linked_player_id": sub.linkedPlayerId as Any,
                    "display_name": sub.displayName as Any,
                    "score": pts,
                    "updated_at": FieldValue.serverTimestamp()
                ], merge: true)
        } catch {
            print("⚠️ syncScoreToSubmissions failed:", error.localizedDescription)
        }
    }

    // MARK: - Parsing

    static func parseSubmission(uid: String, data: [String: Any]) -> PhotoSubmission {
        let linkedPlayerId = data["linked_player_id"] as? String
        let displayName    = data["display_name"] as? String
        let submittedAt    = (data["submitted_at"] as? Timestamp)?.dateValue()

        var photos: [String: PhotoEntry] = [:]
        if let rawPhotos = data["photos"] as? [String: [String: Any]] {
            for (promptId, entry) in rawPhotos {
                if let url = entry["url"] as? String {
                    let ts = (entry["submitted_at"] as? Timestamp)?.dateValue() ?? Date()
                    photos[promptId] = PhotoEntry(url: url, submittedAt: ts)
                }
            }
        }

        var bonusWinners: [String: Bool] = [:]
        if let raw = data["bonus_winners"] as? [String: Bool] {
            bonusWinners = raw
        }

        return PhotoSubmission(
            id: uid,
            uid: uid,
            linkedPlayerId: linkedPlayerId,
            displayName: displayName,
            submittedAt: submittedAt,
            photos: photos,
            bonusWinners: bonusWinners
        )
    }
}
