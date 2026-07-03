//
//  GolfEventHomeView.swift
//  Best Man Challenge
//

import SwiftUI

struct GolfEventHomeView: View {
    @StateObject private var store = GolfEventStore()
    @EnvironmentObject var session: SessionStore

    private var isOwner: Bool { session.isAdmin }

    var body: some View {
        Group {
            if store.isLoading {
                ZStack {
                    Color.background.ignoresSafeArea()
                    ProgressView()
                }
            } else {
                GolfLeaderboardView(store: store, isOwner: isOwner)
            }
        }
        .navigationTitle("Golf")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.start() }
        .onDisappear { store.stop() }
    }
}
