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
    case video
    case image
    case text
    case code
    case link
    case photoAndText
    case videoAndText
    case codeAndText
    case anyMedia

    var needsText: Bool {
        switch self {
        case .text, .photoAndText, .videoAndText, .codeAndText:
            return true
        default:
            return false
        }
    }

    var needsCode: Bool {
        switch self {
        case .code, .codeAndText:
            return true
        default:
            return false
        }
    }

    var needsMedia: Bool {
        switch self {
        case .photo, .video, .image, .photoAndText, .videoAndText, .anyMedia:
            return true
        default:
            return false
        }
    }
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

enum BMCProofMediaType: String, Codable, CaseIterable {
    case none
    case image
    case video
    case file
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

    // Saturday mission window. Calendar weekday: Sunday = 1, Saturday = 7.
    var missionWindowEnabled: Bool = true
    var missionWindowWeekday: Int = 7
    var missionWindowStartHourLocal: Int = 0
    var missionWindowEndHourLocal: Int = 24
    var missionWindowTitle: String = "Saturday Missions"
    var missionWindowClosedMessage: String = "Missions open every Saturday from 12:00 AM to 11:59 PM."

    // Info / rules screen.
    var rulesTitle: String = "Missions, Coins & Power-Ups"
    var rulesText: String = "Complete Saturday missions, submit proof, wait for admin review, and earn coins after approval. Spend coins in the shop for power-ups."
    var rulesVideoURL: String?

    var updatedAt: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id
        case coinsEnabled
        case shopEnabled
        case missionsEnabled
        case randomDropsEnabled
        case randomDropMinHours
        case randomDropMaxHours
        case maxDailyMissionsShown
        case maxActiveRandomDrops
        case dailyResetHourLocal
        case currencyName
        case missionWindowEnabled
        case missionWindowWeekday
        case missionWindowStartHourLocal
        case missionWindowEndHourLocal
        case missionWindowTitle
        case missionWindowClosedMessage
        case rulesTitle
        case rulesText
        case rulesVideoURL
        case updatedAt
    }

    init() { }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        coinsEnabled = try c.decodeIfPresent(Bool.self, forKey: .coinsEnabled) ?? true
        shopEnabled = try c.decodeIfPresent(Bool.self, forKey: .shopEnabled) ?? true
        missionsEnabled = try c.decodeIfPresent(Bool.self, forKey: .missionsEnabled) ?? true
        randomDropsEnabled = try c.decodeIfPresent(Bool.self, forKey: .randomDropsEnabled) ?? true
        randomDropMinHours = try c.decodeIfPresent(Int.self, forKey: .randomDropMinHours) ?? 6
        randomDropMaxHours = try c.decodeIfPresent(Int.self, forKey: .randomDropMaxHours) ?? 18
        maxDailyMissionsShown = try c.decodeIfPresent(Int.self, forKey: .maxDailyMissionsShown) ?? 6
        maxActiveRandomDrops = try c.decodeIfPresent(Int.self, forKey: .maxActiveRandomDrops) ?? 2
        dailyResetHourLocal = try c.decodeIfPresent(Int.self, forKey: .dailyResetHourLocal) ?? 5
        currencyName = try c.decodeIfPresent(String.self, forKey: .currencyName) ?? "Groom Bucks"
        missionWindowEnabled = try c.decodeIfPresent(Bool.self, forKey: .missionWindowEnabled) ?? true
        missionWindowWeekday = try c.decodeIfPresent(Int.self, forKey: .missionWindowWeekday) ?? 7
        missionWindowStartHourLocal = try c.decodeIfPresent(Int.self, forKey: .missionWindowStartHourLocal) ?? 0
        missionWindowEndHourLocal = try c.decodeIfPresent(Int.self, forKey: .missionWindowEndHourLocal) ?? 24
        missionWindowTitle = try c.decodeIfPresent(String.self, forKey: .missionWindowTitle) ?? "Saturday Missions"
        missionWindowClosedMessage = try c.decodeIfPresent(String.self, forKey: .missionWindowClosedMessage) ?? "Missions open every Saturday from 12:00 AM to 11:59 PM."
        rulesTitle = try c.decodeIfPresent(String.self, forKey: .rulesTitle) ?? "Missions, Coins & Power-Ups"
        rulesText = try c.decodeIfPresent(String.self, forKey: .rulesText) ?? "Complete Saturday missions, submit proof, wait for admin review, and earn coins after approval. Spend coins in the shop for power-ups."
        rulesVideoURL = try c.decodeIfPresent(String.self, forKey: .rulesVideoURL)
        updatedAt = try c.decodeIfPresent(Timestamp.self, forKey: .updatedAt)
    }

    var isMissionWindowOpenNow: Bool {
        guard missionWindowEnabled else { return true }

        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)

        guard weekday == missionWindowWeekday else { return false }

        let startHour = max(0, min(23, missionWindowStartHourLocal))
        let endHour = max(1, min(24, missionWindowEndHourLocal))

        return hour >= startHour && hour < endHour
    }
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
    var missionTitle: String?
    var playerId: String
    var displayName: String
    var status: BMCCoinClaimStatus
    var proofType: BMCCoinProofType
    var proofText: String?
    var proofCode: String?
    var proofImageURL: String?
    var proofMediaURL: String?
    var proofMediaType: BMCProofMediaType?
    var proofFileName: String?
    var coinReward: Int
    var submittedAt: Timestamp?
    var reviewedAt: Timestamp?
    var reviewedBy: String?
    var adminNote: String?
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
