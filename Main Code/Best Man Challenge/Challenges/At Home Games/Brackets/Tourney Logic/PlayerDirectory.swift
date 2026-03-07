import Foundation
import FirebaseFirestore

/// Lightweight helper to resolve playerId -> display name.
/// Primary source: /players/{playerId}.display_name
/// Fallback: /users/{uid}.display_name (not used here because we generally only have playerIds in tourney docs).
final class PlayerDirectory {
    private let db = Firestore.firestore()

    func fetchDisplayNames(playerIds: [String]) async -> [String: String] {
        let unique = Array(Set(playerIds)).filter { !$0.isEmpty }
        guard !unique.isEmpty else { return [:] }

        var results: [String: String] = [:]

        await withTaskGroup(of: (String, String?).self) { group in
            for pid in unique {
                group.addTask { [db] in
                    do {
                        let snap = try await db.collection("players").document(pid).getDocument()
                        let name = snap.data()?["display_name"] as? String
                        return (pid, name)
                    } catch {
                        return (pid, nil)
                    }
                }
            }

            for await (pid, name) in group {
                if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    results[pid] = name
                }
            }
        }

        return results
    }
}
