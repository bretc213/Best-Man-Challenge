//
//  NFLFuturesRow.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/12/26.
//  (Futures row + store — file kept separate from scores store.)
//

import Foundation
import FirebaseFirestore

struct NFLFuturesRow: Identifiable {
    let id: String
    let displayName: String
    let afc: String?
    let nfc: String?
    let superBowl: String?
}

@MainActor
final class NFLFuturesStore: ObservableObject {

    @Published var players: [NFLFuturesRow] = []
    @Published var admins: [NFLFuturesRow] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var playersListener: ListenerRegistration?
    private var adminsListener: ListenerRegistration?

    let bracketId: String

    /// Futures should be constant regardless of selected round.
    /// Your champs live under picks/wildcard, so we lock to wildcard.
    private let baseRoundId = "wildcard"

    init(bracketId: String) {
        self.bracketId = bracketId
        listen()
    }

    deinit {
        playersListener?.remove()
        adminsListener?.remove()
    }

    func listen() {
        isLoading = true
        errorMessage = nil

        let base = db.collection("brackets")
            .document(bracketId)
            .collection("picks")
            .document(baseRoundId)

        playersListener = base.collection("players")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    self.errorMessage = err.localizedDescription
                    self.isLoading = false
                    return
                }
                self.players = Self.parseRows(from: snap)
                self.isLoading = false
            }

        adminsListener = base.collection("admins")
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    self.errorMessage = err.localizedDescription
                    self.isLoading = false
                    return
                }
                self.admins = Self.parseRows(from: snap)
                self.isLoading = false
            }
    }

    private static func parseRows(from snap: QuerySnapshot?) -> [NFLFuturesRow] {
        let docs = snap?.documents ?? []
        return docs.map { d in
            let data = d.data()
            let champs = data["champs"] as? [String: Any] ?? [:]
            return NFLFuturesRow(
                id: d.documentID,
                displayName: data["displayName"] as? String ?? d.documentID,
                afc: champs["afc"] as? String,
                nfc: champs["nfc"] as? String,
                superBowl: champs["superBowl"] as? String
            )
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
