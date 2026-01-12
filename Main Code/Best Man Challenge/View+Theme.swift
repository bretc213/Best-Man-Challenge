//
//  View+Theme.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 7/31/25.
//

import SwiftUI

extension View {
    /// Applies card styling: dark background, rounded corners, and subtle shadow
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.card)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }

    /// Primary title text style
    func titleText() -> some View {
        self
            .font(.title.bold())
            .foregroundColor(.textPrimary)
    }

    /// Muted secondary text style
    func secondaryText() -> some View {
        self
            .font(.subheadline)
            .foregroundColor(.textSecondary)
    }

    /// Accent button style (for gold buttons, etc.)
    func accentButtonStyle() -> some View {
        self
            .padding()
            .background(Color.accent)
            .foregroundColor(.black)
            .cornerRadius(10)
    }
}

