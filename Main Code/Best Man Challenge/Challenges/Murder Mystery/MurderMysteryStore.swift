//
//  MurderMysteryStore.swift
//  Best Man Challenge
//
//  "Dead in the Dust" — local state (AppStorage only, no Firestore)
//

import SwiftUI

@MainActor
final class MurderMysteryStore: ObservableObject {

    @AppStorage("mm_week")     var currentWeek: Int = 0
    @AppStorage("mm_points")   var points: Int = 0
    @AppStorage("mm_chSolved") var challengesSolved: Int = 0
    @AppStorage("mm_history")  var historyData: Data = Data()
    @AppStorage("mm_done")     var doneData: Data = Data()

    // MARK: - Decoded accessors

    var history: [AccusationEntry] {
        (try? JSONDecoder().decode([AccusationEntry].self, from: historyData)) ?? []
    }

    var completedChallengeIDs: Set<String> {
        Set((try? JSONDecoder().decode([String].self, from: doneData)) ?? [])
    }

    var currentMultiplier: Double {
        MurderMysteryData.multiplier(forWeek: currentWeek)
    }

    var hasAccusedThisWeek: Bool {
        history.contains { $0.week == currentWeek }
    }

    /// Accusation results stay sealed until the finale (Week 13).
    var isFinaleRevealed: Bool {
        currentWeek >= MurderMysteryData.finalWeek
    }

    /// Accusation points only count toward the total once the finale reveals them.
    var revealedAccusationPoints: Int {
        guard isFinaleRevealed else { return 0 }
        return history.reduce(0) { $0 + $1.pointsAwarded }
    }

    /// Challenge points + (revealed) accusation points.
    var totalPoints: Int {
        points + revealedAccusationPoints
    }

    func lastAccusation(before week: Int) -> AccusationEntry? {
        history.filter { $0.week < week }.max { $0.week < $1.week }
    }

    // MARK: - Week control (admin)

    func advanceWeek() {
        guard currentWeek < MurderMysteryData.finalWeek else { return }
        objectWillChange.send()
        currentWeek += 1
    }

    func setWeek(_ week: Int) {
        objectWillChange.send()
        currentWeek = min(max(week, 0), MurderMysteryData.finalWeek)
    }

    func resetAll() {
        objectWillChange.send()
        currentWeek = 0
        points = 0
        challengesSolved = 0
        historyData = Data()
        doneData = Data()
    }

    // MARK: - Challenges

    func isChallengeComplete(_ id: String) -> Bool {
        completedChallengeIDs.contains(id)
    }

    func markChallengeComplete(id: String, pts: Int) {
        guard !completedChallengeIDs.contains(id) else { return }
        objectWillChange.send()
        var done = completedChallengeIDs
        done.insert(id)
        if let encoded = try? JSONEncoder().encode(Array(done)) {
            doneData = encoded
        }
        points += pts
        challengesSolved += 1
    }

    // MARK: - Accusations

    /// Records the weekly accusation. Points are calculated against the hidden
    /// solution (100 pts per correct variable × week multiplier) but stay SEALED —
    /// they are not shown or added to the total until the finale (Week 13).
    /// Double-down flags are stored unresolved; their bonus/penalty resolves at finale.
    func submitAccusation(killer: String, weapon: String, location: String,
                          ddKiller: Bool, ddWeapon: Bool, ddLocation: Bool) {
        objectWillChange.send()
        let mult = currentMultiplier
        let base = 100.0
        var awarded = 0.0
        if mmNormalize(killer) == mmNormalize(MurderMysteryData.solutionKiller)     { awarded += base * mult }
        if mmNormalize(weapon) == mmNormalize(MurderMysteryData.solutionWeapon)     { awarded += base * mult }
        if mmNormalize(location) == mmNormalize(MurderMysteryData.solutionLocation) { awarded += base * mult }

        let entry = AccusationEntry(
            id: UUID(),
            week: currentWeek,
            killer: killer,
            weapon: weapon,
            location: location,
            pointsAwarded: Int(awarded.rounded()),
            multiplier: mult,
            doubleDownKiller: ddKiller,
            doubleDownWeapon: ddWeapon,
            doubleDownLocation: ddLocation
        )

        var entries = history
        entries.append(entry)
        if let encoded = try? JSONEncoder().encode(entries) {
            historyData = encoded
        }
        // Sealed: accusation points surface via totalPoints only at the finale.
    }
}
