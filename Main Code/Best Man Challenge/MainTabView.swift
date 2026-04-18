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

            NavigationView {
                HomeView()
            }
            .tabItem {
                VStack {
                    Image(systemName: "house.fill")
                    Text("Main")
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
                LeaderboardView()
            }
            .tabItem {
                VStack {
                    Image(systemName: "list.number")
                    Text("Leaderboard")
                }
            }

            NavigationView {
                //BMCCoinMissionBoardView()
                UnderConstructionView()
            }
            .tabItem {
                VStack {
                    Image(systemName: "target")
                    Text("Missions")
                }
            }

            // These will appear under More automatically.
            NavigationView {
                EventsRootView()
            }
            .tabItem {
                VStack {
                    Image(systemName: "calendar.circle.fill")
                    Text("Events")
                }
            }

            NavigationView {
                //BMCShopView()
                UnderConstructionView()
            }
            .tabItem {
                VStack {
                    Image(systemName: "cart.fill")
                    Text("Shop")
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
