//
//  WordlePropFields.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 2/16/26.
//


import Foundation
import FirebaseFirestore

/// Minimal Wordle fields living on the "prop" doc.
/// Designed to be merged into your existing Prop/WeeklyProp model.
///
/// If your existing Prop already decodes Firestore docs,
/// copy these fields + CodingKeys into it instead of using a separate struct.
struct WordlePropFields: Codable {
    var wordLength: Int?
    var maxAttempts: Int?
    var answer: String?

    enum CodingKeys: String, CodingKey {
        case wordLength = "word_length"
        case maxAttempts = "max_attempts"
        case answer
    }
}

/// Utility: tolerate Firestore values that might be missing or NSNull.
/// If your model already does custom decoding, you may not need this.
extension KeyedDecodingContainer {
    func decodeIfPresentSafeString(_ key: Key) -> String? {
        // Normal decodeIfPresent(String.self, forKey:) is usually enough.
        // This helper exists in case you store "" or omit the field.
        return try? decodeIfPresent(String.self, forKey: key)
    }
}
