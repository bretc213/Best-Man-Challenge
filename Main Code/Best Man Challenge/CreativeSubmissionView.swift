//
//  CreativeSubmissionView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 5/26/25.
//


import SwiftUI

struct CreativeSubmissionView: View {
    let challenge: WeeklyChallenge

    var body: some View {
        VStack(spacing: 20) {
            Text(challenge.title)
                .font(.title)
                .bold()

            Text(challenge.description)
                .multilineTextAlignment(.center)

            Text("📸 Submit your entry by sharing a screenshot or image!")
                .foregroundColor(.blue)
        }
    }
}
