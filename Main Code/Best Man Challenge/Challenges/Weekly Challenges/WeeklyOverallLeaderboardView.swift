//
//  WeeklyOverallLeaderboardView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/12/26.
//


import SwiftUI

struct WeeklyOverallLeaderboardView: View {
    @StateObject private var store = WeeklyOverallStore()
    @State private var mode: WeeklyGroupMode = .players

    var body: some View {
        VStack(spacing: 10) {

            HStack {
                Picker("", selection: $mode) {
                    ForEach(WeeklyGroupMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    store.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .padding(.leading, 8)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Divider().opacity(0.35)

            if store.isLoading {
                ProgressView("Calculating totals...")
                    .padding()
                Spacer()
            } else if let err = store.errorMessage {
                Text("Couldn’t load: \(err)")
                    .foregroundStyle(.secondary)
                    .padding()
                Spacer()
            } else {
                List(rowsForMode) { row in
                    HStack {
                        Text(row.displayName)
                        Spacer()
                        Text("\(row.score)")
                            .fontWeight(.semibold)
                    }
                }
                .listStyle(.plain)
            }
        }
        .onAppear {
            store.refresh()
        }
    }

    private var rowsForMode: [WeeklyScoreRow] {
        switch mode {
        case .players: return store.playersRows
        case .admins:  return store.adminsRows
        }
    }
}
