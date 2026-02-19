//
//  WBCBracketRoundView.swift
//  Best Man Challenge
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct WBCBracketRoundView: View {
    let title: String
    let matchups: [WBCMatchup]
    /// Prefix isn't used for logic but helps readability ("qf" / "sf").
    let pickKeyPrefix: String
    let pickValueProvider: (String) -> String?
    let onPick: (String, String) async throws -> Void
    let teamLabel: (String?) -> String
    let locked: Bool

    var body: some View {
        List {
            Section {
                Text("Pick the winner for each matchup.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(matchups) { m in
                Section(header: Text(matchupTitle(m.id))) {
                    WinnerPickRow(
                        leftId: m.left,
                        rightId: m.right,
                        selectedId: pickValueProvider(m.id),
                        teamLabel: teamLabel,
                        locked: locked
                    ) { teamId in
                        Task { try? await onPick(m.id, teamId) }
                    }
                }
            }
        }
        .navigationTitle(title)
    }

    private func matchupTitle(_ id: String) -> String {
        switch id {
        case "qf1": return "QF1"
        case "qf2": return "QF2"
        case "qf3": return "QF3"
        case "qf4": return "QF4"
        case "sf1": return "SF1"
        case "sf2": return "SF2"
        default: return id.uppercased()
        }
    }
}

private struct WinnerPickRow: View {
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
                    if selectedId == leftId, leftId != nil { Image(systemName: "checkmark.circle.fill") }
                }
            }
            .buttonStyle(.bordered)
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
                    if selectedId == rightId, rightId != nil { Image(systemName: "checkmark.circle.fill") }
                }
            }
            .buttonStyle(.bordered)
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

