//
//  AdminScoringHubView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/24/26.
//

import SwiftUI
import FirebaseFirestore

/// Admin hub to finalize challenges. Owner-only actions by default.
struct AdminScoringHubView: View {
    @EnvironmentObject var session: SessionStore

    @State private var isRunning: Bool = false
    @State private var statusMessage: String? = nil

    // MARK: - Challenge Finalizers (existing)

    struct ChallengeRow: Identifiable {
        let id: String           // challengeId used for point_awards doc ids
        let title: String
        var multiplier: Double
        let description: String
        let higherIsBetter: Bool

        /// If true, and finalize succeeds, we will move the corresponding at-home tile to "archived".
        /// Use this ONLY for "complete" challenges (ex: NFL overall), not partial rounds.
        let archivesAtHomeOnFinalize: Bool

        let scoreProvider: () async throws -> [String: Double]
    }

    @State private var rows: [ChallengeRow] = []

    // MARK: - Weekly Winner Bonuses (+1)

    struct WeeklyBonusRow: Identifiable {
        let id: String           // weeklyId e.g. "2026_w01"
        let week: Int
        let title: String
        let isFinalized: Bool
        let bonusesApplied: Bool
        let winnerBonus: Double
        let winners: [String]
    }

    @State private var weeklyBonusRows: [WeeklyBonusRow] = []
    private let db = Firestore.firestore()

    var body: some View {
        ThemedScreen {
            VStack(spacing: 12) {
                header()

                List {

                    // -------------------------------
                    // Challenge Finalizers
                    // -------------------------------
                    Section("Challenge Finalizers") {
                        ForEach($rows) { $row in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(row.title).font(.headline)
                                        Text(row.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("×\(Int(row.multiplier))")
                                        .font(.subheadline).bold()
                                }

                                HStack(spacing: 12) {
                                    Stepper(value: $row.multiplier, in: 1...5, step: 1) {
                                        Text("Multiplier: ×\(Int(row.multiplier))")
                                    }
                                    .labelsHidden()

                                    Spacer()

                                    Button {
                                        Task { await finalize(row: row) }
                                    } label: {
                                        Label("Finalize", systemImage: "checkmark.seal")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!isOwnerAccount() || isRunning)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }

                    // -------------------------------
                    // Weekly Winner Bonuses (+1)
                    // -------------------------------
                    Section("Weekly Winner Bonuses (+1)") {

                        if weeklyBonusRows.isEmpty {
                            Text("No weekly challenges found yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(weeklyBonusRows) { w in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Week \(w.week) — Weekly Winner Bonus")
                                                .font(.headline)
                                            Text(w.title)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("+\(formatPoints(w.winnerBonus))")
                                                .font(.subheadline).bold()
                                            Text(w.isFinalized ? "Finalized" : "Not Finalized")
                                                .font(.caption2)
                                                .foregroundColor(w.isFinalized ? .secondary : .orange)
                                        }
                                    }

                                    if !w.winners.isEmpty {
                                        Text("Winners: \(w.winners.joined(separator: ", "))")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Winners: (will compute from submissions if empty)")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    HStack {
                                        if w.bonusesApplied {
                                            Label("Bonus Applied", systemImage: "checkmark.circle.fill")
                                                .font(.footnote)
                                                .foregroundStyle(.green)
                                        } else {
                                            Label("Not Applied", systemImage: "circle")
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button {
                                            Task { await applyWeeklyBonus(weeklyId: w.id) }
                                        } label: {
                                            Label(
                                                w.bonusesApplied ? "Re-Apply Winner Bonus" : "Apply Winner Bonus",
                                                systemImage: w.bonusesApplied ? "arrow.clockwise.circle.fill" : "plus.circle.fill"
                                            )
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(!isOwnerAccount() || isRunning || !w.isFinalized)

                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await reloadWeeklyRows() }

                if let msg = statusMessage {
                    Text(msg)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .onAppear {
                setupRows()
                Task { await reloadWeeklyRows() }
            }
        }
    }

    private func header() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Scoring Admin").font(.title2).bold()
            Text("Finalize challenge results and award points. Only owners can finalize.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private func setupRows() {
        rows = [
            ChallengeRow(
                id: "cfb_playoffs_2025",
                title: "CFB Playoffs 2025",
                multiplier: 1,
                description: "College Football playoff pool (test/hardcoded).",
                higherIsBetter: true,
                archivesAtHomeOnFinalize: true, // ✅ complete challenge, archive tile when finalized
                scoreProvider: {
                    return [
                        "valentinom": 14,
                        "dannyo": 16,
                        "isaiahs": 6,
                        "jakeo": 6,
                        "joelr": 8,
                        "ronaldp": 8,
                        "matthewp": 8,
                        "anthonyc": 2,
                        "mitchz": 2,
                        "kylel": 6,
                        "matthewc": 6,
                        "bretc": 0
                    ]
                }
            ),
            ChallengeRow(
                id: "nfl_playoffs_2026_overall",
                title: "NFL Playoffs 2026 (Overall)",
                multiplier: 3,
                description: "Totals across all rounds (computed from Firestore via NFLPlayoffsScoresStore).",
                higherIsBetter: true,
                archivesAtHomeOnFinalize: true, // ✅ only archive when OVERALL is finalized
                scoreProvider: {
                    let store = NFLPlayoffsScoresStore(bracketId: "nfl_2026_playoffs")
                    let provider = NFLPlayoffsScoresProvider(store: store)
                    return try await provider.fetchScoresByPlayer()
                }
            )
        ]
    }

    private func reloadWeeklyRows() async {
        do {
            let snap = try await db.collection("weekly_challenges").getDocuments()

            let mapped: [WeeklyBonusRow] = snap.documents.compactMap { doc in
                let d = doc.data()
                let week = (d["week"] as? NSNumber)?.intValue ?? 0
                let title = (d["title"] as? String) ?? doc.documentID
                let isFinalized = (d["is_finalized"] as? Bool) ?? false
                let applied = (d["winner_bonuses_applied"] as? Bool) ?? false
                let bonus = (d["winner_bonus"] as? NSNumber)?.doubleValue ?? 1.0
                let winners = (d["winners"] as? [String]) ?? []

                return WeeklyBonusRow(
                    id: doc.documentID,
                    week: week,
                    title: title,
                    isFinalized: isFinalized,
                    bonusesApplied: applied,
                    winnerBonus: bonus,
                    winners: winners
                )
            }
            .sorted { $0.week < $1.week }

            await MainActor.run { self.weeklyBonusRows = mapped }
        } catch {
            await MainActor.run {
                self.setStatus("Failed to load weekly challenges: \(error.localizedDescription)", temporary: true)
            }
        }
    }

    private func finalize(row: ChallengeRow) async {
        guard isOwnerAccount() else {
            setStatus("Only owners can finalize.", temporary: true)
            return
        }

        isRunning = true
        setStatus("Gathering scores for \(row.title)...", temporary: false)

        do {
            let scores = try await row.scoreProvider()
            guard !scores.isEmpty else {
                setStatus("No scores available for \(row.title).", temporary: true)
                isRunning = false
                return
            }

            setStatus("Running finalizer for \(row.title) (×\(Int(row.multiplier)))...", temporary: false)

            let finalizer = ChallengePointsFinalizer()
            try await finalizer.finalizeChallenge(
                challengeId: row.id,
                scoresByPlayer: scores,
                multiplier: row.multiplier,
                higherIsBetter: row.higherIsBetter
            )

            setStatus("Finalize complete for \(row.title).", temporary: true)

            // ✅ Only archive the at-home tile when this finalize represents "complete"
            if row.archivesAtHomeOnFinalize {
                await markAtHomeGameArchived(challengeId: row.id)
            }

        } catch {
            setStatus("Finalize failed: \(error.localizedDescription)", temporary: true)
        }

        isRunning = false
    }

    private func applyWeeklyBonus(weeklyId: String) async {
        guard isOwnerAccount() else {
            setStatus("Only owners can apply bonuses.", temporary: true)
            return
        }

        isRunning = true
        setStatus("Applying weekly winner bonus for \(weeklyId)...", temporary: false)

        do {
            print("🔥 APPLY BONUS tapped for weeklyId:", weeklyId)

            let finalizer = ChallengePointsFinalizer()
            try await finalizer.applyWeeklyWinnerBonus(weeklyId: weeklyId)

            print("✅ APPLY BONUS success for weeklyId:", weeklyId)

            setStatus("Weekly winner bonus applied for \(weeklyId).", temporary: true)

            await reloadWeeklyRows()

            if let row = weeklyBonusRows.first(where: { $0.id == weeklyId }) {
                print("🏁 Applied winners for \(weeklyId):", row.winners)
            }
        } catch {
            print("❌ APPLY BONUS failed:", error)
            setStatus("Weekly bonus failed: \(error.localizedDescription)", temporary: true)
        }

        isRunning = false
    }

    // MARK: - At Home archiving (new)

    /// Finds the at-home game doc whose `challengeId` matches and moves it to archived.
    /// This does nothing if the finalize row is not tied to an at-home tile.
    private func markAtHomeGameArchived(challengeId: String) async {
        do {
            let snap = try await db.collection("at_home_games")
                .whereField("challengeId", isEqualTo: challengeId)
                .getDocuments()

            guard let doc = snap.documents.first else {
                // Not an at-home game (or not seeded yet)
                return
            }

            try await doc.reference.updateData([
                "state": "archived",
                "finalizedAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } catch {
            // We intentionally don't fail the scoring finalize if archiving fails.
            print("⚠️ Failed to archive at-home game for \(challengeId):", error)
        }
    }

    // MARK: - Owner + status helpers

    private func isOwnerAccount() -> Bool {
        let role = session.profile?.role ?? ""
        return role == "owner" || role == "commish"
    }

    private func setStatus(_ text: String, temporary: Bool) {
        statusMessage = text
        if temporary {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                if statusMessage == text { statusMessage = nil }
            }
        }
    }

    private func formatPoints(_ pts: Double) -> String {
        pts == floor(pts) ? String(Int(pts)) : String(format: "%.1f", pts)
    }
}
