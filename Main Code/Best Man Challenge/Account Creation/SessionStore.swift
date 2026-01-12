//
//  SessionStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/1/26.
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

    private let db = Firestore.firestore()
    private var listener: AuthStateDidChangeListenerHandle?

    func start() {
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { await self.handleAuth(user) }
        }
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
            let snap = try await db.collection("users").document(user.uid).getDocument()
            if snap.exists {
                profile = try snap.data(as: UserProfile.self)
            } else {
                errorMessage = "No profile found for this login. Please claim an account."
            }
        } catch {
            errorMessage = "Failed to load user profile: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func signOut() {
        do { try Auth.auth().signOut() } catch { }
    }
}
