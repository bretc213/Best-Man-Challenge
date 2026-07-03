//
//  ScavengerHuntStore.swift
//  Best Man Challenge
//
//  Scoring is admin-gated:
//  • Submissions land as "pending" until admin marks Valid or Invalid.
//  • validatedScore() = count of "valid" items (+ bonus for item10 if subjects == "both")
//  • pendingCount = count of items with no status or status == "pending"
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
    /// itemId -> "pending" | "valid" | "invalid"
    var itemStatuses: [String: String]
    /// For bonus-eligible item: "bret" | "amanda" | "both"
    var item10Subjects: String?

    // MARK: Scoring

    func pendingCount() -> Int {
        completedItems.keys.filter { itemId in
            let status = itemStatuses[itemId] ?? "pending"
            return status == "pending"
        }.count
    }

    func validatedScore(bonusItemId: String? = "item10") -> Int {
        var score = 0
        for itemId in completedItems.keys {
            guard itemStatuses[itemId] == "valid" else { continue }
            score += 1
            if let bonusId = bonusItemId, itemId == bonusId, item10Subjects == "both" {
                score += 1  // bonus point
            }
        }
        return score
    }

    // Legacy compatibility
    func score(pointsPerItem: Int) -> Int {
        validatedScore()
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

            // Photo lands as "pending" — awaiting admin validation
            try await docRef.setData([
                "uid": uid,
                "linked_player_id": linkedPlayerId as Any,
                "display_name": displayName as Any,
                "submitted_at": FieldValue.serverTimestamp(),
                "completed_items": [itemId: url.absoluteString],
                "item_statuses": [itemId: "pending"]
            ], merge: true)

        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Set subjects for bonus item (who's in the photo)

    func setSubjects(challengeId: String, itemId: String, subjects: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let docRef = db.collection("weekly_challenges")
                .document(challengeId)
                .collection("photo_submissions")
                .document(uid)
            let key = itemId == "item10" ? "item10_subjects" : "\(itemId)_subjects"
            try await docRef.setData([key: subjects], merge: true)
        } catch {
            errorMessage = "Couldn't save selection: \(error.localizedDescription)"
        }
    }

    // MARK: - Admin: set item status (Valid / Invalid)

    func setItemStatus(
        challengeId: String,
        uid: String,
        itemId: String,
        status: String,   // "valid" | "invalid" | "pending"
        bonusItemId: String?
    ) async {
        do {
            let docRef = db.collection("weekly_challenges")
                .document(challengeId)
                .collection("photo_submissions")
                .document(uid)

            try await docRef.setData(
                ["item_statuses": [itemId: status]],
                merge: true
            )

            await syncScore(challengeId: challengeId, uid: uid, bonusItemId: bonusItemId)
        } catch {
            errorMessage = "Failed to update status: \(error.localizedDescription)"
        }
    }

    // MARK: - Sync score to submissions/

    func syncScore(challengeId: String, pointsPerItem: Int = 1) async {
        guard let uid = Auth.auth().currentUser?.uid,
              let sub = submission else { return }
        let bonusItemId = "item10"
        await syncScore(challengeId: challengeId, uid: uid, bonusItemId: bonusItemId)
    }

    func syncScore(challengeId: String, uid: String, bonusItemId: String?) async {
        do {
            let snap = try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("photo_submissions")
                .document(uid)
                .getDocument()

            guard let data = snap.data() else { return }
            let sub = Self.parseSubmission(uid: uid, data: data)
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
            print("⚠️ ScavengerHunt syncScore failed:", error.localizedDescription)
        }
    }

    // MARK: - Parse

    static func parseSubmission(uid: String, data: [String: Any]) -> ScavengerHuntSubmission {
        let linkedPlayerId  = data["linked_player_id"] as? String
        let displayName     = data["display_name"] as? String
        let completedItems  = data["completed_items"] as? [String: String] ?? [:]
        let itemStatuses    = data["item_statuses"] as? [String: String] ?? [:]
        let item10Subjects  = data["item10_subjects"] as? String

        return ScavengerHuntSubmission(
            id: uid,
            uid: uid,
            linkedPlayerId: linkedPlayerId,
            displayName: displayName,
            completedItems: completedItems,
            itemStatuses: itemStatuses,
            item10Subjects: item10Subjects
        )
    }
}
