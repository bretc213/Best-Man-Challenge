//
//  SoftballBracketStore.swift
//  Best Man Challenge
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class SoftballBracketStore: ObservableObject {
    @Published var config: SoftballBracketConfig = .default2026
    @Published var myPicks: SoftballBracketPicks?
    @Published var allPicks: [SoftballBracketPicks] = []
    @Published var results: SoftballBracketResults = .empty
    @Published var isLoading = false
    @Published var errorMessage: String?

    let challengeId: String

    private let db = Firestore.firestore()
    private var configListener: ListenerRegistration?
    private var myPicksListener: ListenerRegistration?
    private var allPicksListener: ListenerRegistration?

    init(challengeId: String = SoftballBracketConfig.challengeId) {
        self.challengeId = challengeId
    }

    deinit {
        configListener?.remove()
        myPicksListener?.remove()
        allPicksListener?.remove()
    }

    var bracketRef: DocumentReference {
        db.collection("softball_brackets").document(challengeId)
    }

    var isLocked: Bool {
        let status = config.status.lowercased()
        if status == "locked" || status == "finalized" { return true }
        guard let locksAt = config.locksAt else { return false }
        return locksAt.dateValue() <= Date()
    }

    func start(session: SessionStore) {
        listenToConfig()
        listenToAllPicks()
        listenToMyPicks(session: session)
    }

    func listenToConfig() {
        configListener?.remove()

        configListener = bracketRef.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let snapshot, snapshot.exists else {
                    self.errorMessage = "Missing Firestore document: softball_brackets/\(self.challengeId). Run the WCWS seeder."
                    return
                }

                do {
                    self.config = try snapshot.data(as: SoftballBracketConfig.self)

                    if let data = snapshot.data(),
                       let resultsData = data["results"] as? [String: Any] {
                        self.results = SoftballBracketStore.decodeResults(from: resultsData)
                    } else {
                        self.results = .empty
                    }

                    self.errorMessage = nil
                } catch {
                    self.errorMessage = "Could not decode softball config: \(error.localizedDescription)"
                }
            }
        }
    }

    func listenToMyPicks(session: SessionStore) {
        myPicksListener?.remove()

        let submitterId = Self.submitterId(session: session)
        let displayName = Self.displayName(session: session)

        myPicksListener = bracketRef
            .collection("picks")
            .document(submitterId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    guard let snapshot, snapshot.exists else {
                        self.myPicks = .empty(submitterId: submitterId, displayName: displayName)
                        return
                    }

                    do {
                        self.myPicks = try snapshot.data(as: SoftballBracketPicks.self)
                    } catch {
                        self.errorMessage = "Could not decode picks: \(error.localizedDescription)"
                    }
                }
            }
    }

    func listenToAllPicks() {
        allPicksListener?.remove()

        allPicksListener = bracketRef.collection("picks").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                self.allPicks = snapshot?.documents.compactMap { document in
                    try? document.data(as: SoftballBracketPicks.self)
                } ?? []
            }
        }
    }

    func savePicks(_ picks: SoftballBracketPicks) async throws {
        guard !isLocked else {
            throw NSError(domain: "SoftballBracket", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bracket is locked."])
        }

        var updated = picks
        if updated.submittedAt == nil {
            updated.submittedAt = Timestamp(date: Date())
        }
        updated.updatedAt = Timestamp(date: Date())

        try bracketRef
            .collection("picks")
            .document(updated.submitterId)
            .setData(from: updated, merge: true)
    }

    func saveResults(_ newResults: SoftballBracketResults) async throws {
        var updatedResults = newResults
        if updatedResults.champion != nil && updatedResults.finalizedAt == nil {
            updatedResults.finalizedAt = Timestamp(date: Date())
        }

        let shouldFinalize = updatedResults.champion != nil
        let data: [String: Any] = [
            "results": Self.encodeResults(updatedResults),
            "status": shouldFinalize ? "finalized" : config.status,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await bracketRef.setData(data, merge: true)
    }

    func updateStatus(_ status: String) async throws {
        try await bracketRef.setData([
            "status": status,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func leaderboardRows() -> [SoftballLeaderboardRow] {
        allPicks
            .map { scoreRow(for: $0) }
            .sorted {
                if $0.total == $1.total { return $0.displayName < $1.displayName }
                return $0.total > $1.total
            }
    }

    func scoreRow(for picks: SoftballBracketPicks) -> SoftballLeaderboardRow {
        var regionalPoints = 0
        var superPoints = 0
        var finalistPoints = 0
        var championPoints = 0
        var maxRemaining = 0

        for regional in config.regionals {
            let official = results.regionalWinners[regional.id]
            let pick = picks.regionalWinners[regional.id]

            if let official {
                if pick == official { regionalPoints += config.regionalPoints }
            } else if pick != nil {
                maxRemaining += config.regionalPoints
            }
        }

        for pair in SoftballBracketConfig.superRegionalPairings {
            let id = SoftballBracketHelpers.superRegionalId(seedA: pair.0, seedB: pair.1)
            let official = results.superRegionalWinners[id]
            let pick = picks.superRegionalWinners[id]

            if let official {
                if pick == official { superPoints += config.superRegionalPoints }
            } else if pick != nil {
                maxRemaining += config.superRegionalPoints
            }
        }

        if results.finalists.count == 2 {
            for pickedFinalist in picks.finalists {
                if results.finalists.contains(pickedFinalist) {
                    finalistPoints += config.finalistPoints
                }
            }
        } else {
            maxRemaining += picks.finalists.count * config.finalistPoints
        }

        if let officialChampion = results.champion {
            if picks.champion == officialChampion {
                championPoints += config.championPoints
            }
        } else if picks.champion != nil {
            maxRemaining += config.championPoints
        }

        let total = regionalPoints + superPoints + finalistPoints + championPoints

        return SoftballLeaderboardRow(
            submitterId: picks.submitterId,
            displayName: picks.displayName,
            regionalPoints: regionalPoints,
            superRegionalPoints: superPoints,
            finalistPoints: finalistPoints,
            championPoints: championPoints,
            total: total,
            maxRemaining: total + maxRemaining
        )
    }

    static func submitterId(session: SessionStore) -> String {
        if let linkedPlayerId = session.linkedPlayerId,
           !linkedPlayerId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return linkedPlayerId
        }

        if let uid = Auth.auth().currentUser?.uid {
            return "admin_\(uid)"
        }

        return session.accountId
    }

    static func displayName(session: SessionStore) -> String {
        let name = session.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty && name != "Unknown" { return name }
        return Auth.auth().currentUser?.email ?? "Unknown"
    }

    static func encodeResults(_ results: SoftballBracketResults) -> [String: Any] {
        var data: [String: Any] = [
            "regionalWinners": results.regionalWinners,
            "superRegionalWinners": results.superRegionalWinners,
            "finalists": results.finalists
        ]

        if let champion = results.champion {
            data["champion"] = champion
        }

        if let finalizedAt = results.finalizedAt {
            data["finalizedAt"] = finalizedAt
        }

        return data
    }

    static func decodeResults(from data: [String: Any]) -> SoftballBracketResults {
        SoftballBracketResults(
            regionalWinners: data["regionalWinners"] as? [String: String] ?? [:],
            superRegionalWinners: data["superRegionalWinners"] as? [String: String] ?? [:],
            finalists: data["finalists"] as? [String] ?? [],
            champion: data["champion"] as? String,
            finalizedAt: data["finalizedAt"] as? Timestamp
        )
    }
}
