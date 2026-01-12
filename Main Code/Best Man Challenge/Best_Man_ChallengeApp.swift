//
//  Best_Man_ChallengeApp.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 5/23/25.
//

import SwiftUI
import Firebase

@main
struct BestManChallengeApp: App {

    @StateObject private var session = SessionStore()

    init() {
        FirebaseApp.configure()

        // ✅ DEV ONLY: seed the test Sudoku → key → cipher → riddle doc once
        // Run the app one time, confirm Firestore updated, then comment this Task out.
        /*Task {
            do {
                try await WeeklyChallengeSeeder.seedTestCipherRiddleWeek()
            } catch {
                print("❌ WeeklyChallengeSeeder failed: \(error.localizedDescription)")
            }
         
        Task {
            do {
                try await WeeklyChallengeSeeder2026W01.seedQuiz()
            } catch {
                print("❌ seedQuiz failed: \(error.localizedDescription)")
            }
        }
         }*/

         

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color.background)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.textPrimary)]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(Color.accent) // for buttons
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if session.isLoading {
                    ZStack {
                        Color.background.ignoresSafeArea()
                        ProgressView("Loading...")
                            .foregroundStyle(Color.textPrimary)
                    }
                } else if session.firebaseUser == nil {
                    // Not signed in yet → Claim / Sign In flow
                    ClaimAccountView()
                } else {
                    // Signed in → Main app
                    MainTabView()
                }
            }
            .environmentObject(session)      // ✅ Step 7: app-wide session access
            .preferredColorScheme(.dark)     // 🔥 Enforces dark mode app-wide
            .onAppear {
                session.start()
            }
        }
    }
}
