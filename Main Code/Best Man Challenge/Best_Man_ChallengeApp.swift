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

        // ✅ ONE-TIME: seed Week 4 on app open (guarded by UserDefaults)
        let seedKey = "did_seed_weekly_2026_w04"
        if !UserDefaults.standard.bool(forKey: seedKey) {
            do {
                try await WeeklyChallengeSeeder2026W04.seedQuiz()
                UserDefaults.standard.set(true, forKey: seedKey)
                print("✅ Seeded weekly_challenges/2026_w04")
            } catch {
                print("❌ Week 4 seed failed: \(error.localizedDescription)")
            }
        }
    }
}
