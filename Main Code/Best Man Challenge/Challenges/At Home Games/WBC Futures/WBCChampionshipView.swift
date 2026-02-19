//
//  WBCChampionshipView.swift
//  Best Man Challenge
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import FirebaseAuth

struct WBCChampionshipView: View {
    @ObservedObject var store: WBC2026PicksStore
    let session: SessionStore

    var body: some View {
        List {
            if store.isLocked {
                Section {
                    Text("Picks are locked")
                        .foregroundStyle(.secondary)
                }
            }

            Section(header: Text("Final")) {
                let final = store.finalMatchup(for: store.myEntry)
                WinnerPickFinalRow(
                    leftId: final?.left,
                    rightId: final?.right,
                    selectedId: store.myEntry?.champPick,
                    teamLabel: { store.teamLabel($0) },
                    locked: store.isLocked
                ) { teamId in
                    Task {
                        try? await store.setChampionPick(
                            uid: Auth.auth().currentUser?.uid ?? "",
                            displayName: session.profile?.displayName ?? "Unknown",
                            role: session.profile?.role ?? "",
                            linkedPlayerId: session.profile?.linkedPlayerId,
                            teamId: teamId
                        )
                    }
                }
            }

            Section {
                Text("Scoring: Quarterfinal winners 8 pts each, Semifinal winners 16 pts each, Champion 32 pts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Championship")
    }
}

private struct WinnerPickFinalRow: View {
    let leftId: String?
    let rightId: String?
    let selectedId: String?
    let teamLabel: (String?) -> String
    let locked: Bool
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button {
                if let leftId, !leftId.isEmpty { onSelect(leftId) }
            } label: {
                HStack {
                    HStack(spacing: 10) {
                        TeamLogoView(teamId: leftId, size: 22)
                        Text(teamLabel(leftId))
                    }
                    Spacer()
                    if selectedId == leftId, leftId != nil { Image(systemName: "checkmark.seal.fill") }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(locked || leftId == nil || leftId == "")

            Button {
                if let rightId, !rightId.isEmpty { onSelect(rightId) }
            } label: {
                HStack {
                    HStack(spacing: 10) {
                        TeamLogoView(teamId: rightId, size: 22)
                        Text(teamLabel(rightId))
                    }
                    Spacer()
                    if selectedId == rightId, rightId != nil { Image(systemName: "checkmark.seal.fill") }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(locked || rightId == nil || rightId == "")
        }
        .padding(.vertical, 4)
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

