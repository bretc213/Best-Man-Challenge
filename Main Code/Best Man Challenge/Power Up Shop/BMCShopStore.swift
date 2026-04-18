import Foundation
import FirebaseFirestore


@MainActor
final class BMCShopStore: ObservableObject {
    @Published var items: [BMCCoinShopItem] = []
    @Published var myPurchases: [BMCCoinPurchase] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var itemsListener: ListenerRegistration?
    private var purchasesListener: ListenerRegistration?

    deinit {
        itemsListener?.remove()
        purchasesListener?.remove()
    }

    func start(playerId: String) {
        isLoading = true
        errorMessage = nil

        itemsListener?.remove()
        itemsListener = db.collection("coin_shop_items")
            .whereField("isActive", isEqualTo: true)
            .order(by: "sortOrder")
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                do {
                    self.items = try snap?.documents.compactMap { try $0.data(as: BMCCoinShopItem.self) } ?? []
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }

        purchasesListener?.remove()
        purchasesListener = db.collection("coin_purchases")
            .whereField("playerId", isEqualTo: playerId)
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                do {
                    self.myPurchases = try snap?.documents.compactMap { try $0.data(as: BMCCoinPurchase.self) } ?? []
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
    }

    func ownedCount(for itemId: String) -> Int {
        myPurchases.filter { $0.shopItemId == itemId && $0.status == .owned }.count
    }

    func purchase(
        item: BMCCoinShopItem,
        playerId: String,
        displayName: String
    ) async throws {
        guard let itemId = item.id else { return }

        let walletRef = db.collection("coin_wallets").document(playerId)
        let txRef = walletRef.collection("transactions").document()
        let purchaseRef = db.collection("coin_purchases").document()
        let itemRef = db.collection("coin_shop_items").document(itemId)

        try await db.runTransaction { transaction, errorPointer in
            do {
                let walletSnap = try transaction.getDocument(walletRef)
                let itemSnap = try transaction.getDocument(itemRef)

                let currentBalance = walletSnap.data()?["balance"] as? Int ?? 0
                let currentSpent = walletSnap.data()?["lifetimeSpent"] as? Int ?? 0
                let currentEarned = walletSnap.data()?["lifetimeEarned"] as? Int ?? 0
                let liveInventory = itemSnap.data()?["inventory"] as? Int
                let maxPerUser = itemSnap.data()?["maxPerUser"] as? Int

                if currentBalance < item.coinCost {
                    throw NSError(domain: "BMCShopStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not enough coins."])
                }

                let existingOwned = self.myPurchases.filter { $0.shopItemId == itemId && $0.status == .owned }.count
                if let maxPerUser, existingOwned >= maxPerUser {
                    throw NSError(domain: "BMCShopStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "You already own the max allowed for this power-up."])
                }

                if let liveInventory, liveInventory <= 0 {
                    throw NSError(domain: "BMCShopStore", code: 3, userInfo: [NSLocalizedDescriptionKey: "This item is sold out."])
                }

                let nextBalance = currentBalance - item.coinCost

                transaction.setData([
                    "playerId": playerId,
                    "displayName": displayName,
                    "balance": nextBalance,
                    "lifetimeEarned": currentEarned,
                    "lifetimeSpent": currentSpent + item.coinCost,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: walletRef, merge: true)

                transaction.setData([
                    "kind": BMCCoinTransactionKind.shopPurchase.rawValue,
                    "amount": -item.coinCost,
                    "balanceAfter": nextBalance,
                    "missionId": NSNull(),
                    "shopItemId": itemId,
                    "note": "Purchased \(item.title)",
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: txRef)

                transaction.setData([
                    "shopItemId": itemId,
                    "playerId": playerId,
                    "displayName": displayName,
                    "coinCost": item.coinCost,
                    "status": BMCPurchaseStatus.owned.rawValue,
                    "purchasedAt": FieldValue.serverTimestamp(),
                    "usedAt": NSNull(),
                    "usedInEventId": NSNull()
                ], forDocument: purchaseRef)

                if let liveInventory {
                    transaction.updateData([
                        "inventory": max(0, liveInventory - 1)
                    ], forDocument: itemRef)
                }
            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }
    }

    func markPurchaseUsed(purchaseId: String, eventId: String) async throws {
        try await db.collection("coin_purchases").document(purchaseId).updateData([
            "status": BMCPurchaseStatus.used.rawValue,
            "usedAt": FieldValue.serverTimestamp(),
            "usedInEventId": eventId
        ])
    }
}
