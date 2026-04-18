import Foundation
import FirebaseFirestore


@MainActor
final class BMCCoinWalletStore: ObservableObject {
    @Published var wallet: BMCCoinWallet?
    @Published var transactions: [BMCCoinTransaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var walletListener: ListenerRegistration?
    private var txListener: ListenerRegistration?

    deinit {
        walletListener?.remove()
        txListener?.remove()
    }

    func start(playerId: String, displayName: String) {
        isLoading = true
        errorMessage = nil

        ensureWalletExists(playerId: playerId, displayName: displayName)

        walletListener?.remove()
        walletListener = db.collection("coin_wallets")
            .document(playerId)
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                do {
                    self.wallet = try snap?.data(as: BMCCoinWallet.self)
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }

        txListener?.remove()
        txListener = db.collection("coin_wallets")
            .document(playerId)
            .collection("transactions")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                do {
                    self.transactions = try snap?.documents.compactMap { try $0.data(as: BMCCoinTransaction.self) } ?? []
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
    }

    func ensureWalletExists(playerId: String, displayName: String) {
        db.collection("coin_wallets").document(playerId).setData([
            "playerId": playerId,
            "displayName": displayName,
            "balance": 0,
            "lifetimeEarned": 0,
            "lifetimeSpent": 0,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func adminAdjust(
        playerId: String,
        displayName: String,
        amount: Int,
        note: String
    ) async throws {
        let walletRef = db.collection("coin_wallets").document(playerId)
        let txRef = walletRef.collection("transactions").document()

        try await db.runTransaction { transaction, errorPointer in
            do {
                let walletSnap = try transaction.getDocument(walletRef)
                let currentBalance = walletSnap.data()?["balance"] as? Int ?? 0
                let currentEarned = walletSnap.data()?["lifetimeEarned"] as? Int ?? 0
                let currentSpent = walletSnap.data()?["lifetimeSpent"] as? Int ?? 0
                let nextBalance = max(0, currentBalance + amount)

                var nextEarned = currentEarned
                var nextSpent = currentSpent
                if amount >= 0 {
                    nextEarned += amount
                } else {
                    nextSpent += abs(amount)
                }

                transaction.setData([
                    "playerId": playerId,
                    "displayName": displayName,
                    "balance": nextBalance,
                    "lifetimeEarned": nextEarned,
                    "lifetimeSpent": nextSpent,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: walletRef, merge: true)

                transaction.setData([
                    "kind": BMCCoinTransactionKind.adminAdjustment.rawValue,
                    "amount": amount,
                    "balanceAfter": nextBalance,
                    "missionId": NSNull(),
                    "shopItemId": NSNull(),
                    "note": note,
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: txRef)
            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }
    }
}
