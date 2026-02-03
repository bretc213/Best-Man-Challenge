//
//  NFLMatchupPicksDetailView.swift
//  Best Man Challenge
//

import SwiftUI

struct NFLMatchupPicksDetailView: View {
    @ObservedObject var store: NFLPlayoffsPicksStore
    let session: SessionStore
    let matchup: BracketMatchup

    // Identifiable wrapper (fixes tuple Identifiable error)
    private struct PickRow: Identifiable {
        let id: String
        let name: String
        let teamId: String?
    }

    private var rows: [PickRow] {
        store.allPlayersPicks
            .map { doc in
                PickRow(
                    id: doc.id,                       // RoundPicksDoc.id (linkedPlayerId)
                    name: doc.displayName,
                    teamId: doc.picks[matchup.id]
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Picks")
                .font(.title3.bold())

            Text("\(matchup.away.name) @ \(matchup.home.name)")
                .foregroundStyle(.secondary)

            if let err = store.errorMessage {
                Text("Couldn’t load: \(err)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if store.isLoading {
                ProgressView("Loading picks...")
                    .padding(.top, 8)
            }

            List {
                ForEach(rows) { r in
                    HStack {
                        Text(r.name)
                        Spacer()
                        Text(labelForTeamId(r.teamId))
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                }

                if rows.isEmpty && !store.isLoading {
                    Text("No picks yet.")
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
        }
        .padding(.top, 8)
        
    }

    private func labelForTeamId(_ teamId: String?) -> String {
        guard let teamId, !teamId.isEmpty else { return "—" }
        if teamId == matchup.away.id { return matchup.away.name }
        if teamId == matchup.home.id { return matchup.home.name }
        return teamId
    }
}
