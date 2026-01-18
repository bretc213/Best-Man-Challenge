import Foundation
import FirebaseFirestore

@MainActor
final class WeeklyStandingsStore: ObservableObject {
    @Published var playersRows: [WeeklyScoreRow] = []
    @Published var adminsRows: [WeeklyScoreRow] = []

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening(activeChallengeId: String) {
        stopListening()

        isLoading = true
        errorMessage = nil
        playersRows = []
        adminsRows = []

        listener = db.collection("weekly_challenges")
            .document(activeChallengeId)
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

                for doc in docs {
                    let d = doc.data()

                    let id = doc.documentID

                    let displayName =
                        (d["display_name"] as? String)
                        ?? (d["displayName"] as? String)
                        ?? id

                    let submittedAt =
                        (d["submittedAt"] as? Timestamp)?.dateValue()
                        ?? (d["submitted_at"] as? Timestamp)?.dateValue()

                    let score =
                        (d["score"] as? Int)
                        ?? 0

                    let maxScore =
                        (d["maxScore"] as? Int)
                        ?? (d["max_score"] as? Int)

                    // ✅ NEW: parse answers (quiz submissions)
                    let answers = d["answers"] as? [String: Int]

                    let row = WeeklyScoreRow(
                        id: id,
                        displayName: displayName,
                        score: score,
                        maxScore: maxScore,
                        answers: answers,
                        submittedAt: submittedAt
                    )

                    // ✅ Split admins vs players by doc id prefix
                    // (admins write to admin_<uid>)
                    if id.lowercased().hasPrefix("admin_") {
                        admins.append(row)
                    } else {
                        players.append(row)
                    }
                }

                // Sort: highest score first, then name
                players.sort {
                    if $0.score != $1.score { return $0.score > $1.score }
                    return $0.displayName < $1.displayName
                }
                admins.sort {
                    if $0.score != $1.score { return $0.score > $1.score }
                    return $0.displayName < $1.displayName
                }

                Task { @MainActor in
                    self.playersRows = players
                    self.adminsRows = admins
                    self.isLoading = false
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
