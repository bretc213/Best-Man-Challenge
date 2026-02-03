//
//  PropBetsStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 2/3/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class PropBetsStore: ObservableObject {

    @Published var challenge: PropBetsChallenge?
    @Published var props: [PropBet] = []

    @Published var selections: [String: String] = [:] // propId -> optionId
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?

    @Published var isDirty: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var lastSubmittedAt: Date?

    private var propsListener: ListenerRegistration?
    private var picksListener: ListenerRegistration?
    private var challengeListener: ListenerRegistration?

    private var hasHydratedFromFirestore = false

    deinit {
        propsListener?.remove()
        picksListener?.remove()
        challengeListener?.remove()
    }

    func start(challengeId: String) {
        stop()

        isLoading = true
        errorMessage = nil
        isDirty = false
        isSubmitting = false
        lastSubmittedAt = nil
        hasHydratedFromFirestore = false

        let db = Firestore.firestore()
        let challengeRef = db.collection("weekly_challenges").document(challengeId)

        // 1) Challenge listener
        challengeListener = challengeRef.addSnapshotListener { [weak self] snap, err in
            guard let self else { return }
            if let err {
                Task { @MainActor in self.errorMessage = err.localizedDescription }
                return
            }
            guard let snap, snap.exists, let data = snap.data() else { return }

            if let decoded = PropBetsChallenge.fromDoc(id: snap.documentID, data: data) {
                Task { @MainActor in self.challenge = decoded }
            } else {
                Task { @MainActor in self.errorMessage = "Challenge decode failed: missing required fields." }
            }
        }

        // 2) Props listener (ordered)
        propsListener = challengeRef.collection("props")
            .whereField("is_active", isEqualTo: true)
            .order(by: "position", descending: false)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in self.errorMessage = err.localizedDescription }
                    return
                }
                guard let snap else { return }

                var newProps: [PropBet] = []
                newProps.reserveCapacity(snap.documents.count)

                for doc in snap.documents {
                    let data = doc.data()
                    if let p = PropBet.fromDoc(id: doc.documentID, data: data) {
                        newProps.append(p)
                    }
                }

                newProps.sort { $0.position < $1.position }

                Task { @MainActor in
                    self.props = newProps
                    self.isLoading = false
                }
            }

        // 3) Picks listener (loads submitted picks)
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }

        picksListener = challengeRef.collection("picks").document(uid)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    Task { @MainActor in self.errorMessage = err.localizedDescription }
                    return
                }

                // If no doc, reset only on first hydration
                guard let snap, snap.exists, let data = snap.data() else {
                    Task { @MainActor in
                        if !self.hasHydratedFromFirestore {
                            self.selections = [:]
                            self.isDirty = false
                            self.lastSubmittedAt = nil
                            self.hasHydratedFromFirestore = true
                        }
                    }
                    return
                }

                let remoteSelections = data["selections"] as? [String: String] ?? [:]
                let submittedAt = (data["submitted_at"] as? Timestamp)?.dateValue()

                Task { @MainActor in
                    // Don't clobber in-progress edits.
                    if !self.isDirty {
                        self.selections = remoteSelections
                    }
                    self.lastSubmittedAt = submittedAt
                    self.hasHydratedFromFirestore = true
                }
            }
    }

    func stop() {
        propsListener?.remove()
        picksListener?.remove()
        challengeListener?.remove()
        propsListener = nil
        picksListener = nil
        challengeListener = nil
    }

    var isLocked: Bool {
        challenge?.isLocked ?? false
    }

    // ✅ Local-only selection (no Firestore write)
    func selectOption(propId: String, optionId: String) {
        guard !isLocked else { return }
        selections[propId] = optionId
        isDirty = true
    }

    // ✅ Submit writes current picks (can be resubmitted/updated until locksAt)
    func submitPicks() async {
        guard !isLocked else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let challengeId = challenge?.id, !challengeId.isEmpty else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let db = Firestore.firestore()
            let pickRef = db.collection("weekly_challenges")
                .document(challengeId)
                .collection("picks")
                .document(uid)

            try await pickRef.setData([
                "uid": uid,
                "selections": selections,
                "submitted_at": FieldValue.serverTimestamp(),   // always refresh on submit
                "updated_at": FieldValue.serverTimestamp()
            ], merge: true)

            isDirty = false

        } catch {
            errorMessage = "Submit failed: \(error.localizedDescription)"
        }
    }
}
