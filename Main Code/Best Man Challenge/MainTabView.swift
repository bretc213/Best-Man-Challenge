import SwiftUI

struct MainTabView: View {
    init() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Color.background)

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = UIColor(Color.accent)
    }

    var body: some View {
        TabView {

            // ✅ Wrap Home in NavigationView so Home buttons can push screens
            NavigationView {
                HomeView()
            }
            .tabItem {
                VStack {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            }

            NavigationView {
                MainChallengeView()
            }
            .tabItem {
                VStack {
                    Image(systemName: "flame.fill")
                    Text("Challenges")
                }
            }

            NavigationView {
                EventsView()
            }
            .tabItem {
                VStack {
                    Image(systemName: "calendar.circle.fill")
                    Text("Events")
                }
            }

            NavigationView {
                LeaderboardView()
            }
            .tabItem {
                VStack {
                    Image(systemName: "list.number")
                    Text("Leaderboard")
                }
            }

            NavigationView {
                ProfileView()
            }
            .tabItem {
                VStack {
                    Image(systemName: "person.crop.circle.fill")
                    Text("Profile")
                }
            }
        }
        .background(Color.background.ignoresSafeArea())
    }
}
