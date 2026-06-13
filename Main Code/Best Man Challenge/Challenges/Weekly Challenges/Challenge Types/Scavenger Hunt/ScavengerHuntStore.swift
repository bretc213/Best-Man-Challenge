//
//  ScavengerHuntStore.swift
//  Best Man Challenge
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import SwiftUI

// MARK: - Runtime model

struct ScavengerHuntSubmission: Identifiable {
    let id: String  // uid
    let uid: String
    let linkedPlayerId: String?
    let displayName: String?
    /// itemId -> download URL
    var completedItems: [String: String]

    func score(pointsPerItem: Int) -> Int {
        completedItems.count * pointsPerItem
    }
}

// MARK: - Store

@MainActor
final class ScavengerHuntStore: ObservableObject {

    @Published var submission: ScavengerHuntSubmission?
    @Published var isUploading = false
    @Published var uploadingItemId: String?
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var currentChallengeId: String?

    deinit { listener?.remove() }

    // MARK: - Lifecycle

    func start(challengeId: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        currentChallengeId = challengeId
        listener?.remove()

        listener = db.collection("weekly_challenges")
            .document(challengeId)
            .collection("photo_submissions")
            .document(uid)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                if let data = snap?.data(), snap?.exists == true {
                    Task { @MainActor in
                        self.submission = Self.parseSubmission(uid: uid, data: data)
                    }
                } else {
                    Task { @MainActor in self.submission = nil }
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
        currentChallengeId = nil
    }

    // MARK: - Upload photo proof for an item

    func uploadProof(
        imageData: Data,
        itemId: String,
        challengeId: String,
        linkedPlayerId: String?,
        displayName: String?
    ) async {
        guard !isUploading,
              let uid = Auth.auth().currentUser?.uid else { return }

        isUploading = true
        uploadingItemId = itemId
        errorMessage = nil
        defer {
            isUploading = false
            uploadingItemId = nil
        }

        do {
            let cleanUid = uid.replacingOccurrences(of: "/", with: "_")
            let cleanCId = challengeId.replacingOccurrences(of: "/", with: "_")
            let path     = "weekly_challenge_photos/\(cleanCId)/\(cleanUid)/scavenger/\(itemId)/\(UUID().uuidString).jpg"
            let ref      = Storage.storage().reference().child(path)

            let meta = StorageMetadata()
            meta.contentType = "image/jpeg"
            _ = try await ref.putDataAsync(imageData, metadata: meta)
            let url = try await ref.downloadURL()

            let docRef = db.collection("weekly_challenges")
                .document(challengeId)
                .collection("photo_submissions")
                .document(uid)

            try await docRef.setData([
                "uid": uid,
                "linked_player_id": linkedPlayerId as Any,
                "display_name": displayName as Any,
                "submitted_at": FieldValue.serverTimestamp(),
                "completed_items": [itemId: url.absoluteString]
            ], merge: true)

        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Sync score to leaderboard

    func syncScore(challengeId: String, pointsPerItem: Int) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let sub = submission else { return }
        let score    = sub.score(pointsPerItem: pointsPerItem)
        let linkedId = sub.linkedPlayerId ?? uid

        do {
            try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("submissions")
                .document(linkedId)
                .setData([
                    "uid": uid,
                    "linked_player_id": sub.linkedPlayerId as Any,
                    "display_name": sub.displayName as Any,
                    "score": score,
                    "updated_at": FieldValue.serverTimestamp()
                ], merge: true)
        } catch {
            print("⚠️ ScavengerHunt syncScore failed:", error.localizedDescription)
        }
    }

    // MARK: - Parse

    static func parseSubmission(uid: String, data: [String: Any]) -> ScavengerHuntSubmission {
        let linkedPlayerId   = data["linked_player_id"] as? String
        let displayName      = data["display_name"] as? String
        let completedItems   = data["completed_items"] as? [String: String] ?? [:]

        return ScavengerHuntSubmission(
            id: uid,
            uid: uid,
            linkedPlayerId: linkedPlayerId,
            displayName: displayName,
            completedItems: completedItems
        )
    }
}
