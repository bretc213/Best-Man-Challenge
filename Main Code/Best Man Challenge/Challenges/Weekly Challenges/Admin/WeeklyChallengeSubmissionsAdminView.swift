//
//  WeeklyChallengeSubmissionsAdminView.swift
//  Best Man Challenge
//
//  Owner-only admin tool: view and DELETE individual player submissions for a
//  given weekly challenge. Works for EVERY challenge type — it operates on the
//  shared `weekly_challenges/{id}/submissions/{submitterId}` records that feed
//  the standings/leaderboard.
//
//  Primary use case: Bret clearing his OWN submission to re-play a challenge,
//  but any player's submission can be removed.
//
//  Deleting a submission:
//    • removes weekly_challenges/{id}/submissions/{submitterId}
//    • if the submission carries a `uid` (prop-bets / pick 'em), also removes
//      weekly_challenges/{id}/picks/{uid} so their picks are fully cleared too
//    • the player drops off the weekly standings automatically (the store is live)
//
//  Every delete is guarded by an "Are you sure?" confirmation that names the
//  player AND shows their submission document ID.
//

import SwiftUI
import FirebaseFirestore

struct WeeklyChallengeSubmissionsAdminView: View {
    let challenge: WeeklyChallenge

    @StateObject private var vm = SubmissionsAdminVM()
    @State private var pendingDelete: AdminSubmissionRow?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text("Delete a player's submission for this challenge. This permanently removes their scored entry and drops them from the weekly standings. Mainly for clearing your own entry to replay — but works for anyone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if let status = vm.statusMessage {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(vm.statusIsError ? .red : .green)
                        .padding(.horizontal)
                }

                if vm.isLoading {
                    ProgressView("Loading submissions…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if vm.rows.isEmpty {
                    Text("No submissions yet for this challenge.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    ForEach(vm.rows) { row in
                        submissionCard(row)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Submissions — W\(challenge.week)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(challengeId: challenge.id) }
        .confirmationDialog(
            "Delete this submission?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let row = pendingDelete {
                Button("Delete \(row.displayName)'s submission", role: .destructive) {
                    let toDelete = row
                    pendingDelete = nil
                    Task { await vm.deleteSubmission(challengeId: challenge.id, row: toDelete) }
                }
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            if let row = pendingDelete {
                Text("You're about to permanently delete this submission for Week \(challenge.week):\n\nPlayer: \(row.displayName)\nID: \(row.id)\n\nThis can't be undone.")
            }
        }
    }

    // MARK: - Row card

    private func submissionCard(_ row: AdminSubmissionRow) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("ID: \(row.id)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    if let score = row.scoreText {
                        Text(score)
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    if let sub = row.submittedText {
                        Text(sub)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button(role: .destructive) {
                pendingDelete = row
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(vm.deletingId == row.id)
            .overlay {
                if vm.deletingId == row.id {
                    ProgressView().scaleEffect(0.7)
                }
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

// MARK: - Row model

struct AdminSubmissionRow: Identifiable, Equatable {
    let id: String            // submission document id (submitterId)
    let displayName: String
    let uid: String?          // Auth uid, when present (used to also clear picks/)
    let scoreText: String?
    let submittedText: String?
}

// MARK: - ViewModel

@MainActor
final class SubmissionsAdminVM: ObservableObject {
    @Published var rows: [AdminSubmissionRow] = []
    @Published var isLoading = false
    @Published var deletingId: String?
    @Published var statusMessage: String?
    @Published var statusIsError = false

    private let db = Firestore.firestore()

    func load(challengeId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let snap = try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("submissions")
                .getDocuments()

            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .short

            self.rows = snap.documents.map { doc in
                let d = doc.data()

                let name = (d["display_name"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedName = (name?.isEmpty == false) ? name! : "Unknown player"

                let uid = (d["uid"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

                // Score chip — only if the doc actually has a score.
                var scoreText: String? = nil
                if let score = intValue(d["score"]) {
                    if let maxScore = intValue(d["max_score"]) {
                        scoreText = "\(score)/\(maxScore) pts"
                    } else {
                        scoreText = "\(score) pts"
                    }
                }

                // Submitted timestamp — try a few known keys.
                var submittedText: String? = nil
                if let ts = (d["submitted_at"] as? Timestamp) ?? (d["submittedAt"] as? Timestamp) ?? (d["updated_at"] as? Timestamp) {
                    submittedText = df.string(from: ts.dateValue())
                }

                return AdminSubmissionRow(
                    id: doc.documentID,
                    displayName: resolvedName,
                    uid: (uid?.isEmpty == false) ? uid : nil,
                    scoreText: scoreText,
                    submittedText: submittedText
                )
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        } catch {
            setStatus("Failed to load submissions: \(error.localizedDescription)", isError: true)
        }
    }

    func deleteSubmission(challengeId: String, row: AdminSubmissionRow) async {
        deletingId = row.id
        defer { deletingId = nil }

        let challengeRef = db.collection("weekly_challenges").document(challengeId)

        do {
            // 1) Delete the scored submission doc (drops them from standings).
            try await challengeRef.collection("submissions").document(row.id).delete()

            // 2) Prop-bets / pick 'em also store raw picks keyed by Auth uid.
            //    Clear those too when we know the uid. (No-op if the doc doesn't exist.)
            if let uid = row.uid, !uid.isEmpty {
                try await challengeRef.collection("picks").document(uid).delete()
            }
            // Safety: some prop docs are keyed by the submission id itself.
            if row.uid == nil || row.uid == row.id {
                try? await challengeRef.collection("picks").document(row.id).delete()
            }

            rows.removeAll { $0.id == row.id }
            setStatus("🗑️ Deleted \(row.displayName)'s submission.", isError: false)

        } catch {
            setStatus("Delete failed: \(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - Helpers

    private func intValue(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let i = any as? Int64 { return Int(i) }
        if let d = any as? Double { return Int(d) }
        if let n = any as? NSNumber { return n.intValue }
        return nil
    }

    private func setStatus(_ text: String, isError: Bool) {
        statusMessage = text
        statusIsError = isError
        let captured = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            if self?.statusMessage == captured { self?.statusMessage = nil }
        }
    }
}
