import Foundation
import FirebaseFirestore


// MARK: - Shared enums

enum BMCCoinMissionType: String, Codable, CaseIterable {
    case scavenger
    case fitness
    case social
    case daily
    case randomDrop
    case custom
}

enum BMCCoinProofType: String, Codable, CaseIterable {
    case none
    case photo
    case text
    case photoAndText
}

enum BMCCoinClaimStatus: String, Codable, CaseIterable {
    case pending
    case approved
    case denied
}

enum BMCCoinTransactionKind: String, Codable, CaseIterable {
    case missionReward
    case adminAdjustment
    case shopPurchase
    case refund
}

enum BMCPurchaseStatus: String, Codable, CaseIterable {
    case owned
    case used
    case refunded
}

// MARK: - Config

struct BMCCoinConfig: Codable {
    @DocumentID var id: String?
    var coinsEnabled: Bool = true
    var shopEnabled: Bool = true
    var missionsEnabled: Bool = true
    var randomDropsEnabled: Bool = true
    var randomDropMinHours: Int = 6
    var randomDropMaxHours: Int = 18
    var maxDailyMissionsShown: Int = 6
    var maxActiveRandomDrops: Int = 2
    var dailyResetHourLocal: Int = 5
    var currencyName: String = "Groom Bucks"
    var updatedAt: Timestamp?
}

// MARK: - Mission

struct BMCCoinMission: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var subtitle: String
    var type: BMCCoinMissionType
    var proofType: BMCCoinProofType
    var coinReward: Int
    var repeatable: Bool
    var repeatCadence: String
    var isActive: Bool
    var isTimed: Bool
    var sortOrder: Int
    var startsAt: Timestamp?
    var endsAt: Timestamp?
    var maxCompletionsTotal: Int?
    var maxCompletionsPerUser: Int?
    var requiresAdminApproval: Bool
    var tags: [String]

    var isCurrentlyAvailable: Bool {
        let now = Date()
        if !isActive { return false }
        if let startsAt, now < startsAt.dateValue() { return false }
        if let endsAt, now > endsAt.dateValue() { return false }
        return true
    }
}

// MARK: - Claim

struct BMCCoinMissionClaim: Codable, Identifiable {
    @DocumentID var id: String?
    var missionId: String
    var playerId: String
    var displayName: String
    var status: BMCCoinClaimStatus
    var proofType: BMCCoinProofType
    var proofText: String?
    var proofImageURL: String?
    var coinReward: Int
    var submittedAt: Timestamp?
    var reviewedAt: Timestamp?
    var reviewedBy: String?
}

// MARK: - Wallet

struct BMCCoinWallet: Codable, Identifiable {
    @DocumentID var id: String?
    var playerId: String
    var displayName: String
    var balance: Int
    var lifetimeEarned: Int
    var lifetimeSpent: Int
    var updatedAt: Timestamp?
}

struct BMCCoinTransaction: Codable, Identifiable {
    @DocumentID var id: String?
    var kind: BMCCoinTransactionKind
    var amount: Int
    var balanceAfter: Int
    var missionId: String?
    var shopItemId: String?
    var note: String?
    var createdAt: Timestamp?
}

// MARK: - Shop

struct BMCCoinShopItem: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var subtitle: String
    var category: String
    var coinCost: Int
    var inventory: Int?
    var isActive: Bool
    var sortOrder: Int
    var stackable: Bool
    var maxPerUser: Int?
    var requiresAdminActivation: Bool
    var rulesText: String
}

struct BMCCoinPurchase: Codable, Identifiable {
    @DocumentID var id: String?
    var shopItemId: String
    var playerId: String
    var displayName: String
    var coinCost: Int
    var status: BMCPurchaseStatus
    var purchasedAt: Timestamp?
    var usedAt: Timestamp?
    var usedInEventId: String?
}
