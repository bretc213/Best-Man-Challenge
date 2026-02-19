//
//  WBCPoolPicksView.swift
//  Best Man Challenge
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import FirebaseAuth

struct WBCPoolPicksView: View {
    @ObservedObject var store: WBC2026PicksStore
    let session: SessionStore

    var body: some View {
        List {
            if store.isLocked {
                Section {
                    Text("Picks are locked")
                        .foregroundStyle(.secondary)
                }
            } else if let locksAt = store.locksAt {
                Section {
                    Text("Locks at \(locksAt.formatted(date: .abbreviated, time: .shortened))")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(WBCPool.allCases) { pool in
                Section(header: Text("Pool \(pool.rawValue)")) {
                    let teams = store.teamsByPool[pool] ?? []
                    PoolSlotPickerRow(
                        title: "Winner (1)",
                        currentTeamId: store.myEntry?.poolPicks[pool.rawValue]?["winner"],
                        options: teams,
                        disabledIds: [store.myEntry?.poolPicks[pool.rawValue]?["runnerUp"]].compactMap { $0 },
                        locked: store.isLocked,
                        label: { $0.abbr }
                    ) { teamId in
                        Task {
                            try? await store.setPoolPick(
                                uid: Auth.auth().currentUser?.uid ?? "",
                                displayName: session.profile?.displayName ?? "Unknown",
                                role: session.profile?.role ?? "",
                                linkedPlayerId: session.profile?.linkedPlayerId,
                                pool: pool,
                                slot: "winner",
                                teamId: teamId
                            )
                        }
                    }

                    PoolSlotPickerRow(
                        title: "Runner-up (2)",
                        currentTeamId: store.myEntry?.poolPicks[pool.rawValue]?["runnerUp"],
                        options: teams,
                        disabledIds: [store.myEntry?.poolPicks[pool.rawValue]?["winner"]].compactMap { $0 },
                        locked: store.isLocked,
                        label: { $0.abbr }
                    ) { teamId in
                        Task {
                            try? await store.setPoolPick(
                                uid: Auth.auth().currentUser?.uid ?? "",
                                displayName: session.profile?.displayName ?? "Unknown",
                                role: session.profile?.role ?? "",
                                linkedPlayerId: session.profile?.linkedPlayerId,
                                pool: pool,
                                slot: "runnerUp",
                                teamId: teamId
                            )
                        }
                    }
                }
            }

            Section {
                Text("Scoring: 2 pts for correct top-2 team + 2 bonus if correct seed (1 vs 2).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("WBC 2026")
    }
}

private struct PoolSlotPickerRow: View {
    let title: String
    let currentTeamId: String?
    let options: [WBCTeam]
    let disabledIds: [String]
    let locked: Bool
    let label: (WBCTeam) -> String
    let onSelect: (String) -> Void

    var body: some View {
        HStack {
            Text(title)
            Spacer()

            Menu {
                ForEach(options) { t in
                    Button {
                        onSelect(t.id)
                    } label: {
                        HStack(spacing: 10) {
                            TeamLogoView(teamId: t.id, size: 20)
                            Text(label(t))
                        }
                    }
                    .disabled(locked || disabledIds.contains(t.id))
                }
            } label: {
                HStack(spacing: 10) {
                    TeamLogoView(teamId: currentTeamId, size: 20)
                    Text(labelText)
                        .fontWeight(.semibold)
                }
            }
            .disabled(locked)
        }
    }

    private var labelText: String {
        guard let id = currentTeamId, !id.isEmpty else { return "Pick" }
        if let t = options.first(where: { $0.id == id }) {
            return label(t)
        }
        return id
    }
}

private struct TeamLogoView: View {
    let teamId: String?
    var size: CGFloat = 24

    var body: some View {
        #if canImport(UIKit)
        if let id = teamId, !id.isEmpty, let ui = UIImage(named: id) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        } else {
            fallback
        }
        #else
        fallback
        #endif
    }

    private var fallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
            Text((teamId?.isEmpty == false ? teamId! : "?") )
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .frame(width: size, height: size)
    }
}
