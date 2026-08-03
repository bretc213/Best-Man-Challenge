//
//  CFBConfChampsAllPicksView.swift
//  Best Man Challenge
//
//  Everyone's picks, grouped by conference. Preseason picks reveal after the
//  Phase 1 lock (kept blind beforehand so nobody copies).
//

import SwiftUI

struct CFBConfChampsAllPicksView: View {
    @ObservedObject var store: CFBConfChampsStore
    let session: SessionStore

    @State private var expanded: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(store.conferences) { conf in
                    confSection(conf)
                }
            }
            .padding()
        }
        .overlay {
            if store.allEntries.isEmpty {
                ContentUnavailableView(
                    "No picks yet",
                    systemImage: "person.2",
                    description: Text("Player predictions will show here.")
                )
            }
        }
    }

    private func confSection(_ conf: CFBConference) -> some View {
        let isOpen = expanded.contains(conf.id)
        let blind = !conf.isPhase1Locked   // hide preseason picks until lock
        return VStack(spacing: 0) {
            Button {
                if isOpen { expanded.remove(conf.id) } else { expanded.insert(conf.id) }
            } label: {
                HStack {
                    Text(conf.name).font(.headline)
                    if conf.matchupSet {
                        Text(conf.finalists.map { $0.name }.joined(separator: " vs "))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    if let champ = conf.champion {
                        Label(champ.name, systemImage: "crown.fill")
                            .font(.caption2.weight(.semibold)).foregroundStyle(.yellow)
                    }
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding()
            }
            .buttonStyle(.plain)

            if isOpen {
                Divider().padding(.horizontal)
                if blind {
                    Text("Preseason picks are hidden until they lock at the first Power-4 game.")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                } else {
                    VStack(spacing: 8) {
                        ForEach(store.allEntries) { entry in
                            playerRow(entry: entry, conf: conf)
                        }
                    }
                    .padding([.horizontal, .bottom])
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func playerRow(entry: CFBConfChampsEntry, conf: CFBConference) -> some View {
        let p1 = entry.phase1[conf.id]
        let p2 = entry.phase2[conf.id]
        return HStack(alignment: .top) {
            Text(entry.displayName)
                .font(.subheadline.weight(.semibold))
                .frame(width: 90, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                if let p1, !p1.finalistIds.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(p1.finalistIds, id: \.self) { tid in
                            let isChamp = p1.championId == tid
                            Text(CFBData.team(for: tid)?.name ?? tid)
                                .font(.caption)
                                .fontWeight(isChamp ? .bold : .regular)
                            if isChamp {
                                Image(systemName: "crown.fill").font(.system(size: 9)).foregroundStyle(.yellow)
                            }
                            if tid != p1.finalistIds.last { Text("·").foregroundStyle(.secondary) }
                        }
                    }
                } else {
                    Text("— no preseason pick").font(.caption).foregroundStyle(.secondary)
                }
                if let p2 {
                    Text("Champ Week: \(CFBData.team(for: p2)?.name ?? p2)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}
