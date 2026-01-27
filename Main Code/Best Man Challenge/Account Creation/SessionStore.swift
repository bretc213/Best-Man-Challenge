//
//  SessionStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/1/26.
//  Updated: lazy Firestore usage so clearPersistence() can run first.
//


import Foundation
import FirebaseAuth
import FirebaseFirestore

struct UserProfile: Codable {
    let accountId: String
    let displayName: String
    let role: String
    let linkedPlayerId: String?

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case displayName = "display_name"
        case role
        case linkedPlayerId = "linked_player_id"
    }
}

@MainActor
final class SessionStore: ObservableObject {
    @Published var firebaseUser: User?
    @Published var profile: UserProfile?
    @Published var isLoading = true
    @Published var errorMessage: String?

    // IMPORTANT: do NOT create Firestore here
    private var listener: AuthStateDidChangeListenerHandle?

    init() {
        // Keep init lightweight — no Firestore access here
        isLoading = true
    }

    func start() {
        // Avoid double-listening
        guard listener == nil else { return }

        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            Task { await self.handleAuth(user) }
        }

        // Handle already-authenticated user
        Task { await handleAuth(Auth.auth().currentUser) }
    }

    private func firestore() -> Firestore {
        // Create Firestore only when needed
        Firestore.firestore()
    }

    private func handleAuth(_ user: User?) async {
        isLoading = true
        errorMessage = nil
        firebaseUser = user
        profile = nil

        guard let user else {
            isLoading = false
            return
        }

        do {
            let db = firestore()
            let ref = db.collection("users").document(user.uid)
            let snap = try await ref.getDocument()

            if snap.exists, let data = snap.data() {
                let accountId = data["account_id"] as? String ?? user.uid
                let displayName = data["display_name"] as? String ?? (user.displayName ?? "Unknown")
                let role = data["role"] as? String ?? "player"
                let linked = data["linked_player_id"] as? String

                profile = UserProfile(
                    accountId: accountId,
                    displayName: displayName,
                    role: role,
                    linkedPlayerId: linked
                )
            } else {
                errorMessage = "No profile found for this login. Please claim an account."
            }
        } catch {
            errorMessage = "Failed to load user profile: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            firebaseUser = nil
            profile = nil
        } catch {
            print("Sign out error:", error.localizedDescription)
        }
    }

    deinit {
        if let h = listener {
            Auth.auth().removeStateDidChangeListener(h)
            listener = nil
        }
    }
}
