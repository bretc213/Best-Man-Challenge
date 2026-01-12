//
//  UnderConstructionView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/9/26.
//


import SwiftUI

struct UnderConstructionView: View {
    let title: String
    let message: String
    let systemImage: String

    init(
        title: String = "Under Construction",
        message: String = "🚧 This screen is currently being fixed. Please check back later.",
        systemImage: String = "hammer.fill"
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }

    var body: some View {
        ThemedScreen {
            VStack(spacing: 14) {
                Spacer(minLength: 20)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 96, height: 96)

                    Image(systemName: systemImage)
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(Color.accent)
                }

                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer(minLength: 20)
            }
            .padding()
            .navigationTitle(title)
        }
    }
}

#Preview {
    NavigationView {
        UnderConstructionView(
            title: "Weekly Challenges",
            message: "🚧 The weekly challenges are taking an unscheduled coffee break. Check back later."
        )
    }
}
