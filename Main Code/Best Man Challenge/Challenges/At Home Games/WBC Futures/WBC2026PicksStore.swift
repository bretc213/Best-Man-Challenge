//
//  WBC2026PicksStore.swift
//  Best Man Challenge
//
//  All-picks-up-front WBC bracket store.
//

import Foundation
import FirebaseFirestore

@MainActor
final class WBC2026PicksStore: ObservableObject {

    let bracketId: String

    /// "players" or "admins"
    @Published private(set) var lane: String = "players"

    // Teams/config
    @Published var teams: [WBCTeam] = []
    @Published var teamsByPool: [WBCPool: [WBCTeam]] = [:]

    // Picks
    @Published var allEntries: [WBCEntry] = []
    @Published var myEntry: WBCEntry?

    // Bracket meta
    @Published var locksAt: Date? = nil
    @Published var isLocked: Bool = false

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()

    private var bracketListener: ListenerRegistration?
    private var teamsListener: ListenerRegistration?
    private var picksListener: ListenerRegistration?

    // Cached identity
    private var myLinkedPlayerId: String?
    private var myUid: String?
    private var myDisplayName: String?
    private var myRole: String?

    init(bracketId: String = "wbc_2026") {
        self.bracketId = bracketId
    }

    deinit {
        bracketListener?.remove()
        teamsListener?.remove()
        picksListener?.remove()
    }

    // MARK: - Entry point

    func startListening(linkedPlayerId: String?, uid: String?, displayName: String?, role: String?) {
        self.myLinkedPlayerId = linkedPlayerId
        self.myUid = uid
        self.myDisplayName = displayName
        self.myRole = role

        let roleLower = (role ?? "").lowercased()
        let isExec = ["owner", "commish", "ref", "admin", "exec"].contains(roleLower)

        if let linkedPlayerId, !linkedPlayerId.isEmpty {
            lane = "players"
        } else if isExec, let uid, !uid.isEmpty {
            lane = "admins"
        } else {
            lane = "players"
        }

        stopListening()
        errorMessage = nil
        isLoading = true

        listenBracketDoc()
        listenTeams()
        listenEntries()
    }

    func stopListening() {
        bracketListener?.remove(); bracketListener = nil
        teamsListener?.remove(); teamsListener = nil
        picksListener?.remove(); picksListener = nil
        isLoading = false
    }

    // MARK: - Firestore listeners

    private func listenBracketDoc() {
        bracketListener?.remove()
        bracketListener = db.collection("brackets")
            .document(bracketId)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in
                        self.errorMessage = err.localizedDescription
                        self.isLoading = false
                    }
                    return
                }
                let d = snap?.data() ?? [:]
                let lock = (d["locksAt"] as? Timestamp)?.dateValue()
                let lockedFlag = d["isLocked"] as? Bool

                Task { @MainActor in
                    self.locksAt = lock
                    if let lockedFlag {
                        self.isLocked = lockedFlag
                    } else if let lock {
                        self.isLocked = Date() >= lock
                    } else {
                        self.isLocked = false
                    }
                }
            }
    }

    private func listenTeams() {
        teamsListener?.remove()
        teamsListener = db.collection("brackets")
            .document(bracketId)
            .collection("teams")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in
                        self.errorMessage = err.localizedDescription
                        self.isLoading = false
                    }
                    return
                }
                let docs = snap?.documents ?? []
                let decoded: [WBCTeam] = docs.compactMap { doc in
                    let d = doc.data()
                    let name = d["name"] as? String ?? doc.documentID
                    let abbr = d["abbr"] as? String ?? doc.documentID
                    let poolRaw = (d["pool"] as? String ?? "").uppercased()
                    guard let pool = WBCPool(rawValue: poolRaw) else { return nil }
                    return WBCTeam(
                        id: doc.documentID,
                        name: name,
                        abbr: abbr,
                        pool: pool,
                        logoAsset: d["logoAsset"] as? String,
                        logoStoragePath: d["logoStoragePath"] as? String,
                        logoUrl: d["logoUrl"] as? String
                    )
                }
                let grouped = Dictionary(grouping: decoded, by: { $0.pool })
                    .mapValues { $0.sorted { $0.abbr < $1.abbr } }

                Task { @MainActor in
                    self.teams = decoded.sorted { $0.abbr < $1.abbr }
                    self.teamsByPool = grouped
                }
            }
    }

    private func listenEntries() {
        picksListener?.remove()

        let ref = db.collection("brackets")
            .document(bracketId)
            .collection("picks")
            .document("all")
            .collection(lane)

        picksListener = ref.addSnapshotListener { [weak self] snap, err in
            guard let self else { return }
            if let err {
                Task { @MainActor in
                    self.errorMessage = err.localizedDescription
                    self.isLoading = false
                }
                return
            }

            let docs = snap?.documents ?? []

            // determine my doc id
            let myDocId: String? = {
                if self.lane == "players" {
                    if let lp = self.myLinkedPlayerId, !lp.isEmpty { return lp }
                    if let uid = self.myUid, !uid.isEmpty { return uid }
                    return nil
                } else {
                    if let uid = self.myUid, !uid.isEmpty { return uid }
                    if let lp = self.myLinkedPlayerId, !lp.isEmpty { return lp }
                    return nil
                }
            }()

            var rows: [WBCEntry] = []
            rows.reserveCapacity(docs.count)

            var mine: WBCEntry? = nil

            for doc in docs {
                let d = doc.data()
                let displayName = d["displayName"] as? String ?? doc.documentID
                let linkedPlayerId = d["linkedPlayerId"] as? String ?? doc.documentID
                let updatedAt = (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date.distantPast

                let poolPicks = d["poolPicks"] as? [String: [String: String]] ?? [:]
                let qf = d["qfPicks"] as? [String: String] ?? [:]
                let sf = d["sfPicks"] as? [String: String] ?? [:]
                let champ = d["champPick"] as? String

                let row = WBCEntry(
                    id: doc.documentID,
                    linkedPlayerId: linkedPlayerId,
                    displayName: displayName,
                    updatedAt: updatedAt,
                    poolPicks: poolPicks,
                    qfPicks: qf,
                    sfPicks: sf,
                    champPick: champ
                )
                rows.append(row)

                if let myDocId, doc.documentID == myDocId {
                    mine = row
                }
            }

            rows.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            Task { @MainActor in
                self.allEntries = rows
                self.myEntry = mine
                self.isLoading = false
            }
        }
    }

    // MARK: - Derived matchups

    func teamLabel(_ teamId: String?) -> String {
        guard let teamId, !teamId.isEmpty else { return "TBD" }
        if let t = teams.first(where: { $0.id == teamId }) {
            return t.abbr
        }
        return teamId
    }

    func qfMatchups(for entry: WBCEntry?) -> [WBCMatchup] {
        guard let entry else { return [] }
        let A1 = entry.poolPicks["A"]?["winner"]
        let A2 = entry.poolPicks["A"]?["runnerUp"]
        let B1 = entry.poolPicks["B"]?["winner"]
        let B2 = entry.poolPicks["B"]?["runnerUp"]
        let C1 = entry.poolPicks["C"]?["winner"]
        let C2 = entry.poolPicks["C"]?["runnerUp"]
        let D1 = entry.poolPicks["D"]?["winner"]
        let D2 = entry.poolPicks["D"]?["runnerUp"]

        // Fixed mapping (as requested):
        // QF1: C2 vs D1
        // QF2: A2 vs B1
        // QF3: B2 vs A1
        // QF4: D2 vs C1
        return [
            WBCMatchup(id: "qf1", left: C2, right: D1),
            WBCMatchup(id: "qf2", left: A2, right: B1),
            WBCMatchup(id: "qf3", left: B2, right: A1),
            WBCMatchup(id: "qf4", left: D2, right: C1)
        ]
    }

    func sfMatchups(for entry: WBCEntry?) -> [WBCMatchup] {
        guard let entry else { return [] }
        let qf = qfMatchups(for: entry)
        let qf1w = entry.qfPicks["qf1"]
        let qf2w = entry.qfPicks["qf2"]
        let qf3w = entry.qfPicks["qf3"]
        let qf4w = entry.qfPicks["qf4"]

        // If a user hasn't picked a winner yet, we still show the matchup teams.
        _ = qf // keep for readability
        return [
            WBCMatchup(id: "sf1", left: qf1w, right: qf2w),
            WBCMatchup(id: "sf2", left: qf3w, right: qf4w)
        ]
    }

    func finalMatchup(for entry: WBCEntry?) -> WBCMatchup? {
        guard let entry else { return nil }
        return WBCMatchup(id: "final", left: entry.sfPicks["sf1"], right: entry.sfPicks["sf2"]) 
    }

    // MARK: - Writes

    private func docRefForMe(uid: String, displayName: String, role: String, linkedPlayerId: String?) -> DocumentReference {
        let roleLower = role.lowercased()
        let isExec = ["owner", "commish", "ref", "admin", "exec"].contains(roleLower)

        let laneToUse: String
        let docId: String
        let linkedIdToWrite: String

        if let linkedPlayerId, !linkedPlayerId.isEmpty {
            laneToUse = "players"
            docId = linkedPlayerId
            linkedIdToWrite = linkedPlayerId
        } else if isExec {
            laneToUse = "admins"
            docId = uid
            linkedIdToWrite = uid
        } else {
            laneToUse = "players"
            docId = uid
            linkedIdToWrite = uid
        }

        return db.collection("brackets")
            .document(bracketId)
            .collection("picks")
            .document("all")
            .collection(laneToUse)
            .document(docId)
            .withWriteFields(linkedPlayerId: linkedIdToWrite, displayName: displayName)
    }

    func setPoolPick(
        uid: String,
        displayName: String,
        role: String,
        linkedPlayerId: String?,
        pool: WBCPool,
        slot: String, // "winner" or "runnerUp"
        teamId: String
    ) async throws {
        guard !isLocked else { return }

        let ref = docRefForMe(uid: uid, displayName: displayName, role: role, linkedPlayerId: linkedPlayerId)

        try await ref.setData([
            "updatedAt": Timestamp(date: Date()),
            "poolPicks": [
                pool.rawValue: [
                    slot: teamId
                ]
            ]
        ], merge: true)
    }

    func setBracketPick(
        uid: String,
        displayName: String,
        role: String,
        linkedPlayerId: String?,
        stage: String, // "qfPicks" | "sfPicks"
        key: String,   // qf1..qf4 OR sf1..sf2
        teamId: String
    ) async throws {
        guard !isLocked else { return }
        let ref = docRefForMe(uid: uid, displayName: displayName, role: role, linkedPlayerId: linkedPlayerId)
        try await ref.setData([
            "updatedAt": Timestamp(date: Date()),
            stage: [
                key: teamId
            ]
        ], merge: true)
    }

    func setChampionPick(
        uid: String,
        displayName: String,
        role: String,
        linkedPlayerId: String?,
        teamId: String
    ) async throws {
        guard !isLocked else { return }
        let ref = docRefForMe(uid: uid, displayName: displayName, role: role, linkedPlayerId: linkedPlayerId)
        try await ref.setData([
            "updatedAt": Timestamp(date: Date()),
            "champPick": teamId
        ], merge: true)
    }
}

// MARK: - Small helper

private extension DocumentReference {
    /// Adds standard identity fields without repeating callsites.
    func withWriteFields(linkedPlayerId: String, displayName: String) -> DocumentReference {
        // no-op wrapper; we write fields in setData for merge operations.
        // Keeping this as an extension point if you later want to change schema.
        return self
    }
}
