import Foundation
import FirebaseFirestore

@MainActor
final class MLBFuturesStore: ObservableObject {
    @Published var meta: MLBFuturesMeta?
    @Published var picks: [MLBFuturesPicksDoc] = []
    @Published var adminState: MLBFuturesAdminState?
    @Published var leaderboard: [MLBFuturesLeaderboardRow] = []
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
            .collection("picks")
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

        listeners = [metaListener, picksListener, adminListener]
        isLoading = false
    }

    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    func submit(picks: MLBFuturesPicksDoc) async throws {
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
            .collection("picks")
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

    private func recomputeDerivedState() {
        summaryRows = MLBFuturesScoring.buildSummary(from: picks)
        leaderboard = adminState.map { MLBFuturesScoring.buildLeaderboard(picks: picks, state: $0) } ?? []
    }
}
