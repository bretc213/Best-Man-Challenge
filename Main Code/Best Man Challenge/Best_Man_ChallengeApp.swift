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

    // ✅ NEW: forces users onto TestFlight when their build is below the
    // minimum_version set in Firestore (app_config/ios).
    @StateObject private var updateChecker = AppUpdateChecker()

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
                if updateChecker.updateRequired {
                    // ✅ Hard block — nothing else loads until they update.
                    UpdateRequiredView(message: updateChecker.message)
                } else if session.isLoading {
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
                // ✅ Check version first. If an update is required the gate
                // shows immediately; bootstrap still runs so Firestore stays warm.
                await updateChecker.check()
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
        // W27 Home Run Derby — seeder removed, challenge is finalized
        await WeeklyChallengeSeeder2026W28.seedIfNeeded()  // World Cup Final — Spain vs Argentina
        await WeeklyChallengeSeeder2026W29.seedIfNeeded()  // Triple Wordle (was W31)
        await WeeklyChallengeSeeder2026W30.seedIfNeeded()  // Bret & Amanda Scavenger Hunt (was W29)
        await WeeklyChallengeSeeder2026W31.seedIfNeeded()  // The Midsummer Cipher (was W30) — overwrites old Triple Wordle
        await WeeklyChallengeSeeder2026W32.seedIfNeeded()  // Connections — Best Man Edition #1 (10 pts)
        await WeeklyChallengeSeeder2026W33.seedIfNeeded()  // NFL Preseason Pick 'Em — 10 Sat games via prop engine (10 pts)
        await WeeklyChallengeSeeder2026W34.seedIfNeeded()  // College Football Hype Quiz — 10 Qs (10 pts)
        await WeeklyChallengeSeeder2026W35.seedIfNeeded()  // CFB Week 1 Ranked Pick 'Em — SCAFFOLD, self-skips until matchups filled
        await WeeklyChallengeSeeder2026W47.seedIfNeeded()
        await WeeklyChallengeSeeder2026W48.seedIfNeeded()

        await BackyardChallengePointsSeeder.seedIfNeeded()

        // ✅ In-person events (re-runs on every launch to pick up date/content changes)
        try? await InPersonEventsSeeder.seed()

        // await SoftballChallengeSeeder2026.seedIfNeeded()

    }
}
