import SwiftUI

struct MoreRootView: View {
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
        }
        .navigationTitle("More")
    }
}
