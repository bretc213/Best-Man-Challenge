//
//  WeeklyChallengeAdminStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/8/26.
//


//
//  WeeklyChallengeAdminStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/8/26.
//

import Foundation
import FirebaseFirestore

@MainActor
final class WeeklyChallengeAdminStore: ObservableObject {
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    /// Updates correct_index for a question inside weekly_challenges/{challengeId}.quiz.questions
    func setCorrectIndex(
        challengeId: String,
        questionId: String,
        correctIndex: Int
    ) async {
        guard correctIndex == 0 || correctIndex == 1 else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let ref = db.collection("weekly_challenges").document(challengeId)

            // Load current questions array
            let snap = try await ref.getDocument()
            let data = snap.data() ?? [:]
            let quiz = data["quiz"] as? [String: Any] ?? [:]
            var questions = quiz["questions"] as? [[String: Any]] ?? []

            // Find question and update correct_index
            guard let idx = questions.firstIndex(where: { ($0["id"] as? String) == questionId }) else {
                throw NSError(domain: "WeeklyAdmin", code: 404,
                              userInfo: [NSLocalizedDescriptionKey: "Question \(questionId) not found."])
            }

            questions[idx]["correct_index"] = correctIndex

            // Write back quiz.questions (merge true is fine)
            try await ref.setData([
                "quiz": [
                    "questions": questions
                ],
                "updated_at": FieldValue.serverTimestamp()
            ], merge: true)

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
