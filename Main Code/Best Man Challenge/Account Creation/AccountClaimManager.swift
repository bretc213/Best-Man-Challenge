//
//  AccountClaimManager.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/1/26.
//


import Foundation
import FirebaseAuth
import FirebaseFirestore

enum ClaimError: LocalizedError {
    case accountNotFound
    case inactive
    case alreadyClaimed
    case codeMismatch

    var errorDescription: String? {
        switch self {
        case .accountNotFound: return "Account not found."
        case .inactive: return "This account is inactive."
        case .alreadyClaimed: return "This account has already been claimed."
        case .codeMismatch: return "Claim code is incorrect."
        }
    }
}

@MainActor
final class AccountClaimManager: ObservableObject {
    @Published var isWorking = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func claim(accountId: String, claimCode: String, email: String, password: String) async {
        isWorking = true
        errorMessage = nil

        let accountId = accountId.trimmingCharacters(in: .whitespacesAndNewlines)
        let claimCode = claimCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        do {
            let accountRef = db.collection("accounts").document(accountId)
            let snap = try await accountRef.getDocument()
            guard snap.exists else { throw ClaimError.accountNotFound }

            let data = snap.data() ?? [:]

            let isActive = (data["is_active"] as? Bool) ?? true
            if !isActive { throw ClaimError.inactive }

            if (data["claimed_by_uid"] as? String) != nil {
                throw ClaimError.alreadyClaimed
            }

            let storedCode = (data["claim_code"] as? String)?.uppercased()
            guard storedCode == claimCode else { throw ClaimError.codeMismatch }

            // Create Auth user
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid

            // Create users/{uid} mapping from account doc
            let userData: [String: Any] = [
                "account_id": accountId,
                "display_name": data["display_name"] as? String ?? "",
                "role": data["role"] as? String ?? "player",
                "linked_player_id": data["linked_player_id"] as Any
            ]

            let batch = db.batch()
            batch.setData(userData, forDocument: db.collection("users").document(uid), merge: true)
            batch.updateData([
                "claimed_by_uid": uid,
                "claimed_at": FieldValue.serverTimestamp()
            ], forDocument: accountRef)

            try await batch.commit()

        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isWorking = false
    }
}
