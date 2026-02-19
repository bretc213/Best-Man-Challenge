//
//  WBC2026ResultsStore.swift
//  Best Man Challenge
//
//  Admin-set results for WBC 2026 bracket challenge.
//

import Foundation
import FirebaseFirestore

@MainActor
final class WBC2026ResultsStore: ObservableObject {

    let bracketId: String
    @Published var results: WBCResults = WBCResults()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init(bracketId: String = "wbc_2026") {
        self.bracketId = bracketId
    }

    deinit {
        listener?.remove()
    }

    func startListening() {
        if listener != nil { return }
        isLoading = true
        errorMessage = nil

        listener = db.collection("brackets")
            .document(bracketId)
            .collection("results")
            .document("current")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in
                        self.errorMessage = err.localizedDescription
                        self.isLoading = false
                    }
                    return
                }

                let d = snap?.data() ?? [:]
                let pool = d["poolResults"] as? [String: [String: String]] ?? [:]

                // Semifinalists + finalists (order does NOT matter for scoring)
                let ff = d["finalFour"] as? [String] ?? []
                let ft = d["finalTwo"] as? [String] ?? []
                let champ = d["champion"] as? String

                Task { @MainActor in
                    self.results = WBCResults(poolResults: pool, finalFour: ff, finalTwo: ft, champion: champ)
                    self.isLoading = false
                }
            }
    }

    func stopListening() {
        listener?.remove(); listener = nil
        isLoading = false
    }

    // MARK: - Writes (Admin)

    func setPoolResult(pool: WBCPool, seed: String, teamId: String) async throws {
        let ref = db.collection("brackets")
            .document(bracketId)
            .collection("results")
            .document("current")

        try await ref.setData([
            "updatedAt": Timestamp(date: Date()),
            "poolResults": [
                pool.rawValue: [
                    seed: teamId
                ]
            ]
        ], merge: true)
    }

    /// index 0..3 (order does NOT matter; treated as a set for scoring)
    func setFinalFour(index: Int, teamId: String) async throws {
        try await setArrayElement(field: "finalFour", index: index, value: teamId, targetCount: 4)
    }

    /// index 0..1 (order does NOT matter; treated as a set for scoring)
    func setFinalTwo(index: Int, teamId: String) async throws {
        try await setArrayElement(field: "finalTwo", index: index, value: teamId, targetCount: 2)
    }

    func setChampion(teamId: String) async throws {
        let ref = db.collection("brackets")
            .document(bracketId)
            .collection("results")
            .document("current")
        try await ref.setData([
            "updatedAt": Timestamp(date: Date()),
            "champion": teamId
        ], merge: true)
    }

    private func setArrayElement(field: String, index: Int, value: String, targetCount: Int) async throws {
        let ref = db.collection("brackets")
            .document(bracketId)
            .collection("results")
            .document("current")

        let snap = try await ref.getDocument()
        var arr = snap.data()?[field] as? [String] ?? []
        if arr.count < targetCount {
            arr.append(contentsOf: Array(repeating: "", count: targetCount - arr.count))
        }
        if index >= 0 && index < targetCount {
            arr[index] = value
        }
        try await ref.setData([
            "updatedAt": Timestamp(date: Date()),
            field: arr
        ], merge: true)
    }
}
