//
//  ThemedScreen.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 7/31/25.
//


import SwiftUI

struct ThemedScreen<Content: View>: View {
    let content: () -> Content

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea() // Global dark background
            content()
                .foregroundColor(.textPrimary) // Global text color
        }
    }
}
