import Foundation
import FirebaseFirestore

// ✅ Backwards compatibility with any old views still referencing the old store name
typealias WeeklyChallengeStandingsStore = WeeklyStandingsStore

@MainActor
final class WeeklyStandingsStore: ObservableObject {

    @Published var playersRows: [WeeklyScoreRow] = []
    @Published var adminsRows: [WeeklyScoreRow] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var submissionsListener: ListenerRegistration?

    // (We still load this, but we are NOT using role for bucketing anymore.)
    private var roleByUID: [String: String] = [:]

    deinit {
        submissionsListener?.remove()
    }

    func stopListening() {
        submissionsListener?.remove()
        submissionsListener = nil
    }

    func startListening(activeChallengeId: String) {
        stopListening()

        isLoading = true
        errorMessage = nil
        playersRows = []
        adminsRows = []

        Task {
            await loadAccountsIndex()
            listenToSubmissions(challengeId: activeChallengeId)
        }
    }

    private func loadAccountsIndex() async {
        do {
            let snap = try await db.collection("accounts").getDocuments()
            var map: [String: String] = [:]
            for doc in snap.documents {
                let data = doc.data()
                let uid = (data["claimed_by_uid"] as? String) ?? ""
                let role = (data["role"] as? String ?? "").lowercased()
                if !uid.isEmpty { map[uid] = role }
            }
            roleByUID = map
        } catch {
            roleByUID = [:]
        }
    }

    private func listenToSubmissions(challengeId: String) {
        submissionsListener = db.collection("weekly_challenges")
            .document(challengeId)
            .collection("submissions")
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

                var players: [WeeklyScoreRow] = []
                var admins: [WeeklyScoreRow] = []

                for d in docs {
                    let data = d.data()

                    let score = data["score"] as? Int ?? 0
                    let maxScore = (data["maxScore"] as? Int) ?? (data["max_score"] as? Int)

                    let dn =
                        (data["display_name"] as? String)
                        ?? (data["displayName"] as? String)
                        ?? "Unknown"

                    let rawLP = data["linked_player_id"] as? String
                    let uid = (data["uid"] as? String) ?? d.documentID

                    let submittedAt =
                        (data["submittedAt"] as? Timestamp)?.dateValue()
                        ?? (data["submitted_at"] as? Timestamp)?.dateValue()

                    let row = WeeklyScoreRow(
                        id: uid,
                        displayName: dn,
                        linkedPlayerId: rawLP,
                        score: score,
                        maxScore: maxScore,
                        submittedAt: submittedAt
                    )

                    // ✅ Bucket rule for weekly leaderboards:
                    // If linked_player_id exists -> treat as PLAYER (includes you even if role is owner)
                    let cleanedLP = (rawLP ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let isPlayerBucket = !cleanedLP.isEmpty

                    if isPlayerBucket {
                        players.append(row)
                    } else {
                        admins.append(row)
                    }
                }

                func sortRows(_ rows: [WeeklyScoreRow]) -> [WeeklyScoreRow] {
                    rows.sorted {
                        if $0.score != $1.score { return $0.score > $1.score }
                        return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                    }
                }

                Task { @MainActor in
                    self.playersRows = sortRows(players)
                    self.adminsRows = sortRows(admins)
                    self.isLoading = false
                    self.errorMessage = nil
                }
            }
    }
}
