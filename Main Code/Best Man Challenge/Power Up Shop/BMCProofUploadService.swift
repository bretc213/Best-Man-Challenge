import Foundation
import UniformTypeIdentifiers
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

struct BMCUploadedProofMedia {
    let url: String
    let mediaType: BMCProofMediaType
    let fileName: String
}

enum BMCProofUploadError: LocalizedError {
    case storageNotInstalled
    case invalidData

    var errorDescription: String? {
        switch self {
        case .storageNotInstalled:
            return "FirebaseStorage is not added to this Xcode target. Add FirebaseStorage from the Firebase iOS SDK package to upload photos/videos."
        case .invalidData:
            return "Unable to read the selected proof file."
        }
    }
}

struct BMCProofUploadService {
    static func uploadProof(
        data: Data,
        playerId: String,
        missionId: String,
        fileExtension: String,
        contentType: String,
        mediaType: BMCProofMediaType
    ) async throws -> BMCUploadedProofMedia {
        guard !data.isEmpty else { throw BMCProofUploadError.invalidData }

        #if canImport(FirebaseStorage)
        let cleanPlayerId = playerId.replacingOccurrences(of: "/", with: "_")
        let cleanMissionId = missionId.replacingOccurrences(of: "/", with: "_")
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let path = "coin_mission_claim_proofs/\(cleanPlayerId)/\(cleanMissionId)/\(fileName)"
        let ref = Storage.storage().reference().child(path)

        let metadata = StorageMetadata()
        metadata.contentType = contentType

        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()

        return BMCUploadedProofMedia(
            url: url.absoluteString,
            mediaType: mediaType,
            fileName: fileName
        )
        #else
        throw BMCProofUploadError.storageNotInstalled
        #endif
    }
}
