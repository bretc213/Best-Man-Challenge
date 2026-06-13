import SwiftUI

struct MoreRootView: View {
    @EnvironmentObject var session: SessionStore

    private var isAdmin: Bool {
        let role = (session.profile?.role ?? "").lowercased()
        return ["admin", "owner", "ref", "commish", "commissioner"].contains(role)
    }

    var body: some View {
        List {
            Section("More") {
                NavigationLink {
                    EventsRootView()
                } label: {
                    Label("Events", systemImage: "calendar.circle.fill")
                }

                NavigationLink {
                    BMCShopView()
                } label: {
                    Label("Power-Up Shop", systemImage: "cart.fill")
                }

                NavigationLink {
                    ProfileView()
                } label: {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
            }

            if isAdmin {
                Section("Admin") {
                    NavigationLink {
                        WeeklyChallengeAdminListView()
                            .environmentObject(session)
                    } label: {
                        Label("Weekly Challenge Preview", systemImage: "play.rectangle.fill")
                    }
                }
            }
        }
        .navigationTitle("More")
    }
}
