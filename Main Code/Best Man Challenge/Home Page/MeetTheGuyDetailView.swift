//
//  MeetTheGuyDetailView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/2/26.
//


import SwiftUI

struct MeetTheGuyDetailView: View {
    let guy: MeetTheGuy

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                avatar

                Text(guy.name)
                    .font(.title2).bold()

                Text(guy.nickname)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                infoCard(title: "Relationship", value: guy.relationship)
                infoCard(title: "Favorite Memory", value: guy.favoriteMemory)
                infoCard(title: "Rating", value: guy.rating)
                infoCard(title: "Fun Facts", value: guy.funFacts)

            }
            .padding()
        }
        .navigationTitle(guy.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var avatar: some View {
        if let asset = guy.photoAssetName,
           UIImage(named: asset) != nil {
            Image(asset)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.accent.opacity(0.3))
                .frame(width: 120, height: 120)
                .overlay(
                    Text(String(guy.name.prefix(1)))
                        .font(.largeTitle)
                )
        }
    }

    private func infoCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
        .cardStyle()
    }
}
