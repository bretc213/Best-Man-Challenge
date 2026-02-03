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

        // ✅ Seed Week 5 on app open
        // IMPORTANT: Prefer calling a seeder that ALSO guards by checking Firestore doc exists,
        // so it’s safe across reinstalls & multiple devices.
        await WeeklyChallengeSeeder2026W05.seedIfNeeded()
    }
}
