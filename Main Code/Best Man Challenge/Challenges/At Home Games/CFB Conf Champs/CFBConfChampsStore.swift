//
//  CFBConfChampsStore.swift
//  Best Man Challenge
//
//  Store for the CFB Conference Championships game.
//  Firestore layout:
//    cfb_conf_champs_2026/data/conferences/{confId}  – config + admin state
//    cfb_conf_champs_2026/data/picks/{playerId}     – player entries
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class CFBConfChampsStore: ObservableObject {

    // MARK: - Published

    @Published var conferences: [CFBConference] = []
    @Published var allEntries: [CFBConfChampsEntry] = []
    @Published var scoreRows: [CFBScoreRow] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    // My live picks (mirrors Firestore for my player)
    @Published var myPhase1: [String: CFBPhase1Pick] = [:]
    @Published var myPhase2: [String: String] = [:]

    // Finalize state
    @Published var isFinalized = false

    // MARK: - Private

    private let db = Firestore.firestore()
    private let challengeId = CFBData.challengeId

    private var confListener: ListenerRegistration?
    private var picksListener: ListenerRegistration?
    private var metaListener: ListenerRegistration?

    private var myLinkedPlayerId: String?
    private var myDisplayName: String?
    private var myRole: String?

    deinit {
        confListener?.remove()
        picksListener?.remove()
        metaListener?.remove()
    }

    // MARK: - Start

    func start(linkedPlayerId: String?, displayName: String?, role: String?) {
        myLinkedPlayerId = linkedPlayerId
        myDisplayName = displayName
        myRole = role

        isLoading = true
        errorMessage = nil

        listenConferences()
        listenPicks()
        listenMeta()
    }

    func stop() {
        confListener?.remove(); confListener = nil
        picksListener?.remove(); picksListener = nil
        metaListener?.remove(); metaListener = nil
        isLoading = false
    }

    // MARK: - Conferences

    private func listenConferences() {
        confListener?.remove()
        confListener = db.collection(challengeId).document("data").collection("conferences")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    self.errorMessage = err.localizedDescription
                    self.isLoading = false
                    return
                }
                let live = Dictionary(uniqueKeysWithValues:
                    (snap?.documents ?? []).map { ($0.documentID, $0.data()) })

                // Merge static defs with live admin state; fall back to static if no doc.
                self.conferences = CFBData.conferences.map { def in
                    let d = live[def.id] ?? [:]
                    let finalistIds = (d["finalistIds"] as? [String]) ?? []
                    let championId = (d["championId"] as? String)
                    let p1 = (d["phase1LockAt"] as? Timestamp)?.dateValue()
                    let p2 = (d["phase2LockAt"] as? Timestamp)?.dateValue()
                    return CFBConference(
                        id: def.id,
                        name: def.name,
                        tier: def.tier,
                        sortOrder: def.sortOrder,
                        teamIds: def.teamIds,
                        finalistIds: finalistIds,
                        championId: (championId?.isEmpty == true) ? nil : championId,
                        phase1LockAt: p1,
                        phase2LockAt: p2
                    )
                }.sorted { $0.sortOrder < $1.sortOrder }

                self.recomputeScores()
                self.isLoading = false
            }
    }

    // MARK: - Picks

    private func listenPicks() {
        picksListener?.remove()
        picksListener = db.collection(challengeId).document("data").collection("picks")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err { self.errorMessage = err.localizedDescription; return }

                self.allEntries = (snap?.documents ?? [])
                    .compactMap { self.decodeEntry($0) }
                    .sorted { $0.displayName < $1.displayName }

                let myId = self.myLinkedPlayerId ?? ""
                if let mine = self.allEntries.first(where: { $0.linkedPlayerId == myId }) {
                    self.myPhase1 = mine.phase1
                    self.myPhase2 = mine.phase2
                }
                self.recomputeScores()
            }
    }

    private func decodeEntry(_ doc: QueryDocumentSnapshot) -> CFBConfChampsEntry? {
        let d = doc.data()
        guard let displayName = d["displayName"] as? String else { return nil }
        let linkedPlayerId = (d["linkedPlayerId"] as? String) ?? doc.documentID
        let updatedAt = (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

        // phase1: { confId: { finalists: [a,b], champion: id } }
        var phase1: [String: CFBPhase1Pick] = [:]
        if let raw = d["phase1"] as? [String: Any] {
            for (confId, v) in raw {
                guard let m = v as? [String: Any] else { continue }
                let finalists = (m["finalists"] as? [String]) ?? []
                let champion = m["champion"] as? String
                phase1[confId] = CFBPhase1Pick(
                    finalistIds: finalists,
                    championId: (champion?.isEmpty == true) ? nil : champion
                )
            }
        }

        // phase2: { confId: winnerTeamId }
        var phase2: [String: String] = [:]
        if let raw = d["phase2"] as? [String: Any] {
            for (confId, v) in raw where v is String {
                phase2[confId] = v as? String
            }
        }

        return CFBConfChampsEntry(
            id: linkedPlayerId,
            linkedPlayerId: linkedPlayerId,
            displayName: displayName,
            updatedAt: updatedAt,
            phase1: phase1,
            phase2: phase2
        )
    }

    // MARK: - Meta (finalize flag)

    private func listenMeta() {
        metaListener?.remove()
        metaListener = db.collection(challengeId).document("meta")
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                self.isFinalized = (snap?.data()?["finalized"] as? Bool) ?? false
            }
    }

    // MARK: - Scoring (raw points)

    /// Recomputes each player's raw Phase 1 + Phase 2 points from graded conferences.
    private func recomputeScores() {
        guard !conferences.isEmpty else { scoreRows = []; return }

        var rows: [CFBScoreRow] = []

        for entry in allEntries {
            var p1 = 0.0
            var p2 = 0.0

            for conf in conferences {
                let tier = conf.tier

                // Phase 1 — finalists (graded once matchup is posted)
                if conf.matchupSet, let pick = entry.phase1[conf.id] {
                    for teamId in pick.finalistIds where conf.finalistIds.contains(teamId) {
                        p1 += tier.finalistPoints
                    }
                    // Phase 1 — champion bonus (graded once winner is set)
                    if let champ = conf.championId,
                       pick.championId == champ {
                        p1 += tier.championBonus
                    }
                }

                // Phase 2 — winner pick (graded once winner is set)
                if let champ = conf.championId,
                   let p2Pick = entry.phase2[conf.id],
                   p2Pick == champ {
                    p2 += tier.phase2Points
                }
            }

            rows.append(CFBScoreRow(
                id: entry.linkedPlayerId,
                linkedPlayerId: entry.linkedPlayerId,
                displayName: entry.displayName,
                phase1Points: p1,
                phase2Points: p2
            ))
        }

        scoreRows = rows.sorted {
            if $0.total != $1.total { return $0.total > $1.total }
            return $0.displayName < $1.displayName
        }
    }

    /// Convenience: my current raw total.
    var myScoreRow: CFBScoreRow? {
        scoreRows.first { $0.linkedPlayerId == (myLinkedPlayerId ?? "") }
    }

    // MARK: - Player: Phase 1 submission

    /// Saves a full Phase 1 prediction for one conference (2 finalists + champion).
    func setPhase1(confId: String, finalistIds: [String], championId: String?) async throws {
        guard let pid = myLinkedPlayerId, !pid.isEmpty else { throw CFBError.notLinked }
        guard let conf = conferences.first(where: { $0.id == confId }) else { throw CFBError.notFound }
        guard !conf.isPhase1Locked else { throw CFBError.phase1Locked }

        var confData: [String: Any] = ["finalists": finalistIds]
        if let championId {
            confData["champion"] = championId
        } else {
            confData["champion"] = NSNull()   // clears champion if none
        }

        let ref = picksDoc(pid)
        try await ref.setData([
            "linkedPlayerId": pid,
            "displayName": myDisplayName ?? "Unknown",
            "updatedAt": FieldValue.serverTimestamp(),
            "phase1": [confId: confData]
        ], merge: true)
    }

    // MARK: - Player: Phase 2 submission

    /// Saves a Phase 2 winner pick for one conference.
    func setPhase2(confId: String, winnerId: String) async throws {
        guard let pid = myLinkedPlayerId, !pid.isEmpty else { throw CFBError.notLinked }
        guard let conf = conferences.first(where: { $0.id == confId }) else { throw CFBError.notFound }
        guard conf.matchupSet else { throw CFBError.matchupNotSet }
        guard !conf.isPhase2Locked else { throw CFBError.phase2Locked }
        guard conf.finalistIds.contains(winnerId) else { throw CFBError.notAFinalist }

        let ref = picksDoc(pid)
        try await ref.setData([
            "linkedPlayerId": pid,
            "displayName": myDisplayName ?? "Unknown",
            "updatedAt": FieldValue.serverTimestamp(),
            "phase2": [confId: winnerId]
        ], merge: true)
    }

    private func picksDoc(_ pid: String) -> DocumentReference {
        db.collection(challengeId).document("data").collection("picks").document(pid)
    }

    // MARK: - Admin: set finalists / champion

    /// Posts the 2 finalists for a conference AND its Phase 2 lock (title-game kickoff).
    /// This launches Phase 2 for players and enables Phase 1 finalist grading.
    func adminSetFinalists(confId: String, finalistIds: [String], phase2Lock: Date) async throws {
        guard finalistIds.count == 2 else { throw CFBError.needTwoFinalists }
        let ref = db.collection(challengeId).document("data").collection("conferences").document(confId)
        try await ref.setData([
            "finalistIds": finalistIds,
            "phase2LockAt": Timestamp(date: phase2Lock),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    /// Sets the champion (winner) — completes Phase 1 champion bonus + Phase 2 grading.
    func adminSetChampion(confId: String, championId: String?) async throws {
        let ref = db.collection(challengeId).document("data").collection("conferences").document(confId)
        if let championId, !championId.isEmpty {
            try await ref.setData([
                "championId": championId,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } else {
            try await ref.updateData([
                "championId": FieldValue.delete(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
        }
    }

    /// Clears a conference's finalists + champion (admin correction).
    func adminClearConference(confId: String) async throws {
        let ref = db.collection(challengeId).document("data").collection("conferences").document(confId)
        try await ref.updateData([
            "finalistIds": FieldValue.delete(),
            "championId": FieldValue.delete(),
            "phase2LockAt": FieldValue.delete(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    // MARK: - Admin: Finalize & Award

    /// Converts raw scores → BMC points via the standard finalizer
    /// (golf-payout tie logic + owner +3), then marks the game finalized.
    func finalizeAndAward() async throws {
        var scores: [String: Double] = [:]
        for row in scoreRows {
            scores[row.linkedPlayerId] = row.total
        }
        guard !scores.isEmpty else { throw CFBError.noScores }

        let finalizer = ChallengePointsFinalizer()
        try await finalizer.finalizeChallenge(
            challengeId: challengeId,
            scoresByPlayer: scores,
            multiplier: 1.0,
            higherIsBetter: true
        )

        try await db.collection(challengeId).document("meta").setData([
            "finalized": true,
            "finalizedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    // MARK: - Role

    var isAdmin: Bool {
        ["owner", "commish", "ref", "admin", "exec"].contains((myRole ?? "").lowercased())
    }

    var isOwner: Bool { (myRole ?? "").lowercased() == "owner" }
}

// MARK: - Errors

enum CFBError: LocalizedError {
    case notLinked, notFound, phase1Locked, phase2Locked
    case matchupNotSet, notAFinalist, needTwoFinalists, noScores

    var errorDescription: String? {
        switch self {
        case .notLinked:       return "Your account isn't linked to a player yet."
        case .notFound:        return "Conference not found."
        case .phase1Locked:    return "Preseason picks are locked — the season has started."
        case .phase2Locked:    return "This title game has kicked off — pick is locked."
        case .matchupNotSet:   return "The matchup for this conference hasn't been posted yet."
        case .notAFinalist:    return "That team isn't in this title game."
        case .needTwoFinalists:return "Pick exactly two finalists."
        case .noScores:        return "No scores to finalize yet."
        }
    }
}
