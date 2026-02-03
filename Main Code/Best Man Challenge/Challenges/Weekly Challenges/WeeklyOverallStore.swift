//
//  WeeklyOverallRow.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/7/26.
//

import Foundation
import FirebaseFirestore

typealias WeeklyChallengesOverallStore = WeeklyOverallStore

@MainActor
final class WeeklyOverallStore: ObservableObject {
    
    @Published var playersRows: [WeeklyScoreRow] = []
    @Published var adminsRows: [WeeklyScoreRow] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    /// uid -> role (lowercased)
    private var roleByUID: [String: String] = [:]
    
    func refresh() {
        Task { await rebuildOverall() }
    }
    
    private func loadAccountsIndex() async {
        do {
            let snap = try await db.collection("accounts").getDocuments()
            var map: [String: String] = [:]
            
            for doc in snap.documents {
                let data = doc.data()
                let uid = (data["claimed_by_uid"] as? String) ?? ""
                let role = (data["role"] as? String ?? "").lowercased()
                if !uid.isEmpty {
                    map[uid] = role
                }
            }
            
            roleByUID = map
        } catch {
            roleByUID = [:]
        }
    }
    
    private func rebuildOverall() async {
        isLoading = true
        errorMessage = nil
        playersRows = []
        adminsRows = []
        
        await loadAccountsIndex()
        
        do {
            let challengesSnap = try await db.collection("weekly_challenges").getDocuments()
            let challengeDocs = challengesSnap.documents
            
            // uid -> (name, totalScore)
            var totalByUID: [String: (name: String, total: Int)] = [:]
            
            for challenge in challengeDocs {
                let challengeId = challenge.documentID
                let challengeData = challenge.data()
                
                // Try to read quiz config for scorable grading
                let quizMap = challengeData["quiz"] as? [String: Any]
                let pointsPerCorrect = (quizMap?["points_per_correct"] as? Int) ?? 1
                let questions = quizMap?["questions"] as? [[String: Any]] ?? []
                
                // Build: questionId -> correctIndex (only if present)
                var correctByQid: [String: Int] = [:]
                for q in questions {
                    guard
                        let qid = q["id"] as? String,
                        let correctIndex = q["correct_index"] as? Int
                    else { continue }
                    correctByQid[qid] = correctIndex
                }
                
                let subsSnap = try await db.collection("weekly_challenges")
                    .document(challengeId)
                    .collection("submissions")
                    .getDocuments()
                
                for sub in subsSnap.documents {
                    let data = sub.data()
                    
                    let uidField = (data["uid"] as? String) ?? ""
                    let uid: String = {
                        if !uidField.isEmpty { return uidField }
                        let docId = sub.documentID
                        if docId.lowercased().hasPrefix("admin_") {
                            return String(docId.dropFirst("admin_".count))
                        }
                        return docId
                    }()
                    
                    let name =
                    (data["display_name"] as? String)
                    ?? (data["displayName"] as? String)
                    ?? "Unknown"
                    
                    // ✅ Compute scorable score if we have answers + correct keys
                    var earned = 0
                    
                    if let answers = data["answers"] as? [String: Int], !correctByQid.isEmpty {
                        for (qid, correctIndex) in correctByQid {
                            if answers[qid] == correctIndex {
                                earned += pointsPerCorrect
                            }
                        }
                    } else {
                        // Fallback: use stored score
                        earned = data["score"] as? Int ?? 0
                    }
                    
                    if var existing = totalByUID[uid] {
                        existing.total += earned
                        if existing.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            existing.name = name
                        }
                        totalByUID[uid] = existing
                    } else {
                        totalByUID[uid] = (name: name, total: earned)
                    }
                }
            }
            
            var players: [WeeklyScoreRow] = []
            var admins: [WeeklyScoreRow] = []
            
            for (uid, v) in totalByUID {
                let role = (roleByUID[uid] ?? "").lowercased()
                let isAdmin = ["owner", "commish", "ref", "admin", "exec", "commissioner"].contains(role)
                
                let row = WeeklyScoreRow(
                    id: uid,
                    displayName: v.name,
                    score: v.total,
                    maxScore: (nil as Int?),
                    answers: (nil as [String: Int]?),
                    submittedAt: (nil as Date?)
                )
                
                if isAdmin { admins.append(row) } else { players.append(row) }
            }
            
            func sortRows(_ rows: [WeeklyScoreRow]) -> [WeeklyScoreRow] {
                rows.sorted {
                    if $0.score != $1.score { return $0.score > $1.score }
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
            }
            
            self.playersRows = sortRows(players)
            self.adminsRows = sortRows(admins)
            self.isLoading = false
            
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
}
