//
//  WeeklyChallengePastDetailView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/7/26.
//


//
//  WeeklyChallengePastDetailView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/7/26.
//

import SwiftUI

struct WeeklyChallengePastDetailView: View {
    let challenge: WeeklyChallenge

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(challenge.title)
                .font(.title2.bold())

            Text(challenge.description)
                .foregroundStyle(.secondary)

            Divider().opacity(0.35)

            Text("Challenge Type: \(challenge.type.rawValue)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.top, 8)
        .navigationTitle("Week \(challenge.week)")
        .padding(.horizontal)
    }
}
