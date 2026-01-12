//
//  HomeView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 5/23/25.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        ThemedScreen {
            VStack(spacing: 20) {
                Spacer()

                // Main logo
                Image("HomeLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260)
                    .padding(.horizontal)
                    .shadow(color: Color.black.opacity(0.3), radius: 10, y: 6)

                // Optional subtitle (can remove if you want ultra-clean)
                Text("Best Man Challenge")
                    .font(.title2)
                    .bold()
                    .padding(.top, 4)

                Text("May The Best Man Win!")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                // Future buttons placeholder
                VStack(spacing: 12) {
                    NavigationLink {
                        MeetTheGuysView()
                    } label: {
                        Text("Meet the Guys")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    NavigationLink {
                        RulesView()
                    } label: {
                        Text("Rules")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                }
                .padding(.top, 12)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    HomeView()
}
