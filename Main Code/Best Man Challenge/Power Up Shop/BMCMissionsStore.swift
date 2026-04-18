import Foundation
import FirebaseFirestore


@MainActor
final class BMCMissionsStore: ObservableObject {
    @Published var missions: [BMCCoinMission] = []
    @Published var myClaims: [BMCCoinMissionClaim] = []
    @Published var pendingClaims: [BMCCoinMissionClaim] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var missionListener: ListenerRegistration?
    private var myClaimsListener: ListenerRegistration?
    private var pendingClaimsListener: ListenerRegistration?

    deinit {
        missionListener?.remove()
        myClaimsListener?.remove()
        pendingClaimsListener?.remove()
    }

    func start(forPlayerId playerId: String, isAdmin: Bool) {
        isLoading = true
        errorMessage = nil

        missionListener?.remove()
        missionListener = db.collection("coin_missions")
            .order(by: "sortOrder")
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }
                self.isLoading = false
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                do {
                    self.missions = try snap?.documents.compactMap { try $0.data(as: BMCCoinMission.self) } ?? []
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }

        myClaimsListener?.remove()
        myClaimsListener = db.collection("coin_mission_claims")
            .whereField("playerId", isEqualTo: playerId)
            .addSnapshotListener { [weak self] snap, error in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                do {
                    self.myClaims = try snap?.documents.compactMap { try $0.data(as: BMCCoinMissionClaim.self) } ?? []
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }

        if isAdmin {
            pendingClaimsListener?.remove()
            pendingClaimsListener = db.collection("coin_mission_claims")
                .whereField("status", isEqualTo: BMCCoinClaimStatus.pending.rawValue)
                .addSnapshotListener { [weak self] snap, error in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    do {
                        self.pendingClaims = try snap?.documents.compactMap { try $0.data(as: BMCCoinMissionClaim.self) } ?? []
                    } catch {
                        self.errorMessage = error.localizedDescription
                    }
                }
        }
    }

    func hasApprovedClaim(for missionId: String) -> Bool {
        myClaims.contains { $0.missionId == missionId && $0.status == .approved }
    }

    func hasPendingClaim(for missionId: String) -> Bool {
        myClaims.contains { $0.missionId == missionId && $0.status == .pending }
    }

    func submitClaim(
        mission: BMCCoinMission,
        playerId: String,
        displayName: String,
        proofText: String? = nil,
        proofImageURL: String? = nil
    ) async throws {
        guard let missionId = mission.id else { return }

        let claimRef = db.collection("coin_mission_claims").document()
        let claim = BMCCoinMissionClaim(
            id: claimRef.documentID,
            missionId: missionId,
            playerId: playerId,
            displayName: displayName,
            status: .pending,
            proofType: mission.proofType,
            proofText: proofText,
            proofImageURL: proofImageURL,
            coinReward: mission.coinReward,
            submittedAt: Timestamp(date: Date()),
            reviewedAt: nil,
            reviewedBy: nil
        )

        try claimRef.setData(from: claim)
    }

    func approveClaim(
        claim: BMCCoinMissionClaim,
        reviewedBy: String,
        walletStore: BMCCoinWalletStore
    ) async throws {
        guard let claimId = claim.id else { return }

        let claimRef = db.collection("coin_mission_claims").document(claimId)
        let walletRef = db.collection("coin_wallets").document(claim.playerId)
        let txRef = walletRef.collection("transactions").document()

        try await db.runTransaction { transaction, errorPointer in
            do {
                let claimSnap = try transaction.getDocument(claimRef)
                let walletSnap = try transaction.getDocument(walletRef)

                let currentStatus = claimSnap.data()?["status"] as? String ?? BMCCoinClaimStatus.pending.rawValue
                if currentStatus == BMCCoinClaimStatus.approved.rawValue {
                    return nil
                }

                let currentBalance = walletSnap.data()?["balance"] as? Int ?? 0
                let lifetimeEarned = walletSnap.data()?["lifetimeEarned"] as? Int ?? 0
                let nextBalance = currentBalance + claim.coinReward

                transaction.updateData([
                    "status": BMCCoinClaimStatus.approved.rawValue,
                    "reviewedAt": FieldValue.serverTimestamp(),
                    "reviewedBy": reviewedBy
                ], forDocument: claimRef)

                transaction.setData([
                    "playerId": claim.playerId,
                    "displayName": claim.displayName,
                    "balance": nextBalance,
                    "lifetimeEarned": lifetimeEarned + claim.coinReward,
                    "lifetimeSpent": walletSnap.data()?["lifetimeSpent"] as? Int ?? 0,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: walletRef, merge: true)

                transaction.setData([
                    "kind": BMCCoinTransactionKind.missionReward.rawValue,
                    "amount": claim.coinReward,
                    "balanceAfter": nextBalance,
                    "missionId": claim.missionId,
                    "shopItemId": NSNull(),
                    "note": "Mission approved",
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: txRef)
            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }
    }

    func denyClaim(claim: BMCCoinMissionClaim, reviewedBy: String) async throws {
        guard let claimId = claim.id else { return }
        try await db.collection("coin_mission_claims").document(claimId).updateData([
            "status": BMCCoinClaimStatus.denied.rawValue,
            "reviewedAt": FieldValue.serverTimestamp(),
            "reviewedBy": reviewedBy
        ])
    }
}
