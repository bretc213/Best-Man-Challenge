//
//  PhotoChallengeStore.swift
//  Best Man Challenge
//
//  Scoring is admin-gated:
//  • Photos land as "pending" (no photo_statuses entry) until admin marks Valid or Invalid.
//  • validatedBaseScore = count of prompts with status "valid" × points_per_submission
//  • pendingCount = count of photos with no status or status == "pending"
//  • Bonus (winner) score is unchanged — admin sets via prompt-first view.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import SwiftUI

// MARK: - Data models

struct PhotoEntry {
    let url: String
    let submittedAt: Date
}

struct PhotoSubmission: Identifiable {
    let id: String              // uid
    let uid: String
    let linkedPlayerId: String?
    let displayName: String?
    let submittedAt: Date?
    var photos: [String: PhotoEntry]          // promptId -> PhotoEntry
    var bonusWinners: [String: Bool]          // promptId -> true (admin sets)
    var photoStatuses: [String: String]       // promptId -> "pending"|"valid"|"invalid"

    // MARK: Scoring

    func pendingCount() -> Int {
        photos.keys.filter { promptId in
            let status = photoStatuses[promptId] ?? "pending"
            return status == "pending"
        }.count
    }

    func validatedBaseScore(pointsPerSubmission: Int) -> Int {
        photos.keys.filter { photoStatuses[$0] == "valid" }.count * pointsPerSubmission
    }

    func bonusScore(bonusPointsPerWinner: Int) -> Int {
        bonusWinners.filter { $0.value }.count * bonusPointsPerWinner
    }

    func totalScore(config: WeeklyChallengePhotoConfig) -> Int {
        validatedBaseScore(pointsPerSubmission: config.points_per_submission) +
        bonusScore(bonusPointsPerWinner: config.bonus_points_per_winner)
    }

    // Legacy
    func baseScore(pointsPerSubmission: Int) -> Int {
        validatedBaseScore(pointsPerSubmission: pointsPerSubmission)
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

        let cleanUid  = uid.replacingOccurrences(of: "/", with: "_")
        let cleanCId  = challengeId.replacingOccurrences(of: "/", with: "_")
        let fileName  = "\(UUID().uuidString).jpg"
        let path      = "weekly_challenge_photos/\(cleanCId)/\(cleanUid)/\(promptId)/\(fileName)"
        let ref       = Storage.storage().reference().child(path)

        print("📤 Uploading to path: \(path)")
        print("📦 Image data size: \(imageData.count) bytes")

        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"

        do {
            let resultMeta = try await ref.putDataAsync(imageData, metadata: meta)
            print("✅ putDataAsync succeeded, file size: \(resultMeta.size ?? -1)")
        } catch {
            errorMessage = "Storage put failed: \(error.localizedDescription)"
            return
        }

        let downloadURL: URL
        do {
            downloadURL = try await ref.downloadURL()
            print("✅ downloadURL: \(downloadURL)")
        } catch {
            errorMessage = "Storage URL fetch failed: \(error.localizedDescription)"
            return
        }

        // Write URL + timestamp to Firestore. Photo starts as "pending".
        do {
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
                "photos": [promptId: photoData],
                "photo_statuses": [promptId: "pending"]
            ], merge: true)
        } catch {
            errorMessage = "Firestore write failed: \(error.localizedDescription)"
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

            await syncScoreToSubmissions(challengeId: challengeId, userId: userId)

        } catch {
            errorMessage = "Failed to set winner: \(error.localizedDescription)"
        }
    }

    // MARK: - Admin: set photo status (Valid / Invalid / Pending)

    func setPhotoStatus(challengeId: String, userId: String, promptId: String, status: String) async {
        do {
            let docRef = db.collection("weekly_challenges")
                .document(challengeId)
                .collection("photo_submissions")
                .document(userId)

            try await docRef.setData(
                ["photo_statuses": [promptId: status]],
                merge: true
            )

            await syncScoreToSubmissions(challengeId: challengeId, userId: userId)
        } catch {
            errorMessage = "Failed to update status: \(error.localizedDescription)"
        }
    }

    // MARK: - Sync score to submissions/

    func syncScoreToSubmissions(challengeId: String, userId: String) async {
        do {
            let snap = try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("photo_submissions")
                .document(userId)
                .getDocument()

            guard let data = snap.data() else { return }
            let sub = Self.parseSubmission(uid: userId, data: data)

            // Attempt to get points_per_submission from the challenge doc
            let challengeSnap = try? await db.collection("weekly_challenges")
                .document(challengeId)
                .getDocument()
            let ptsPerSub: Int = {
                if let raw = challengeSnap?.data()?["photo_challenge"] as? [String: Any],
                   let pts = raw["points_per_submission"] as? Int { return pts }
                return 2  // fallback
            }()

            let score        = sub.validatedBaseScore(pointsPerSubmission: ptsPerSub) + sub.bonusScore(bonusPointsPerWinner: 1)
            let pendingScore = sub.pendingCount() * ptsPerSub
            let linkedId     = sub.linkedPlayerId ?? userId

            try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("submissions")
                .document(linkedId)
                .setData([
                    "uid": userId,
                    "linked_player_id": sub.linkedPlayerId as Any,
                    "display_name": sub.displayName as Any,
                    "score": score,
                    "pending_score": pendingScore,
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

        let photoStatuses = data["photo_statuses"] as? [String: String] ?? [:]

        return PhotoSubmission(
            id: uid,
            uid: uid,
            linkedPlayerId: linkedPlayerId,
            displayName: displayName,
            submittedAt: submittedAt,
            photos: photos,
            bonusWinners: bonusWinners,
            photoStatuses: photoStatuses
        )
    }
}
