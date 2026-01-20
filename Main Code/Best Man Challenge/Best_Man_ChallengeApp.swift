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
            .onAppear {
                session.start()
            }
            // ✅ DEV ONLY: runs once due to the UserDefaults + Firestore existence guards
            /*.task {
                Task {
                    do {
                        try await InPersonEventsSeeder.seed()
                        print("✅ Events seeded")
                    } catch {
                        print("❌ Events seed failed:", error)
                    }
                }
            }*/
            
            

            
        }
    }
}
