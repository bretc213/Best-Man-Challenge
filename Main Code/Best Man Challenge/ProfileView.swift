//
//  ProfileView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 5/23/25.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {

                Text("Your Profile")
                    .font(.largeTitle)
                    .bold()

                // Email (from Firebase Auth)
                Text("Email: \(Auth.auth().currentUser?.email ?? "N/A")")
                    .foregroundStyle(.secondary)

                // Firestore-backed profile info
                if let profile = session.profile {
                    infoRow(title: "Name", value: profile.displayName)
                    infoRow(title: "Role", value: profile.role.capitalized)
                    infoRow(
                        title: "Linked Player",
                        value: profile.linkedPlayerId ?? "None"
                    )
                } else {
                    Text("Loading profile…")
                        .foregroundStyle(.secondary)
                }

                // ============================
                // Admin Section
                // ============================
                if isAdminLikeUser {
                    Divider()
                        .padding(.vertical, 10)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Admin")
                            .font(.headline)

                        NavigationLink {
                            AdminScoringHubView()
                                .environmentObject(session)
                        } label: {
                            HStack {
                                Label("Scoring Admin", systemImage: "checkmark.seal.fill")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color.black.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                Divider()
                    .padding(.vertical, 10)

                Button(role: .destructive) {
                    logoutUser()
                } label: {
                    Text("Log Out")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private var isAdminLikeUser: Bool {
        guard let role = session.profile?.role else { return false }
        return role == "owner" || role == "commish"
    }

    private func logoutUser() {
        do {
            try Auth.auth().signOut()
            // SessionStore + App.swift routing will handle navigation
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ProfileView()
        .environmentObject(SessionStore())
}
