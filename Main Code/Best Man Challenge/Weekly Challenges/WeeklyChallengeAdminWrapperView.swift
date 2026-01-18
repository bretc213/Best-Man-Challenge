//
//  WeeklyChallengeAdminWrapperView.swift
//  Best Man Challenge
//

import SwiftUI
import FirebaseAuth

struct WeeklyChallengeAdminWrapperView: View {
    @EnvironmentObject var challengeManager: WeeklyChallengeManager
    @EnvironmentObject var session: SessionStore

    var body: some View {
        WeeklyChallengeView()
            .environmentObject(challengeManager)
            .environmentObject(session)
            .onAppear {
                // ✅ Critical: provides uid so admins can submit even without linkedPlayerId
                challengeManager.setUserContext(
                    uid: Auth.auth().currentUser?.uid,
                    linkedPlayerId: session.profile?.linkedPlayerId,
                    displayName: session.profile?.displayName
                )
            }
    }
}
