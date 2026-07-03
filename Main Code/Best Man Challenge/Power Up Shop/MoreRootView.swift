import SwiftUI

struct MoreRootView: View {
    @EnvironmentObject var session: SessionStore

    private var isAdmin: Bool {
        let role = (session.profile?.role ?? "").lowercased()
        return ["admin", "owner", "ref", "commish", "commissioner"].contains(role)
    }

    var body: some View {
        ThemedScreen {
            List {
                Section {
                    NavigationLink {
                        UnderConstructionView()
                    } label: {
                        hubRow(title: "Missions", subtitle: "Complete missions to earn bonus points", systemImage: "target")
                    }

                    NavigationLink {
                        BMCShopView()
                    } label: {
                        hubRow(title: "Power-Up Shop", subtitle: "Spend your points on power-ups", systemImage: "cart.fill")
                    }

                    NavigationLink {
                        ProfileView()
                    } label: {
                        hubRow(title: "Profile", subtitle: "Your account and settings", systemImage: "person.crop.circle.fill")
                    }
                }
                .listRowBackground(Color.clear)

                if isAdmin {
                    Section {
                        NavigationLink {
                            WeeklyChallengeAdminListView()
                                .environmentObject(session)
                        } label: {
                            hubRow(title: "Weekly Challenge Preview", subtitle: "Preview and test upcoming challenges", systemImage: "play.rectangle.fill")
                        }
                    } header: {
                        Text("Admin")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.background)
            .navigationTitle("More")
        }
    }

    @ViewBuilder
    private func hubRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 46, height: 46)
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
