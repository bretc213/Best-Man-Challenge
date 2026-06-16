//
//  PropBetsAdminGradingView.swift
//  Best Man Challenge
//
//  Owner-only admin view for grading prop bets results.
//
//  WORKFLOW:
//   1. Tap the correct option for each prop → saves correct_option_id to Firestore.
//      (This triggers auto-scoring for any user who has the app open via PropBetsStore listener.)
//   2. Tap "Grade All Submissions" → reads every player's picks doc and
//      writes final scores to submissions/ for anyone who submitted.
//

import SwiftUI
import FirebaseFirestore

struct PropBetsAdminGradingView: View {
    let challenge: WeeklyChallenge

    @StateObject private var vm = PropBetsAdminGradingVM()
    @State private var showGradeConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Status banner
                if let status = vm.statusMessage {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(vm.statusIsError ? .red : .green)
                        .padding(.horizontal)
                }

                // Props list
                if vm.isLoading {
                    ProgressView("Loading props…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if vm.props.isEmpty {
                    Text("No active props found for this challenge.")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    ForEach(vm.props) { prop in
                        propCard(prop)
                    }
                }

                Divider().padding(.horizontal)

                // Grade All button
                VStack(spacing: 8) {
                    Button {
                        showGradeConfirm = true
                    } label: {
                        Label("Grade All Submissions", systemImage: "checkmark.seal.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(vm.isGrading || vm.props.filter { $0.correctOptionId != nil }.isEmpty)
                    .padding(.horizontal)

                    Text("Scores every player's picks against the answers you've set above. Safe to re-run.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if vm.isGrading {
                        ProgressView(vm.gradingProgressMessage ?? "Grading…")
                            .padding(.top, 4)
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(.top, 12)
        }
        .navigationTitle("Grade Props — W\(challenge.week)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load(challengeId: challenge.id) }
        .confirmationDialog(
            "Grade All Submissions",
            isPresented: $showGradeConfirm,
            titleVisibility: .visible
        ) {
            Button("Grade Now") {
                Task { await vm.gradeAllSubmissions(challengeId: challenge.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let answered = vm.props.filter { $0.correctOptionId != nil }.count
            Text("This will score all player picks against the \(answered) prop(s) you've answered. You can re-run anytime.")
        }
    }

    // MARK: - Prop Card

    private func propCard(_ prop: AdminPropBet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(prop.prompt)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                kindBadge(prop.kind)
            }

            if let line = prop.line {
                Text("Line: \(line, specifier: "%.1f")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                ForEach(prop.options, id: \.id) { option in
                    optionButton(prop: prop, option: option)
                }
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func optionButton(prop: AdminPropBet, option: AdminPropOption) -> some View {
        let isCorrect = prop.correctOptionId == option.id
        let isSaving  = vm.savingPropId == prop.id

        return Button {
            Task {
                await vm.setCorrectOption(
                    challengeId: challenge.id,
                    propId: prop.id,
                    optionId: option.id
                )
            }
        } label: {
            HStack {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCorrect ? .green : .secondary)
                Text(option.label)
                    .foregroundStyle(.primary)
                    .font(.subheadline)
                Spacer()
                if let odds = option.oddsAmerican {
                    Text(odds > 0 ? "+\(odds)" : "\(odds)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isCorrect ? Color.green.opacity(0.15) : Color.secondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }

    private func kindBadge(_ kind: String) -> some View {
        Text(kind == "over_under" ? "O/U" : "Pick")
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.15))
            .foregroundStyle(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - Local models (admin-side, flat)

struct AdminPropOption: Identifiable {
    let id: String
    let position: Int
    let label: String
    let oddsAmerican: Int?
}

struct AdminPropBet: Identifiable {
    let id: String
    let position: Int
    let kind: String
    let prompt: String
    let line: Double?
    let options: [AdminPropOption]
    var correctOptionId: String?
}

// MARK: - ViewModel

@MainActor
final class PropBetsAdminGradingVM: ObservableObject {
    @Published var props: [AdminPropBet] = []
    @Published var isLoading = false
    @Published var savingPropId: String?
    @Published var isGrading = false
    @Published var gradingProgressMessage: String?
    @Published var statusMessage: String?
    @Published var statusIsError = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit { listener?.remove() }

    // MARK: - Load props (live)

    func load(challengeId: String) async {
        isLoading = true
        listener?.remove()

        listener = db.collection("weekly_challenges")
            .document(challengeId)
            .collection("props")
            .whereField("is_active", isEqualTo: true)
            .order(by: "position")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                self.isLoading = false
                if let err { self.setStatus("Load error: \(err.localizedDescription)", isError: true); return }
                guard let snap else { return }

                self.props = snap.documents.compactMap { doc -> AdminPropBet? in
                    let d = doc.data()
                    guard let prompt = d["prompt"] as? String else { return nil }

                    let rawOptions = d["options"] as? [[String: Any]] ?? []
                    let options = rawOptions.compactMap { o -> AdminPropOption? in
                        guard let id = o["id"] as? String else { return nil }
                        return AdminPropOption(
                            id: id,
                            position: o["position"] as? Int ?? 0,
                            label: o["label"] as? String ?? "",
                            oddsAmerican: o["odds_american"] as? Int ?? o["oddsAmerican"] as? Int
                        )
                    }.sorted { $0.position < $1.position }

                    var line: Double? = nil
                    if let d = d["line"] as? Double { line = d }
                    else if let i = d["line"] as? Int { line = Double(i) }

                    return AdminPropBet(
                        id: doc.documentID,
                        position: d["position"] as? Int ?? 0,
                        kind: d["kind"] as? String ?? "multiple_choice",
                        prompt: prompt,
                        line: line,
                        options: options,
                        correctOptionId: d["correct_option_id"] as? String ?? d["correctOptionId"] as? String
                    )
                }.sorted { $0.position < $1.position }
            }
    }

    // MARK: - Set correct option

    func setCorrectOption(challengeId: String, propId: String, optionId: String) async {
        savingPropId = propId
        defer { savingPropId = nil }

        do {
            try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("props")
                .document(propId)
                .setData(["correct_option_id": optionId, "updated_at": FieldValue.serverTimestamp()], merge: true)

            setStatus("✅ Answer saved.", isError: false)
        } catch {
            setStatus("Save failed: \(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - Grade all submissions

    func gradeAllSubmissions(challengeId: String) async {
        isGrading = true
        gradingProgressMessage = "Loading props…"
        defer { isGrading = false; gradingProgressMessage = nil }

        // Build answer key from props that have correct_option_id
        let answerKey: [String: String] = props.reduce(into: [:]) { dict, prop in
            if let correct = prop.correctOptionId { dict[prop.id] = correct }
        }

        guard !answerKey.isEmpty else {
            setStatus("⚠️ No props have been answered yet.", isError: true)
            return
        }

        let maxScore = answerKey.count

        do {
            // Load all picks docs
            gradingProgressMessage = "Loading submissions…"
            let picksSnap = try await db.collection("weekly_challenges")
                .document(challengeId)
                .collection("picks")
                .getDocuments()

            guard !picksSnap.documents.isEmpty else {
                setStatus("No submissions found for this challenge.", isError: false)
                return
            }

            var gradedCount = 0
            let total = picksSnap.documents.count

            for pickDoc in picksSnap.documents {
                let uid = pickDoc.documentID
                let data = pickDoc.data()
                let selections = data["selections"] as? [String: String] ?? [:]

                // Compute score
                var score = 0
                for (propId, correctOptionId) in answerKey {
                    if selections[propId] == correctOptionId { score += 1 }
                }

                // Look up linked_player_id
                let linkedPlayerId = await fetchLinkedPlayerId(uid: uid)

                gradingProgressMessage = "Grading \(gradedCount + 1)/\(total)…"

                // Write to submissions
                var submissionData: [String: Any] = [
                    "uid": uid,
                    "score": score,
                    "max_score": maxScore,
                    "graded_at": FieldValue.serverTimestamp(),
                    "updated_at": FieldValue.serverTimestamp()
                ]
                if let lp = linkedPlayerId { submissionData["linked_player_id"] = lp }

                try await db.collection("weekly_challenges")
                    .document(challengeId)
                    .collection("submissions")
                    .document(uid)
                    .setData(submissionData, merge: true)

                gradedCount += 1
            }

            setStatus("✅ Graded \(gradedCount) submission(s). Max score: \(maxScore).", isError: false)

        } catch {
            setStatus("Grading failed: \(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - Helpers

    private func fetchLinkedPlayerId(uid: String) async -> String? {
        do {
            let snap = try await db.collection("users").document(uid).getDocument()
            let lp = snap.data()?["linked_player_id"] as? String
            return (lp?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        } catch {
            return nil
        }
    }

    private func setStatus(_ text: String, isError: Bool) {
        statusMessage = text
        statusIsError = isError
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            if self?.statusMessage == text { self?.statusMessage = nil }
        }
    }
}
