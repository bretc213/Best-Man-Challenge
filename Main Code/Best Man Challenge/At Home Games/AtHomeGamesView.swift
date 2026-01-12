//
//  AtHomeGamesView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/2/26.
//


import SwiftUI

struct AtHomeGamesView: View {

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 120), spacing: 18)
    ]

    var body: some View {
        ThemedScreen {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {

                    NavigationLink(destination: CFBBracketView()) {
                        FolderIconTile(
                            title: "CFB Bracket",
                            assetImage: "CFPLogo"
                        )
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink {
                        NFLPlayoffsRootView()
                    } label: {
                        FolderIconTile(title: "NFL Playoffs", assetImage: "NFLLogo") // later
                    }

                    // Future games go here (paste NavLink above)
                }
                .padding()
            }
            .navigationTitle("At Home Games")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    NavigationView {
        AtHomeGamesView()
    }
}
