//
//  WorldCup2026KnockoutView.swift
//  Best Man Challenge
//
//  Phase 2 root: shows the knockout bracket pick view.
//  (The Phase 1 qualifier list is superseded by the actual bracket.)

import SwiftUI

struct WorldCup2026KnockoutView: View {
    @ObservedObject var picksStore: WorldCup2026PicksStore
    @ObservedObject var resultsStore: WorldCup2026ResultsStore
    @ObservedObject var knockoutStore: WorldCup2026KnockoutStore
    let session: SessionStore

    var body: some View {
        WorldCup2026KnockoutPicksView(
            picksStore: picksStore,
            knockoutStore: knockoutStore,
            resultsStore: resultsStore,
            session: session
        )
    }
}
