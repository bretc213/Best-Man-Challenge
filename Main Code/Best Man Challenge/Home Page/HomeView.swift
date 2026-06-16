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

                VStack(spacing: 12) {
                    NavigationLink {
                        MeetTheGuysView()
                    } label: {
                        Text("Meet the Guys")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accent)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    NavigationLink {
                        RulesView()
                    } label: {
                        Text("Rules")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.10))
                            .foregroundStyle(Color.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
                            )
                    }
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
