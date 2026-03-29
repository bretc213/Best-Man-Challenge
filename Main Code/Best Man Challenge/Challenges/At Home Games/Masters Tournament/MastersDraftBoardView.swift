import SwiftUI
import FirebaseFirestore

struct MastersDraftBoardView: View {
    @EnvironmentObject var session: SessionStore
    let gameRefId: String

    @State private var meta: MastersDraftMeta? = nil
    @State private var golfers: [MastersGolfer] = []
    @State private var rosters: [MastersRoster] = []
    @State private var displayNames: [String: String] = [:]
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var listeners: [ListenerRegistration] = []

    private let db = Firestore.firestore()
    private let directory = PlayerDirectory()
    private let service = MastersDraftService()

    var body: some View {
        ThemedScreen {
            ScrollView {
                VStack(spacing: 12) {
                    headerCard

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    if let meta, !meta.isDraftComplete {
                        draftedBoardSection
                        availableGolfersSection
                    } else {
                        summarySection
                    }
                }
                .padding(.vertical, 8)
            }
            .onAppear { attachListeners() }
            .onDisappear { detachListeners() }
        }
    }

    private var linkedPlayerId: String {
        session.profile?.linkedPlayerId ?? ""
    }

    private var sortedGolfers: [MastersGolfer] {
        golfers.sorted {
            if $0.isDrafted != $1.isDrafted { return !$0.isDrafted && $1.isDrafted }
            if $0.oddsSort != $1.oddsSort { return $0.oddsSort < $1.oddsSort }
            return $0.name < $1.name
        }
    }

    private var availableGolfers: [MastersGolfer] {
        sortedGolfers.filter { !$0.isDrafted }
    }

    private var sortedRosters: [MastersRoster] {
        rosters.sorted { lhs, rhs in
            let lhsMin = lhs.picks.map(\.overallPick).min() ?? Int.max
            let rhsMin = rhs.picks.map(\.overallPick).min() ?? Int.max
            if lhsMin != rhsMin { return lhsMin < rhsMin }
            return (displayNames[lhs.playerId] ?? lhs.displayName ?? lhs.playerId)
                < (displayNames[rhs.playerId] ?? rhs.displayName ?? rhs.playerId)
        }
    }

    @ViewBuilder
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(meta?.title ?? "The Masters Draft")
                .font(.title2.bold())

            if let meta {
                Text(onTheClockText(meta))
                    .font(.headline)

                if let draftStartsAt = meta.draftStartsAt {
                    Text("Draft starts \(dateString(draftStartsAt))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let lastUpdated = meta.lastUpdated {
                    Text("Last updated \(dateString(lastUpdated))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    @ViewBuilder
    private var draftedBoardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Draft Board")
                .font(.headline)
                .padding(.horizontal)

            if sortedRosters.isEmpty {
                ContentUnavailableView(
                    "No picks yet",
                    systemImage: "person.crop.square.badge.plus",
                    description: Text("The draft board will fill in as picks come in.")
                )
                .padding(.top, 12)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(sortedRosters) { roster in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(displayNames[roster.playerId] ?? roster.displayName ?? roster.playerId)
                                .font(.headline)

                            if roster.picks.isEmpty {
                                Text("No golfers yet")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(roster.picks, id: \.overallPick) { pick in
                                    HStack {
                                        Text("R\(pick.round) • #\(pick.overallPick)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 62, alignment: .leading)

                                        Text(pick.golferName)
                                            .font(.subheadline.weight(.semibold))

                                        Spacer()

                                        if let golfer = golfers.first(where: { $0.id == pick.golferId }),
                                           !golfer.oddsText.isEmpty {
                                            Text(golfer.oddsText)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var availableGolfersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Available Golfers")
                    .font(.headline)
                Spacer()
                Text("Sorted by odds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            LazyVStack(spacing: 10) {
                ForEach(availableGolfers) { golfer in
                    Button {
                        Task { await draft(golfer) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(golfer.name)
                                    .font(.headline)
                                    .foregroundStyle(Color.textPrimary)

                                Text(golfer.oddsText)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if isSubmitting {
                                ProgressView()
                            } else if isMyTurn {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isMyTurn || isSubmitting)
                    .padding(.horizontal)
                }
            }
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Draft Summary")
                .font(.headline)
                .padding(.horizontal)

            LazyVStack(spacing: 10) {
                ForEach(sortedRosters) { roster in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(displayNames[roster.playerId] ?? roster.displayName ?? roster.playerId)
                                .font(.headline)
                            Spacer()
                            if roster.totalPoints > 0 {
                                Text("\(roster.totalPoints) pts")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }

                        ForEach(roster.picks, id: \.overallPick) { pick in
                            HStack {
                                Text("R\(pick.round)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .leading)

                                Text(pick.golferName)

                                Spacer()

                                if let golfer = golfers.first(where: { $0.id == pick.golferId }) {
                                    Text(golfer.oddsText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }
            }
        }
    }

    private var isMyTurn: Bool {
        meta?.currentDrafterPlayerId == linkedPlayerId && !(meta?.isDraftComplete ?? false)
    }

    private func draft(_ golfer: MastersGolfer) async {
        guard !linkedPlayerId.isEmpty else {
            errorMessage = "No linked player id."
            return
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            try await service.draftGolfer(gameRefId: gameRefId, playerId: linkedPlayerId, golferId: golfer.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func attachListeners() {
        guard listeners.isEmpty else { return }
        let ref = db.collection("masters_drafts").document(gameRefId)

        listeners.append(ref.addSnapshotListener { snap, error in
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }

            self.meta = MastersDraftMeta(
                id: snap?.documentID ?? self.gameRefId,
                data: snap?.data() ?? [:]
            )
        })

        listeners.append(ref.collection("golfers").addSnapshotListener { snap, error in
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }

            self.golfers = (snap?.documents ?? []).map {
                MastersGolfer(id: $0.documentID, data: $0.data())
            }
        })

        listeners.append(ref.collection("rosters").addSnapshotListener { snap, error in
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }

            let loaded = (snap?.documents ?? []).map {
                MastersRoster(id: $0.documentID, data: $0.data())
            }
            self.rosters = loaded

            Task {
                let ids = loaded.map(\.playerId)
                let names = await directory.fetchDisplayNames(playerIds: ids)
                await MainActor.run {
                    self.displayNames = names
                }
            }
        })
    }

    private func detachListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    private func onTheClockText(_ meta: MastersDraftMeta) -> String {
        if meta.isDraftComplete {
            return meta.isFinalized ? "Finalized" : "Draft complete • scoring live"
        }

        let name = displayNames[meta.currentDrafterPlayerId ?? ""] ?? meta.currentDrafterPlayerId ?? "TBD"
        return "Round \(meta.currentRound) • Pick \(meta.currentOverallPick) • On the clock: \(name)"
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
