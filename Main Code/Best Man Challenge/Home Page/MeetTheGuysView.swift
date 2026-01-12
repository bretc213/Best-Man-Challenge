//
//  MeetTheGuysView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/2/26.
//


import SwiftUI

struct MeetTheGuysView: View {

    let guys = MeetTheGuysData.all

    var body: some View {
        ThemedScreen {
            List(guys) { guy in
                NavigationLink(destination: MeetTheGuyDetailView(guy: guy)) {
                    HStack(spacing: 12) {
                        avatar(for: guy)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(guy.name)
                                .font(.headline)
                            Text(guy.nickname)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .navigationTitle("Meet the Guys")
        }
    }

    @ViewBuilder
    private func avatar(for guy: MeetTheGuy) -> some View {
        if let asset = guy.photoAssetName,
           UIImage(named: asset) != nil {
            Image(asset)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.accent.opacity(0.3))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(guy.name.prefix(1)))
                        .font(.headline)
                )
        }
    }
}
