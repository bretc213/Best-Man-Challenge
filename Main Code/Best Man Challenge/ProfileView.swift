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
        ThemedScreen {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Profile header ──
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Color.accent)

                        if let profile = session.profile {
                            Text(profile.displayName)
                                .font(.title2.bold())
                            Text(Auth.auth().currentUser?.email ?? "N/A")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 24)

                    // ── Info card ──
                    if let profile = session.profile {
                        VStack(spacing: 0) {
                            infoRow(title: "Role", value: profile.role.capitalized)
                            Divider().padding(.leading, 16)
                            infoRow(title: "Linked Player", value: profile.linkedPlayerId ?? "None")
                        }
                        .background(Color.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        Text("Loading profile…")
                            .foregroundStyle(.secondary)
                    }

                    // ── Admin section ──
                    if isAdminLikeUser {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Admin")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)

                            NavigationLink {
                                AdminScoringHubView()
                                    .environmentObject(session)
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.accent.opacity(0.18))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(Color.accent)
                                    }
                                    Text("Scoring Admin")
                                        .font(.headline)
                                        .foregroundStyle(Color.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(Color.card)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }

                    // ── Log out ──
                    Button(role: .destructive) {
                        logoutUser()
                    } label: {
                        Text("Log Out")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.12))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.red.opacity(0.35), lineWidth: 1)
                            )
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Profile")
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
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

#Preview {
    ProfileView()
        .environmentObject(SessionStore())
}
