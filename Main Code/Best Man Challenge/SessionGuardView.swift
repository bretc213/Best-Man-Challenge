//
//  SessionGuardView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/2/26.
//


import SwiftUI

struct SessionGuardView<Content: View>: View {
    @EnvironmentObject var session: SessionStore
    let content: () -> Content

    var body: some View {
        Group {
            if session.isLoading {
                ZStack {
                    Color.background.ignoresSafeArea()
                    ProgressView("Loading...")
                }
            } else if session.firebaseUser == nil {
                ClaimAccountView()
            } else if session.profile == nil {
                VStack(spacing: 12) {
                    Text("Account setup incomplete")
                        .font(.title3).bold()
                    Text(session.errorMessage ?? "Please sign out and sign back in. If this continues, contact the owner.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    Button("Sign Out") { session.signOut() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                content()
            }
        }
    }
}
