import Foundation
import FirebaseFirestore

@MainActor
final class MLBFuturesStore: ObservableObject {
    @Published var meta: MLBFuturesMeta?
    @Published var picks: [MLBFuturesPicksDoc] = []
    @Published var adminPicks: [MLBFuturesPicksDoc] = []
    @Published var adminState: MLBFuturesAdminState?
    @Published var leaderboard: [MLBFuturesLeaderboardRow] = []
    @Published var adminLeaderboard: [MLBFuturesLeaderboardRow] = []
    @Published var summaryRows: [MLBFuturesTeamSummary] = []
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    let challengeId: String

    init(challengeId: String = MLBFuturesConstants.challengeId) {
        self.challengeId = challengeId
    }

    deinit {
        listeners.forEach { $0.remove() }
    }

    var locksAtDate: Date? {
        meta?.locksAt?.dateValue()
    }

    var isLocked: Bool {
        if adminState?.isFinal == true { return true }
        if meta?.isLocked == true { return true }
        if let locksAtDate {
            return Date() >= locksAtDate
        }
        return false
    }

    var allPicksAreVisible: Bool {
        isLocked
    }

    func existingPick(for userId: String, on board: MLBFuturesPickBoard = .publicBoard) -> MLBFuturesPicksDoc? {
        switch board {
        case .publicBoard:
            return picks.first { $0.userId == userId }
        case .adminBoard:
            return adminPicks.first { $0.userId == userId }
        }
    }

    func startListening() {
        stopListening()
        isLoading = true

        let metaListener = db.collection("at_home_games").document(challengeId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                do {
                    self.meta = try snapshot?.data(as: MLBFuturesMeta.self)
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }

        let picksListener = db.collection("at_home_games").document(challengeId)
            .collection(MLBFuturesConstants.publicPicksCollection)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                do {
                    self.picks = try snapshot?.documents.compactMap { try $0.data(as: MLBFuturesPicksDoc.self) } ?? []
                    self.recomputeDerivedState()
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }

        let adminPicksListener = db.collection("at_home_games").document(challengeId)
            .collection(MLBFuturesConstants.adminPicksCollection)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                do {
                    self.adminPicks = try snapshot?.documents.compactMap { try $0.data(as: MLBFuturesPicksDoc.self) } ?? []
                    self.recomputeDerivedState()
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }

        let adminListener = db.collection("at_home_games").document(challengeId)
            .collection("admin").document("current_state")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                do {
                    self.adminState = try snapshot?.data(as: MLBFuturesAdminState.self)
                    self.recomputeDerivedState()
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }

        listeners = [metaListener, picksListener, adminPicksListener, adminListener]
        isLoading = false
    }

    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    func submit(picks: MLBFuturesPicksDoc, on board: MLBFuturesPickBoard = .publicBoard) async throws {
        if isLocked {
            throw NSError(
                domain: "MLBFuturesLocked",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "\(board.lockedMessagePrefix) are locked for this event."]
            )
        }

        let errors = MLBFuturesScoring.validate(picks: picks)
        guard errors.isEmpty else {
            throw NSError(
                domain: "MLBFuturesValidation",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: errors.joined(separator: "\n")]
            )
        }

        try db.collection("at_home_games")
            .document(challengeId)
            .collection(board.picksCollectionName)
            .document(picks.userId)
            .setData(from: picks, merge: true)
    }

    func saveAdminState(_ state: MLBFuturesAdminState) async throws {
        try db.collection("at_home_games")
            .document(challengeId)
            .collection("admin")
            .document("current_state")
            .setData(from: state, merge: true)
    }

    func saveFinalizedResults(finalizedBy: String?) async throws {
        let rows = leaderboard
        let payload: [[String: Any]] = rows.enumerated().map { index, row in
            [
                "rank": index + 1,
                "userId": row.userId,
                "displayName": row.displayName,
                "totalPoints": row.totalPoints,
                "divisionPoints": row.divisionPoints,
                "seedingPoints": row.seedingPoints,
                "dsPoints": row.dsPoints,
                "csPoints": row.csPoints,
                "wsPoints": row.wsPoints,
                "championPoints": row.championPoints
            ]
        }

        try await db.collection("at_home_games")
            .document(challengeId)
            .collection("results")
            .document("final")
            .setData([
                "challengeId": challengeId,
                "finalizedAt": FieldValue.serverTimestamp(),
                "finalizedBy": finalizedBy as Any,
                "leaderboard": payload
            ], merge: true)
    }

    private func recomputeDerivedState() {
        summaryRows = MLBFuturesScoring.buildSummary(from: picks)
        leaderboard = adminState.map { MLBFuturesScoring.buildLeaderboard(picks: picks, state: $0) } ?? []
        adminLeaderboard = adminState.map { MLBFuturesScoring.buildLeaderboard(picks: adminPicks, state: $0) } ?? []
    }
}
