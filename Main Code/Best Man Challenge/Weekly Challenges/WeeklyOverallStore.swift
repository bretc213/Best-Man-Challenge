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
                if !uid.isEmpty { map[uid] = role }
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

            // uid -> (name, lp, totalScore)
            var totalByUID: [String: (name: String, lp: String?, total: Int)] = [:]

            for challenge in challengeDocs {
                let subsSnap = try await db.collection("weekly_challenges")
                    .document(challenge.documentID)
                    .collection("submissions")
                    .getDocuments()

                for sub in subsSnap.documents {
                    let data = sub.data()
                    let uid = data["uid"] as? String ?? sub.documentID
                    let name = data["display_name"] as? String ?? data["displayName"] as? String ?? "Unknown"
                    let lp = data["linked_player_id"] as? String
                    let score = data["score"] as? Int ?? 0

                    if var existing = totalByUID[uid] {
                        existing.total += score
                        // keep earliest known name/lp if needed
                        totalByUID[uid] = (existing.name.isEmpty ? name : existing.name, existing.lp ?? lp, existing.total)
                    } else {
                        totalByUID[uid] = (name, lp, score)
                    }
                }
            }

            var players: [WeeklyScoreRow] = []
            var admins: [WeeklyScoreRow] = []

            for (uid, v) in totalByUID {
                let row = WeeklyScoreRow(
                    id: uid,
                    displayName: v.name,
                    linkedPlayerId: v.lp,
                    score: v.total,
                    maxScore: nil,
                    submittedAt: nil
                )

                let role = (roleByUID[uid] ?? "").lowercased()
                let isAdmin = ["owner", "commish", "ref", "admin", "exec"].contains(role)

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
