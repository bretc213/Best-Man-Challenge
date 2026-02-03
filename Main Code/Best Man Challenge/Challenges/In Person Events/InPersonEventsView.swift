//
//  InPersonEventsView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/2/26.
//


import SwiftUI

struct InPersonEventsView: View {

    private let events = [
        "Backyard Games",
        "Golf",
        "Board Game/Video Games",
        "Scavenger Hunt",
        "Beach Day",
        "Vegas Odds",
        "Drinking Games"
    ]

    var body: some View {
        ThemedScreen {
            List(events, id: \.self) { event in
                NavigationLink {
                    ComingSoonView(title: event)
                } label: {
                    Text(event)
                        .font(.headline)
                        .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .navigationTitle("In Person Events")
            .background(Color.background)
        }
    }
}

#Preview {
    NavigationView {
        InPersonEventsView()
    }
}
