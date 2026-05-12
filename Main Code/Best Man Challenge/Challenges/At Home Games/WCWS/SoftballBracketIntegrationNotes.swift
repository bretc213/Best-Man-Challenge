//
//  SoftballBracketIntegrationNotes.swift
//  Best Man Challenge
//
//  Notes only. You do not have to add this file to the build target.
//

/*
 WCWS MODULE INTEGRATION NOTES

 Files in this folder:
 - SoftballBracketModels.swift
 - SoftballBracketStore.swift
 - SoftballBracketPicksView.swift
 - SoftballBracketAdminResultsView.swift
 - SoftballBracketLeaderboardView.swift
 - SoftballBracketRootView.swift
 - SoftballChallengeSeeder2026.swift

 1. Add all Swift files except this notes file to the app target.

 2. AtHomeGamesView routing needs this branch before the route switch default:

    } else if game.gameType == "softball_bracket" {
        SoftballBracketRootView(
            challengeId: game.gameRefId ?? "wcws_2026",
            session: session
        )

 3. Temporary seed call after Firebase is configured:

    .task {
        do {
            try await SoftballChallengeSeeder2026.seed()
            print("✅ Forced WCWS seed worked")
        } catch {
            print("❌ Forced WCWS seed failed:", error.localizedDescription)
        }
    }

 4. Remove the force seed after confirming Firestore has:
    softball_brackets/wcws_2026
    softball_brackets/wcws_2026/regionals
    softball_brackets/wcws_2026/super_regionals
    at_home_games/wcws_2026

 5. This module expects SessionStore convenience accessors:
    session.role
    session.isAdmin or equivalent
    session.displayName
    session.linkedPlayerId
    session.accountId
*/
