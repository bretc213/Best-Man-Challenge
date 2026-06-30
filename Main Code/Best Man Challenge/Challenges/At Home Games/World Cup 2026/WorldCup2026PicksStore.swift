//
//  WorldCup2026PicksStore.swift
//  Best Man Challenge
//
//  Manages player picks (4 ranked slots per group) and tournament lock state.
//
//  Firestore layout:
//    brackets/world_cup_2026                             ← tournament meta (status, locksAt, isLocked)
//    brackets/world_cup_2026/teams/{teamId}              ← team docs
//    brackets/world_cup_2026/picks/all/players/{docId}   ← player picks
//    brackets/world_cup_2026/picks/all/admins/{docId}    ← admin picks

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class WorldCup2026PicksStore: ObservableObject {

    let bracketId: String

    // MARK: - Published state

    @Published private(set) var teams: [WCTeam] = []
    @Published private(set) var teamsByGroup: [WCGroup: [WCTeam]] = [:]

    @Published private(set) var allEntries: [WCEntry] = []
    @Published private(set) var myEntry: WCEntry?

    @Published private(set) var tournamentStatus: WCTournamentStatus = .open
    @Published private(set) var isLocked: Bool = false
    @Published private(set) var locksAt: Date? = nil

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Private

    private let db = Firestore.firestore()
    private var metaListener: ListenerRegistration?
    private var teamsListener: ListenerRegistration?
    private var picksListener: ListenerRegistration?

    private var lane: String = "players"
    private var myLinkedPlayerId: String?
    private var myUid: String?
    private var myDisplayName: String?
    private var myRole: String?
    private var didStart = false

    init(bracketId: String = "world_cup_2026") {
        self.bracketId = bracketId
    }

    deinit {
        metaListener?.remove()
        teamsListener?.remove()
        picksListener?.remove()
    }

    // MARK: - Start / Stop

    func startListening(linkedPlayerId: String?, uid: String?, displayName: String?, role: String?) {
        self.myLinkedPlayerId = linkedPlayerId
        self.myUid = uid
        self.myDisplayName = displayName
        self.myRole = role

        let roleLower = (role ?? "").lowercased()
        let isExec = ["owner", "commish", "ref", "admin", "exec"].contains(roleLower)
        lane = (linkedPlayerId?.isEmpty == false) ? "players" : (isExec ? "admins" : "players")

        stopListening()
        errorMessage = nil
        isLoading = true
        didStart = true

        listenMeta()
        listenTeams()
        listenEntries()
    }

    func stopListening() {
        metaListener?.remove(); metaListener = nil
        teamsListener?.remove(); teamsListener = nil
        picksListener?.remove(); picksListener = nil
        isLoading = false
    }

    // MARK: - Listeners

    private func listenMeta() {
        metaListener?.remove()
        metaListener = db.collection("brackets")
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
                let statusRaw = d["status"] as? String ?? "open"
                let status = WCTournamentStatus(rawValue: statusRaw) ?? .open
                let lockedFlag = d["isLocked"] as? Bool
                let locksAt = (d["locksAt"] as? Timestamp)?.dateValue()

                Task { @MainActor in
                    self.tournamentStatus = status
                    self.locksAt = locksAt
                    if let lockedFlag {
                        self.isLocked = lockedFlag
                    } else {
                        self.isLocked = (status == .locked || status == .finalized)
                    }
                }
            }
    }

    private func listenTeams() {
        teamsListener?.remove()
        teamsListener = db.collection("brackets")
            .document(bracketId)
            .collection("teams")
            .order(by: "sortOrder")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in self.errorMessage = err.localizedDescription }
                    return
                }
                let docs = snap?.documents ?? []
                let decoded: [WCTeam] = docs.compactMap { doc in
                    let d = doc.data()
                    let name = d["name"] as? String ?? doc.documentID
                    let abbr = d["abbr"] as? String ?? doc.documentID
                    let groupRaw = (d["group"] as? String ?? "").uppercased()
                    guard let group = WCGroup(rawValue: groupRaw) else { return nil }
                    return WCTeam(
                        id: doc.documentID,
                        name: name,
                        abbr: abbr,
                        group: group,
                        flag: d["flag"] as? String,
                        sortOrder: d["sortOrder"] as? Int ?? 0
                    )
                }
                let byGroup = Dictionary(grouping: decoded, by: { $0.group })
                    .mapValues { $0.sorted { $0.sortOrder < $1.sortOrder } }

                Task { @MainActor in
                    self.teams = decoded
                    self.teamsByGroup = byGroup
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
            let myDocId: String? = self.resolveMyDocId()

            var rows: [WCEntry] = []
            var mine: WCEntry? = nil

            for doc in docs {
                let d = doc.data()
                let entry = Self.decodeEntry(docId: doc.documentID, data: d)
                rows.append(entry)
                if let myDocId, doc.documentID == myDocId { mine = entry }
            }

            rows.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            Task { @MainActor in
                self.allEntries = rows
                self.myEntry = mine
                self.isLoading = false
            }
        }
    }

    // MARK: - Helpers

    private func resolveMyDocId() -> String? {
        if lane == "players" {
            return myLinkedPlayerId?.isEmpty == false ? myLinkedPlayerId : myUid
        } else {
            return myUid?.isEmpty == false ? myUid : myLinkedPlayerId
        }
    }

    static func decodeEntry(docId: String, data: [String: Any]) -> WCEntry {
        let displayName = data["displayName"] as? String ?? docId
        let linkedPlayerId = data["linkedPlayerId"] as? String ?? docId
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
        let groupPicks = data["groupPicks"] as? [String: [String: String]] ?? [:]
        let knockoutPicks = data["knockoutPicks"] as? [String: String] ?? [:]
        return WCEntry(
            id: docId,
            linkedPlayerId: linkedPlayerId,
            displayName: displayName,
            updatedAt: updatedAt,
            groupPicks: groupPicks,
            knockoutPicks: knockoutPicks
        )
    }

    func teamName(_ teamId: String?) -> String {
        guard let teamId, !teamId.isEmpty else { return "TBD" }
        return teams.first(where: { $0.id == teamId })?.abbr ?? teamId
    }

    func teamFlag(_ teamId: String?) -> String? {
        guard let teamId, !teamId.isEmpty else { return nil }
        return teams.first(where: { $0.id == teamId })?.flag
    }

    // MARK: - Write: Group Pick

    func clearGroupPick(group: WCGroup, slot: WCGroupSlot) async throws {
        guard !isLocked else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        guard let displayName = myDisplayName, !displayName.isEmpty else { return }

        let docId = resolveMyDocId() ?? uid
        let linkedId = myLinkedPlayerId?.isEmpty == false ? myLinkedPlayerId! : uid

        let ref = db.collection("brackets")
            .document(bracketId)
            .collection("picks")
            .document("all")
            .collection(lane)
            .document(docId)

        // Write empty string — scored as "no pick" (0 pts for that slot)
        try await ref.setData([
            "displayName": displayName,
            "linkedPlayerId": linkedId,
            "updatedAt": Timestamp(date: Date()),
            "groupPicks": [
                group.rawValue: [
                    slot.rawValue: ""
                ]
            ]
        ], merge: true)
    }

    func setGroupPick(
        group: WCGroup,
        slot: WCGroupSlot,
        teamId: String
    ) async throws {
        guard !isLocked else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        guard let displayName = myDisplayName, !displayName.isEmpty else { return }

        let docId = resolveMyDocId() ?? uid
        let laneToUse = lane
        let linkedId = myLinkedPlayerId?.isEmpty == false ? myLinkedPlayerId! : uid

        let ref = db.collection("brackets")
            .document(bracketId)
            .collection("picks")
            .document("all")
            .collection(laneToUse)
            .document(docId)

        try await ref.setData([
            "displayName": displayName,
            "linkedPlayerId": linkedId,
            "updatedAt": Timestamp(date: Date()),
            "groupPicks": [
                group.rawValue: [
                    slot.rawValue: teamId
                ]
            ]
        ], merge: true)
    }

    // MARK: - Write: Knockout Pick

    /// Records a player's winner pick for one knockout match.
    /// Pass teamId = "" to clear the pick.
    func setKnockoutPick(matchId: String, teamId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        guard let displayName = myDisplayName, !displayName.isEmpty else { return }

        let docId = resolveMyDocId() ?? uid
        let linkedId = myLinkedPlayerId?.isEmpty == false ? myLinkedPlayerId! : uid

        let ref = db.collection("brackets")
            .document(bracketId)
            .collection("picks")
            .document("all")
            .collection(lane)
            .document(docId)

        try await ref.setData([
            "displayName":    displayName,
            "linkedPlayerId": linkedId,
            "updatedAt":      Timestamp(date: Date()),
            "knockoutPicks":  [matchId: teamId]
        ], merge: true)
    }

    // MARK: - Completion check

    /// Returns how many group slots have been filled (max 48).
    func filledSlotsCount(entry: WCEntry?) -> Int {
        guard let entry else { return 0 }
        var count = 0
        for g in WCGroup.allCases {
            let picks = entry.groupPicks[g.rawValue] ?? [:]
            for slot in WCGroupSlot.allCases {
                if let v = picks[slot.rawValue], !v.isEmpty { count += 1 }
            }
        }
        return count
    }
}
