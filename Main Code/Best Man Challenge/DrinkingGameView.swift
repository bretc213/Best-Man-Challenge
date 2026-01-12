// DrinkingGameView.swift

import SwiftUI

struct DrinkingGameView: View {
    let players = ["P1","P2","P3","P4","P5","P6","P7","P8","P9","P10","P11","P12"]

    var body: some View {
        List {
            NavigationLink("Beer Pong") {
                BeerPongHomeView(players: players)
            }
            // later: NavigationLink("Flip Cup") { FlipCupView(players: players) }
            // etc.
        }
        .navigationTitle("Drinking Games")
    }
}
