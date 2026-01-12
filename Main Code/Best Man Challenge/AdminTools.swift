//
//  AdminTools.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 12/23/25.
//


import FirebaseFirestore
import FirebaseAuth

enum AdminTools {

    /// Reset ONLY the current user's event balance (Bret)
    static func resetMyBalance(to amount: Int = 300, completion: @escaping (Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(
                NSError(
                    domain: "AdminTools",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Not logged in."]
                )
            )
            return
        }

        let db = Firestore.firestore()
        db.collection("users")
            .document(uid)
            .setData(["event_balance": amount], merge: true) { error in
                completion(error)
            }
    }
}
