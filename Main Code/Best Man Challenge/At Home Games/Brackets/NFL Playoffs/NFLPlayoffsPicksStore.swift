//
//  NFLPlayoffsPicksStore.swift
//  Best Man Challenge
//
//  Supports:
//  - init(bracketId:roundId:) used by NFLPlayoffsRootView
//  - startListening(linkedPlayerId:uid:displayName:role:) used by RootView
//  - setRound(_:) used by Root + Admin
//  - matchups + allPlayersPicks + myPicks (existing)
//  - myChamps + setChamp/clearChamp (NEW - v2 feature)
//  - setPick(...) used by NFLThisWeekPicksView
//

import Foundation
import FirebaseFirestore

@MainActor
final class NFLPlayoffsPicksStore: ObservableObject {

    // MARK: - Public

    let bracketId: String

    /// "players" or "admins"
    @Published private(set) var lane: String = "players"

    /// Bindable round id ("wildcard", "divisional", "conference", "superBowl")
    @Published var roundId: String

    // MARK: - Published data

    @Published var matchups: [BracketMatchup] = []
    @Published var allPlayersPicks: [RoundPicksDoc] = []
    @Published var myPicks: [String: String] = [:]

    /// champs keys: "afc", "nfc", "superBowl"
    @Published var myChamps: [String: String] = [:]

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Internals

    private let db = Firestore.firestore()

    private var matchupsListener: ListenerRegistration?
    private var picksListener: ListenerRegistration?

    // Cached identity (so setRound can restart cleanly)
    private var myLinkedPlayerId: String?
    private var myUid: String?
    private var myDisplayName: String?
    private var myRole: String?

    // MARK: - Init (matches your RootView)

    init(bracketId: String = "nfl_2026_playoffs", roundId: String) {
        self.bracketId = bracketId
        self.roundId = roundId
    }

    /// Convenience
    convenience init(bracketId: String = "nfl_2026_playoffs", round: BracketRound = .wildcard) {
        self.init(bracketId: bracketId, roundId: round.rawValue)
    }

    // IMPORTANT: no async work in deinit
    deinit {
        matchupsListener?.remove()
        picksListener?.remove()
        matchupsListener = nil
        picksListener = nil
    }

    // MARK: - Round switching

    func setRound(_ newRoundId: String) {
        guard newRoundId != roundId else { return }
        roundId = newRoundId

        // restart with cached identity
        startListening(
            linkedPlayerId: myLinkedPlayerId,
            uid: myUid,
            displayName: myDisplayName,
            role: myRole
        )
    }

    func setRound(_ newRound: BracketRound) {
        setRound(newRound.rawValue)
    }

    // MARK: - Listening entrypoints

    /// Used by some child views
    func startListening(myLinkedPlayerId: String?) {
        startListening(linkedPlayerId: myLinkedPlayerId, uid: nil, displayName: nil, role: nil)
    }

    /// Used by NFLPlayoffsRootView
    func startListening(linkedPlayerId: String?, uid: String?, displayName: String?, role: String?) {
        // cache
        self.myLinkedPlayerId = linkedPlayerId
        self.myUid = uid
        self.myDisplayName = displayName
        self.myRole = role

        // determine lane
        let roleLower = (role ?? "").lowercased()
        let isExec = (roleLower == "owner" || roleLower == "commish" || roleLower == "ref" || roleLower == "admin")

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

        listenMatchupsForRound()
        listenPicksForRound()
    }

    func stopListening() {
        matchupsListener?.remove()
        matchupsListener = nil

        picksListener?.remove()
        picksListener = nil

        isLoading = false
    }

    // MARK: - Matchups

    private func listenMatchupsForRound() {
        matchupsListener?.remove()

        matchupsListener = db.collection("brackets")
            .document(bracketId)
            .collection("matchups")
            .whereField("round", isEqualTo: roundId)
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
                let decoded = docs.compactMap { doc in
                    self.decodeMatchup(id: doc.documentID, data: doc.data())
                }
                .sorted {
                    if $0.index != $1.index { return $0.index < $1.index }
                    return $0.startsAt < $1.startsAt
                }

                Task { @MainActor in
                    self.matchups = decoded
                    self.isLoading = false
                }
            }
    }

    private func decodeMatchup(id: String, data: [String: Any]) -> BracketMatchup? {
        guard
            let roundRaw = data["round"] as? String,
            let round = BracketRound(rawValue: roundRaw)
        else { return nil }

        let index = data["index"] as? Int ?? 0

        let startsAt = (data["startsAt"] as? Timestamp)?.dateValue() ?? Date.distantFuture
        let lockAt = (data["lockAt"] as? Timestamp)?.dateValue() ?? startsAt
        let revealAt = (data["revealAt"] as? Timestamp)?.dateValue() ?? lockAt

        let tv = data["tv"] as? String

        let winnerTeamIdRaw =
            (data["winnerTeamId"] as? String) ??
            (data["winnerTeamID"] as? String) ??
            (data["winnerId"] as? String) ??
            ""

        let winnerTeamId = winnerTeamIdRaw.isEmpty ? nil : winnerTeamIdRaw

        let decidedAt = (data["decidedAt"] as? Timestamp)?.dateValue()

        let awayMap = data["away"] as? [String: Any] ?? [:]
        let homeMap = data["home"] as? [String: Any] ?? [:]

        let away = MatchupTeam(
            id: awayMap["id"] as? String ?? "AWAY",
            name: awayMap["name"] as? String ?? (awayMap["id"] as? String ?? "Away"),
            logoAsset: awayMap["logoAsset"] as? String
        )

        let home = MatchupTeam(
            id: homeMap["id"] as? String ?? "HOME",
            name: homeMap["name"] as? String ?? (homeMap["id"] as? String ?? "Home"),
            logoAsset: homeMap["logoAsset"] as? String
        )

        return BracketMatchup(
            id: id,
            round: round,
            index: index,
            away: away,
            home: home,
            tv: tv,
            startsAt: startsAt,
            lockAt: lockAt,
            revealAt: revealAt,
            winnerTeamId: winnerTeamId,
            decidedAt: decidedAt
        )
    }

    // MARK: - Picks (read)

    private func listenPicksForRound() {
        picksListener?.remove()

        let ref = db.collection("brackets")
            .document(bracketId)
            .collection("picks")
            .document(roundId)
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

            // Which doc is "me"?
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

            var rows: [RoundPicksDoc] = []
            rows.reserveCapacity(docs.count)

            var champsForMe: [String: String] = [:]

            for doc in docs {
                let d = doc.data()

                let displayName = d["displayName"] as? String ?? doc.documentID
                let linkedPlayerId = d["linkedPlayerId"] as? String ?? doc.documentID
                let updatedAt = (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

                let picksAny = d["picks"] as? [String: Any] ?? [:]
                var picks: [String: String] = [:]
                picks.reserveCapacity(picksAny.count)
                for (k, v) in picksAny {
                    if let s = v as? String { picks[k] = s } else { picks[k] = "\(v)" }
                }

                // champs
                if let myDocId, doc.documentID == myDocId {
                    let champsAny = d["champs"] as? [String: Any] ?? [:]
                    var champs: [String: String] = [:]
                    champs.reserveCapacity(champsAny.count)
                    for (k, v) in champsAny {
                        if let s = v as? String { champs[k] = s } else { champs[k] = "\(v)" }
                    }
                    champsForMe = champs
                }

                rows.append(
                    RoundPicksDoc(
                        id: linkedPlayerId,
                        linkedPlayerId: linkedPlayerId,
                        displayName: displayName,
                        updatedAt: updatedAt,
                        picks: picks
                    )
                )
            }

            rows.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            Task { @MainActor in
                self.allPlayersPicks = rows
                self.recomputeMyPicks()
                self.myChamps = champsForMe
                self.isLoading = false
            }
        }
    }

    private func recomputeMyPicks() {
        if lane == "players", let myId = myLinkedPlayerId, !myId.isEmpty {
            myPicks = allPlayersPicks.first(where: { $0.linkedPlayerId == myId })?.picks ?? [:]
            return
        }

        if lane == "admins", let uid = myUid, !uid.isEmpty {
            // admins docID likely equals uid; linkedPlayerId may also be uid
            myPicks = allPlayersPicks.first(where: { $0.id == uid || $0.linkedPlayerId == uid })?.picks ?? [:]
            return
        }

        myPicks = [:]
    }

    // MARK: - Picks (write) used by NFLThisWeekPicksView

    func setPick(
        uid: String,
        displayName: String,
        role: String,
        linkedPlayerId: String?,
        matchup: BracketMatchup,
        teamId: String
    ) async throws {

        let roleLower = role.lowercased()
        let isExec = (roleLower == "owner" || roleLower == "commish" || roleLower == "ref" || roleLower == "admin")

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

        let ref = db.collection("brackets")
            .document(bracketId)
            .collection("picks")
            .document(roundId)
            .collection(laneToUse)
            .document(docId)

        try await ref.setData([
            "linkedPlayerId": linkedIdToWrite,
            "displayName": displayName,
            "updatedAt": Timestamp(date: Date()),
            "picks": [
                matchup.id: teamId
            ]
        ], merge: true)
    }

    // MARK: - Champs (write) NEW (v2)

    func setChamp(
        uid: String,
        displayName: String,
        role: String,
        linkedPlayerId: String?,
        key: String,     // "afc", "nfc", "superBowl"
        teamId: String
    ) async throws {

        let roleLower = role.lowercased()
        let isExec = (roleLower == "owner" || roleLower == "commish" || roleLower == "ref" || roleLower == "admin")

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

        let ref = db.collection("brackets")
            .document(bracketId)
            .collection("picks")
            .document(roundId)
            .collection(laneToUse)
            .document(docId)

        try await ref.setData([
            "linkedPlayerId": linkedIdToWrite,
            "displayName": displayName,
            "updatedAt": Timestamp(date: Date()),
            "champs": [
                key: teamId
            ]
        ], merge: true)
    }

    func clearChamp(
        uid: String,
        role: String,
        linkedPlayerId: String?,
        key: String
    ) async throws {

        let roleLower = role.lowercased()
        let isExec = (roleLower == "owner" || roleLower == "commish" || roleLower == "ref" || roleLower == "admin")

        let laneToUse: String
        let docId: String

        if let linkedPlayerId, !linkedPlayerId.isEmpty {
            laneToUse = "players"
            docId = linkedPlayerId
        } else if isExec {
            laneToUse = "admins"
            docId = uid
        } else {
            laneToUse = "players"
            docId = uid
        }

        let ref = db.collection("brackets")
            .document(bracketId)
            .collection("picks")
            .document(roundId)
            .collection(laneToUse)
            .document(docId)

        try await ref.setData([
            "updatedAt": Timestamp(date: Date()),
            "champs": [
                key: FieldValue.delete()
            ]
        ], merge: true)
    }
}
