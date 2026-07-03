//
//  EventsStore.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/20/26.
//


import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class EventsStore: ObservableObject {

    @Published var events: [AppEvent] = []
    @Published var selectedDate: Date = Date()
    @Published var loadError: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening() {
        stopListening()

        listener = db.collection("events")
            .whereField("kind", isEqualTo: "in_person")
            .order(by: "startDate", descending: false)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    self.loadError = err.localizedDescription
                    return
                }

                self.events = snap?.documents.compactMap { doc in
                    try? doc.data(as: AppEvent.self)
                } ?? []
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - RSVP

    struct StoredRSVP {
        var status: RSVPStatus
        var reason: String
        var rsvpVersion: Int?
        var arrivalOption: String?
    }

    func fetchMyRSVP(eventId: String) async -> StoredRSVP? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        let ref = db.collection("events").document(eventId).collection("rsvps").document(uid)
        guard let snap = try? await ref.getDocument(),
              snap.exists,
              let data = snap.data(),
              let rawStatus = data["status"] as? String,
              let status = RSVPStatus(rawValue: rawStatus) else { return nil }
        let reason = data["reason"] as? String ?? ""
        let version = data["rsvpVersion"] as? Int
        let arrivalOption = data["arrivalOption"] as? String
        return StoredRSVP(status: status, reason: reason, rsvpVersion: version, arrivalOption: arrivalOption)
    }

    func submitRSVP(eventId: String, status: RSVPStatus, reason: String?, displayName: String?, rsvpVersion: Int? = nil, arrivalOption: String? = nil) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Events", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
        }

        let ref = db.collection("events").document(eventId).collection("rsvps").document(uid)

        let trimmedReason = (reason ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldIncludeReason = (status == .no || status == .maybe)

        var data: [String: Any] = [
            "uid": uid,
            "displayName": displayName ?? "",
            "status": status.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if shouldIncludeReason {
            data["reason"] = trimmedReason
        } else {
            data["reason"] = "" // keep schema stable
        }

        if let v = rsvpVersion {
            data["rsvpVersion"] = v
        }

        if let a = arrivalOption {
            data["arrivalOption"] = a
        }

        try await ref.setData(data, merge: true)
    }

    // MARK: - Helpers

    func events(on date: Date) -> [AppEvent] {
        events.filter { eventContainsDate($0, date: date) }
            .sorted(by: { $0.startDate < $1.startDate })
    }

    private func eventContainsDate(_ e: AppEvent, date: Date) -> Bool {
        let cal = Calendar.current
        let d0 = cal.startOfDay(for: date)
        let start = cal.startOfDay(for: e.startDate)
        let end = cal.startOfDay(for: e.endDate)
        return (d0 >= start && d0 <= end)
    }
}
