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

        print("DIAG: WeeklyStandingsStore.startListening(activeChallengeId: \(activeChallengeId))")

        listener = db.collection("weekly_challenges")
            .document(activeChallengeId)
            .collection("submissions")
            .addSnapshotListener { [weak self] snap, err in
                Task { @MainActor in
                    guard let self = self else { return }

                    // Always ensure we clear loading and handle errors
                    defer {
                        self.isLoading = false
                    }

                    if let err {
                        self.errorMessage = err.localizedDescription
                        print("DIAG: snapshot error: \(err.localizedDescription)")
                        return
                    }

                    let docs = snap?.documents ?? []
                    print("DIAG: snapshot docs=\(docs.count) (challenge=\(activeChallengeId))")

                    // Build a map userId -> [QueryDocumentSnapshot] for dedupe
                    var byUser: [String: [QueryDocumentSnapshot]] = [:]
                    for doc in docs {
                        let data = doc.data()
                        let userId = (data["user_id"] as? String)
                            ?? (data["uid"] as? String)
                            ?? (data["playerId"] as? String)
                            ?? doc.documentID

                        byUser[userId, default: []].append(doc)
                    }

                    var playersAcc: [WeeklyScoreRow] = []
                    var adminsAcc: [WeeklyScoreRow] = []

                    for (userId, docsForUser) in byUser {
                        // Choose the latest doc safely; fallback to first element
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
                                case (.some(let aDate), .some(let bDate)):
                                    return aDate < bDate
                                case (.some, .none):
                                    return false
                                case (.none, .some):
                                    return true
                                case (.none, .none):
                                    return a.documentID < b.documentID
                                }
                            }) ?? docsForUser[0]
                        }

                        let d = chosenDoc.data()
                        print("DIAG: chosen docId=\(chosenDoc.documentID) keys=\(Array(d.keys))")

                        // Extract display name and times (safe)
                        let docId = chosenDoc.documentID
                        let displayName = (d["submitted_display_name"] as? String)
                            ?? (d["display_name"] as? String)
                            ?? (d["displayName"] as? String)
                            ?? docId

                        let submittedAt =
                            (d["submittedAt"] as? Timestamp)?.dateValue()
                            ?? (d["submitted_at"] as? Timestamp)?.dateValue()
                            ?? (d["updatedAt"] as? Timestamp)?.dateValue()
                            ?? (d["updated_at"] as? Timestamp)?.dateValue()

                        // Parse answers flexibly into [String: Int] — safe, non-throwing
                        var answers: [String: Int]? = nil
                        if let a = d["answers"] as? [String: Int] {
                            answers = a
                        } else if let raw = d["answers"] as? [String: Any] {
                            var parsed: [String: Int] = [:]
                            for (k, v) in raw {
                                if let iv = v as? Int { parsed[k] = iv }
                                else if let dv = v as? Double { parsed[k] = Int(dv) }
                                else if let sv = v as? String, let iv = Int(sv) { parsed[k] = iv }
                                // otherwise skip non-numeric values
                            }
                            if !parsed.isEmpty { answers = parsed }
                        }

                        // Alternate keys to look for if answers missing
                        let altAnswerKeys = ["responses", "submission", "answers_map", "answersObject", "answersMap", "answers_raw"]
                        var foundAltKey: String? = nil
                        for k in altAnswerKeys {
                            if d[k] != nil {
                                foundAltKey = k
                                break
                            }
                        }
                        if foundAltKey != nil {
                            print("DIAG: doc \(docId) has alt answers key '\(foundAltKey!)'")
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
                            print("DIAG: computed score from answers for \(docId): \(parsedScore!)")
                        }

                        // Final values (defaults)
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

                    // Sort and publish
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
                } // Task @MainActor
            } // addSnapshotListener
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
