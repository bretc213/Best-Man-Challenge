import SwiftUI

struct BackyardCornholeSinglesView: View {
    @EnvironmentObject private var store: BackyardChallengeStore
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        ThemedScreen {
            List {
                ForEach(CornholeSinglesBracket.allCases) { bracket in
                    Section(bracket.title) {
                        ForEach(store.cornholePlayers(for: bracket)) { player in
                            CornholeSinglesPlacementRow(
                                bracket: bracket,
                                player: player
                            )
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Singles Tournament")
        }
    }
}

private struct CornholeSinglesPlacementRow: View {
    let bracket: CornholeSinglesBracket
    let player: BackyardPlayer

    @EnvironmentObject private var store: BackyardChallengeStore
    @EnvironmentObject private var session: SessionStore

    private var currentPlace: Int? {
        let p = store.cornholeSinglesDirectPlacements[bracket]?[player.id] ?? 0
        return p > 0 ? p : nil
    }

    private var placeLabel: String {
        guard let place = currentPlace else { return "—" }
        return ordinal(place)
    }

    var body: some View {
        HStack {
            Text(player.displayName)
                .font(.headline)

            Spacer()

            if session.isAdmin {
                Menu {
                    Button("—") {
                        Task { await store.saveCornholeSingleDirectPlacement(bracket: bracket, playerId: player.id, place: 0) }
                    }
                    ForEach(1...4, id: \.self) { place in
                        Button(ordinal(place)) {
                            Task { await store.saveCornholeSingleDirectPlacement(bracket: bracket, playerId: player.id, place: place) }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(placeLabel)
                            .font(.headline)
                            .foregroundStyle(currentPlace != nil ? Color.primary : Color.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(placeLabel)
                    .font(.headline)
                    .foregroundStyle(currentPlace != nil ? Color.primary : Color.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        case 4: return "4th"
        default: return "—"
        }
    }
}
