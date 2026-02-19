//
//  PokerNightView.swift
//  Best Man Challenge
//

import SwiftUI

struct PokerNightView: View {
    @StateObject private var store: PokerNightStore

    @State private var showElimSheet = false
    @State private var pendingElimPlayerUid: String?
    @State private var selectedEliminatorUid: String = ""

    @State private var isFinalizing: Bool = false
    @State private var alertMessage: String?
    @State private var showAlert: Bool = false

    // ChallengeId used by ChallengePointsFinalizer (point_awards id)
    // Keep it stable.
    private let challengeId = "poker_night_001"
    private let multiplier: Double = 2

    init(eventId: String) {
        _store = StateObject(wrappedValue: PokerNightStore(eventId: eventId))
    }

    var body: some View {
        ThemedScreen {
            content
                .navigationTitle("Poker Night")
        }
        .sheet(isPresented: $showElimSheet) {
            eliminatorSheet
        }
        .alert("Poker Night", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 12) {
            header

            if store.isLoading {
                ProgressView().padding(.top, 30)
            } else if let msg = store.errorMessage {
                Text(msg)
                    .foregroundStyle(.red)
                    .padding(.top, 24)
            } else if let state = store.state {
                list(state: state)
            } else {
                Text("No data.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)
            }

            Spacer(minLength: 0)
        }
        .padding()
    }

    private var header: some View {
        HStack {
            Text(store.state?.name ?? "Poker Night")
                .font(.title2.bold())

            Spacer()

            if store.isOwner {
                Menu {
                    Button {
                        Task { await finalizePokerNight() }
                    } label: {
                        Label(isFinalizing ? "Finalizing..." : "Finalize (×2)", systemImage: "checkmark.seal.fill")
                    }
                    .disabled(isFinalizing || (store.state?.isFinalized ?? false))

                    Button("Reset All", role: .destructive) {
                        Task { await store.resetAll() }
                    }
                    .disabled(isFinalizing)

                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
        }
    }

    private func finalizePokerNight() async {
        guard store.isOwner else { return }

        if store.state?.isFinalized == true {
            alertMessage = "Already finalized."
            showAlert = true
            return
        }

        isFinalizing = true
        defer { isFinalizing = false }

        do {
            // Validate placements + build scores
            let scoresByPlayer = try store.buildFinalizerScores()

            // Run existing finalizer
            let finalizer = ChallengePointsFinalizer()
            try await finalizer.finalizeChallenge(
                challengeId: challengeId,
                scoresByPlayer: scoresByPlayer,
                multiplier: multiplier,
                higherIsBetter: true
            )

            await store.markFinalized()

            alertMessage = "Finalize complete (×2)."
            showAlert = true

        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func list(state: PokerEventState) -> some View {
        let nameFor: (String) -> String = { uid in
            store.displayNameByUid[uid] ?? uid
        }

        let placingSorted = state.playerUids.sorted { a, b in
            nameFor(a).localizedCaseInsensitiveCompare(nameFor(b)) == .orderedAscending
        }

        let eliminatedMap: [String: PokerElimination] =
            Dictionary(uniqueKeysWithValues: state.eliminated.map { ($0.playerUid, $0) })

        let winnerUid = state.winnerUid

        let active = placingSorted.filter { uid in
            eliminatedMap[uid] == nil && uid != winnerUid
        }

        // ✅ Leaderboard stacking (higher finish first): #2 above #12 etc.
        let eliminatedSorted = state.eliminated.sorted { $0.place < $1.place }

        return ScrollView {
            VStack(spacing: 10) {

                if state.isFinalized {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Finalized")
                            .font(.footnote).bold()
                        Spacer()
                        if let d = state.finalizedAt {
                            Text(d.formatted(date: .abbreviated, time: .shortened))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if let winnerUid {
                    playerRow(
                        uid: winnerUid,
                        displayName: nameFor(winnerUid),
                        state: state,
                        elimination: nil,
                        isWinnerPinned: true
                    )
                }

                VStack(spacing: 10) {
                    ForEach(active, id: \.self) { uid in
                        playerRow(
                            uid: uid,
                            displayName: nameFor(uid),
                            state: state,
                            elimination: nil,
                            isWinnerPinned: false
                        )
                    }
                }

                if !eliminatedSorted.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Eliminated")
                            .font(.headline)
                            .padding(.top, 10)

                        ForEach(eliminatedSorted, id: \.playerUid) { elim in
                            playerRow(
                                uid: elim.playerUid,
                                displayName: nameFor(elim.playerUid),
                                state: state,
                                elimination: elim,
                                isWinnerPinned: false
                            )
                        }
                    }
                    .padding(.top, 6)
                }
            }
        }
    }

    @ViewBuilder
    private func playerRow(
        uid: String,
        displayName: String,
        state: PokerEventState,
        elimination: PokerElimination?,
        isWinnerPinned: Bool
    ) -> some View {
        let isChipLead = (state.chipLeadUid == uid)
        let isWinner = (state.winnerUid == uid)

        HStack(spacing: 12) {
            if let elimination {
                Text("#\(elimination.place)")
                    .font(.caption.bold())
                    .frame(width: 52, height: 28)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            } else if isWinner {
                Image(systemName: "crown.fill")
                    .frame(width: 52, height: 28)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            } else {
                Spacer().frame(width: 52, height: 28)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.headline)

                    if isChipLead {
                        Image(systemName: "circle.fill") // swap for chip asset later
                            .font(.caption)
                    }
                }

                if let elimination {
                    Text("Eliminated by \(elimination.eliminatedByName) • \(elimination.eliminatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isWinnerPinned {
                    Text("Winner")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isWinner {
                ZStack {
                    Circle().fill(.thinMaterial)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 44, height: 44)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(isWinner ? Color.yellow.opacity(0.18) : Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isWinner ? Color.yellow.opacity(0.5) : Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contextMenu {
            if store.isOwner && !(store.state?.isFinalized ?? false) && !isFinalizing {
                Button("Winner") {
                    Task { await store.setWinner(uid) }
                }

                Button("Chip Lead") {
                    Task { await store.setChipLead(uid) }
                }

                if elimination == nil {
                    Button("Eliminated…", role: .destructive) {
                        pendingElimPlayerUid = uid
                        selectedEliminatorUid = ""
                        showElimSheet = true
                    }
                } else {
                    Button("Reset", role: .destructive) {
                        Task { await store.resetPlayer(uid) }
                    }
                }
            }
        }
    }

    private var eliminatorSheet: some View {
        NavigationView {
            VStack(spacing: 16) {
                let allEliminatorUids = (store.state?.playerUids ?? []) + (store.state?.refUids ?? [])
                let sortedEliminators = allEliminatorUids.sorted { a, b in
                    let an = store.displayNameByUid[a] ?? a
                    let bn = store.displayNameByUid[b] ?? b
                    return an.localizedCaseInsensitiveCompare(bn) == .orderedAscending
                }

                let targetName: String = {
                    guard let uid = pendingElimPlayerUid else { return "" }
                    return store.displayNameByUid[uid] ?? uid
                }()

                Text("Who eliminated \(targetName)?")
                    .font(.headline)
                    .padding(.top, 8)

                Picker("Eliminated By", selection: $selectedEliminatorUid) {
                    Text("Select...").tag("")
                    ForEach(sortedEliminators, id: \.self) { uid in
                        if uid != pendingElimPlayerUid {
                            Text(store.displayNameByUid[uid] ?? uid).tag(uid)
                        }
                    }
                }
                .pickerStyle(.wheel)

                Spacer()
            }
            .padding()
            .navigationTitle("Elimination")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showElimSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard
                            let targetUid = pendingElimPlayerUid,
                            !selectedEliminatorUid.isEmpty
                        else { return }

                        Task {
                            await store.eliminate(playerUid: targetUid, eliminatedByUid: selectedEliminatorUid)
                        }
                        showElimSheet = false
                    }
                    .disabled(pendingElimPlayerUid == nil || selectedEliminatorUid.isEmpty)
                }
            }
        }
    }
}
