//
//  Best_Man_ChallengeApp.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 5/23/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore

@main
struct BestManChallengeApp: App {
    @StateObject private var session = SessionStore()

    // ✅ NEW: make WeeklyChallengeManager globally available
    @StateObject private var weeklyChallengeManager = WeeklyChallengeManager()

    // ✅ Prevents `.task` from running bootstrap more than once per app launch
    @State private var didBootstrapThisLaunch = false

    init() {
        FirebaseApp.configure()

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color.background)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.textPrimary)]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(Color.accent)
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
                    ClaimAccountView()
                } else {
                    MainTabView()
                }
            }
            .environmentObject(session)
            .environmentObject(weeklyChallengeManager) // ✅ NEW
            .preferredColorScheme(.dark)
            .task {
                // ✅ SwiftUI can re-run `.task` on view rebuilds — guard it.
                guard !didBootstrapThisLaunch else { return }
                didBootstrapThisLaunch = true
                await bootstrapApp()
            }
            // session.start() intentionally not called in onAppear: we start it in bootstrapApp()
        }
    }

    @MainActor
    private func bootstrapApp() async {
        // ✅ Only attempt to clear persistence once per install
        let clearKey = "did_clear_firestore_persistence_v1"
        if !UserDefaults.standard.bool(forKey: clearKey) {
            do {
                try await Firestore.firestore().clearPersistence()
                print("✅ Firestore persistence cleared")
            } catch {
                // If Firestore was already in use, this will fail.
                print("⚠️ clearPersistence failed: \(error.localizedDescription)")
            }
            UserDefaults.standard.set(true, forKey: clearKey)
        }

        // ✅ Start session after persistence attempt
        session.start()

        // ✅ Weekly challenge seeders
        await WeeklyChallengeSeeder2026W23.seedIfNeeded()
        await WeeklyChallengeSeeder2026W24.seedIfNeeded()
        await WeeklyChallengeSeeder2026W25.seedIfNeeded()  // Halfway Point Challenge (5 mini-games, 30 pts)
        await WeeklyChallengeSeeder2026W26.seedIfNeeded()  // July 4th Photo Challenge ✅ Ready
        await WeeklyChallengeSeeder2026W27.seedIfNeeded()  // World Cup Final Props (Team A/B = TBD)
        await WeeklyChallengeSeeder2026W31.seedIfNeeded()
        await WeeklyChallengeSeeder2026W47.seedIfNeeded()
        await WeeklyChallengeSeeder2026W48.seedIfNeeded()

        await BackyardChallengePointsSeeder.seedIfNeeded()

        // await SoftballChallengeSeeder2026.seedIfNeeded()
            
    }
}
