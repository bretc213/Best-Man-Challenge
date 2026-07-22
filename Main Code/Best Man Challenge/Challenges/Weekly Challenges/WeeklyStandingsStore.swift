import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class WeeklyStandingsStore: ObservableObject {
    @Published var playersRows: [WeeklyScoreRow] = []
    @Published var adminsRows: [WeeklyScoreRow] = []

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // Resolves a display name for any id we might encounter on a submission:
    // Firebase uid, linked player id, or the submission doc id. Populated from
    // the `users` and `players` collections so a submission that was saved
    // without a display_name still shows a real name instead of a raw UID.
    private var nameById: [String: String] = [:]
    private var latestDocs: [QueryDocumentSnapshot] = []

    func startListening(activeChallengeId: String) {
        stopListening()

        isLoading = true
        errorMessage = nil
        playersRows = []
        adminsRows = []
        nameById = [:]
        latestDocs = []

        print("DIAG: WeeklyStandingsStore.startListening(activeChallengeId: \(activeChallengeId))")

        // Load the name lookup map first (async, one-shot), then rebuild.
        Task { await loadNameMap() }

        listener = db.collection("weekly_challenges")
            .document(activeChallengeId)
            .collection("submissions")
            .addSnapshotListener { [weak self] snap, err in
                Task { @MainActor in
                    guard let self = self else { return }
                    defer { self.isLoading = false }

                    if let err {
                        self.errorMessage = err.localizedDescription
                        print("DIAG: snapshot error: \(err.localizedDescription)")
                        return
                    }

                    self.latestDocs = snap?.documents ?? []
                    print("DIAG: snapshot docs=\(self.latestDocs.count) (challenge=\(activeChallengeId))")
                    self.rebuild()
                }
            }
    }

    // MARK: - Name lookup

    /// Builds uid/playerId -> display name from the `players` and `users`
    /// collections. Called once per startListening.
    private func loadNameMap() async {
        var map: [String: String] = [:]

        // players/{playerId} -> display_name
        if let pSnap = try? await db.collection("players").getDocuments() {
            for doc in pSnap.documents {
                let d = doc.data()
                if let name = cleaned(d["display_name"] as? String) ?? cleaned(d["name"] as? String) {
                    map[doc.documentID] = name
                }
            }
        }

        // users/{uid} -> display_name, and mirror onto the linked player id.
        // (May be blocked by security rules for a non-admin; that's fine — the
        // current-user fallback below still guarantees the viewer's own row.)
        if let uSnap = try? await db.collection("users").getDocuments() {
            for doc in uSnap.documents {
                let d = doc.data()
                guard let name = cleaned(d["display_name"] as? String) else { continue }
                map[doc.documentID] = name
                if let linked = cleaned(d["linked_player_id"] as? String), map[linked] == nil {
                    map[linked] = name
                }
            }
        }

        // Always resolvable: the signed-in user's own profile. Guarantees the
        // viewer never sees their own UID even if the users list read is denied.
        if let uid = Auth.auth().currentUser?.uid,
           let snap = try? await db.collection("users").document(uid).getDocument(),
           let d = snap.data() {
            if let name = cleaned(d["display_name"] as? String) {
                map[uid] = name
                if let linked = cleaned(d["linked_player_id"] as? String), map[linked] == nil {
                    map[linked] = name
                }
            }
        }

        self.nameById = map
        print("DIAG: name map loaded, \(map.count) entries")
        self.rebuild()
    }

    private func cleaned(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }

    // MARK: - Build rows

    /// Recomputes rows from the latest submissions snapshot + current name map.
    /// Safe to call whenever either input changes.
    private func rebuild() {
        // Dedupe: userId -> [docs]
        var byUser: [String: [QueryDocumentSnapshot]] = [:]
        for doc in latestDocs {
            let data = doc.data()
            let userId = (data["user_id"] as? String)
                ?? (data["uid"] as? String)
                ?? (data["playerId"] as? String)
                ?? doc.documentID
            byUser[userId, default: []].append(doc)
        }

        var playersAcc: [WeeklyScoreRow] = []
        var adminsAcc: [WeeklyScoreRow] = []

        for (_, docsForUser) in byUser {
            // Choose the latest doc; fallback to first
            let chosenDoc: QueryDocumentSnapshot
            if docsForUser.count == 1 {
                chosenDoc = docsForUser[0]
            } else {
                chosenDoc = docsForUser.max(by: { a, b in
                    let aData = a.data()
                    let bData = b.data()
                    let aTs = (aData["submittedAt"] as? Timestamp)?.dateValue()
                        ?? (aData["submitted_at"] as? Timestamp)?.dateValue()
                        ?? (aData["updatedAt"] as? Timestamp)?.dateValue()
                        ?? (aData["updated_at"] as? Timestamp)?.dateValue()
                    let bTs = (bData["submittedAt"] as? Timestamp)?.dateValue()
                        ?? (bData["submitted_at"] as? Timestamp)?.dateValue()
                        ?? (bData["updatedAt"] as? Timestamp)?.dateValue()
                        ?? (bData["updated_at"] as? Timestamp)?.dateValue()
                    switch (aTs, bTs) {
                    case (.some(let aDate), .some(let bDate)): return aDate < bDate
                    case (.some, .none): return false
                    case (.none, .some): return true
                    case (.none, .none): return a.documentID < b.documentID
                    }
                }) ?? docsForUser[0]
            }

            let d = chosenDoc.data()
            let docId = chosenDoc.documentID

            // Resolve a real display name. Prefer whatever was stored on the
            // submission; otherwise look the id up in the name map; only fall
            // back to a raw id as a last resort.
            let uid = cleaned(d["uid"] as? String) ?? docId
            let linked = cleaned(d["linked_player_id"] as? String)
            let explicitName = cleaned(d["submitted_display_name"] as? String)
                ?? cleaned(d["display_name"] as? String)
                ?? cleaned(d["displayName"] as? String)

            let displayName = explicitName
                ?? nameById[docId]
                ?? nameById[uid]
                ?? linked.flatMap { nameById[$0] }
                ?? linked
                ?? docId

            let submittedAt =
                (d["submittedAt"] as? Timestamp)?.dateValue()
                ?? (d["submitted_at"] as? Timestamp)?.dateValue()
                ?? (d["updatedAt"] as? Timestamp)?.dateValue()
                ?? (d["updated_at"] as? Timestamp)?.dateValue()

            // Parse answers flexibly into [String: Int]
            var answers: [String: Int]? = nil
            if let a = d["answers"] as? [String: Int] {
                answers = a
            } else if let raw = d["answers"] as? [String: Any] {
                var parsed: [String: Int] = [:]
                for (k, v) in raw {
                    if let iv = v as? Int { parsed[k] = iv }
                    else if let dv = v as? Double { parsed[k] = Int(dv) }
                    else if let sv = v as? String, let iv = Int(sv) { parsed[k] = iv }
                }
                if !parsed.isEmpty { answers = parsed }
            }

            // Parse score flexibly
            var parsedScore: Int? = nil
            if let s = d["score"] as? Int { parsedScore = s }
            else if let s = d["score"] as? Double { parsedScore = Int(s) }
            else if let s = d["score"] as? String, let si = Int(s) { parsedScore = si }
            else if let s = d["points"] as? Int { parsedScore = s }
            else if let s = d["points_total"] as? Int { parsedScore = s }
            else if let s = d["points"] as? Double { parsedScore = Int(s) }

            if parsedScore == nil, let ans = answers {
                parsedScore = ans.values.reduce(0, +)
            }

            let score = parsedScore ?? 0
            let maxScore = (d["maxScore"] as? Int) ?? (d["max_score"] as? Int)

            let row = WeeklyScoreRow(
                id: docId,
                displayName: displayName,
                score: score,
                maxScore: maxScore,
                answers: answers,
                submittedAt: submittedAt
            )

            if docId.lowercased().hasPrefix("admin_") {
                adminsAcc.append(row)
            } else {
                playersAcc.append(row)
            }
        }

        playersAcc.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.displayName < $1.displayName
        }
        adminsAcc.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.displayName < $1.displayName
        }

        self.playersRows = playersAcc
        self.adminsRows = adminsAcc
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
