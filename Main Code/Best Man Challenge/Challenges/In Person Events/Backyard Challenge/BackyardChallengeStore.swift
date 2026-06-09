import Foundation
import FirebaseFirestore

@MainActor
final class BackyardChallengeStore: ObservableObject {

    @Published var players: [BackyardPlayer] = BackyardPlayer.defaults

    @Published var golfHoleScores: [Int: [String: Int]] = [:]
    // Audit/verification scorecards keyed by scorerId, then hole, then playerId.
    // These DO NOT feed the live golf leaderboard unless scorerId == playerId.
    @Published var golfGroupScorecards: [String: [Int: [String: Int]]] = [:]
    @Published var golfRefreshToken = UUID()

    // 18-hole Bucket Golf par card. Change these if any hole is not par 3.
    // Leaderboard uses this to show E / + / - correctly.
    @Published var bucketGolf18Pars: [Int: Int] = Dictionary(uniqueKeysWithValues: (1...18).map { ($0, 3) })
    @Published var dekaRoundScores: [Int: [String: Int]] = [:]
    @Published var finalScoresByGame: [BackyardGameId: [String: Double]] = [:]
    @Published var relayTeamSeconds: [String: Double] = [:]
    @Published var relaySplits: [String: [String: Double]] = [:]

    @Published var closestMulligans: [String: Int] = [:]
    @Published var closestEliminatedPlaces: [String: Int] = [:]
    @Published var closestByHole: [Int: String] = [:]
    @Published var furthestByHole: [Int: String] = [:]

    @Published var cornholeSinglesWinners: [CornholeSinglesBracket: [String: String]] = [:]

    /// Direct bracket placements: bracket → [playerId: place (1-4)]
    /// This is the simplified replacement for game-by-game bracket tracking.
    @Published var cornholeSinglesDirectPlacements: [CornholeSinglesBracket: [String: Int]] = [:]

    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []

    // Keeps picker changes from snapping back when Firestore briefly sends an older snapshot.
    // Key format is "hole|playerId". value == nil means the pending change is a clear/dash.
    private struct PendingGolfWrite {
        let value: Int?
    }
    private var pendingGolfHoleScoreOverrides: [String: PendingGolfWrite] = [:]

    let eventId: String

    init(eventId: String) {
        self.eventId = eventId
        self.closestMulligans = Dictionary(
            uniqueKeysWithValues: BackyardPlayer.defaults.map { ($0.id, 1) }
        )
    }

    deinit {
        listeners.forEach { $0.remove() }
    }

    var eventRef: DocumentReference {
        db.collection("backyard_challenge_events").document(eventId)
    }

    private func gameRef(_ gameId: BackyardGameId) -> DocumentReference {
        eventRef.collection("games").document(gameId.rawValue)
    }

    private func golfPendingKey(hole: Int, playerId: String) -> String {
        "\(hole)|\(playerId)"
    }

    private func applyGolfSnapshot(_ firestoreScores: [Int: [String: Int]]) {
        var merged = firestoreScores
        var stillPending: [String: PendingGolfWrite] = [:]

        for (key, pending) in pendingGolfHoleScoreOverrides {
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2, let hole = Int(parts[0]) else { continue }
            let playerId = parts[1]

            let firestoreValue = firestoreScores[hole]?[playerId]

            // If Firestore has caught up to the local value, the pending write is confirmed.
            if firestoreValue == pending.value {
                continue
            }

            // Firestore has not caught up yet. Keep showing the local value so the picker does not bounce back.
            stillPending[key] = pending
            var holeScores = merged[hole] ?? [:]
            if let value = pending.value {
                holeScores[playerId] = value
            } else {
                holeScores.removeValue(forKey: playerId)
            }
            merged[hole] = holeScores
        }

        pendingGolfHoleScoreOverrides = stillPending
        golfHoleScores = merged
        golfRefreshToken = UUID()
    }

    func bootstrapIfNeeded() async {
        do {
            try await eventRef.setData([
                "title": "Backyard Challenge",
                "status": "setup",
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            try await seedClosestIfNeeded()
        } catch {
            print("❌ Backyard bootstrap failed:", error.localizedDescription)
        }
    }

    func startListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()

        listenGolf18()
        listenGolfGroupScorecards()
        listenDeka()
        listenFinalScores()
        listenRelay()
        listenClosestToPin()
        listenCornholeSingles()
        listenCornholeSinglesDirectPlacements()
    }

    private func listenGolf18() {
        let ref = gameRef(.bucketGolfInd18).collection("hole_scores")

        let listener = ref.addSnapshotListener { [weak self] snap, error in
            guard let self else { return }

            if let error {
                print("❌ listenGolf18:", error.localizedDescription)
                return
            }

            var next: [Int: [String: Int]] = [:]

            for doc in snap?.documents ?? [] {
                let data = doc.data()
                let hole = data["hole"] as? Int ?? Int(doc.documentID) ?? 0
                let rawScores = data["scores"] as? [String: Any] ?? [:]

                var scores: [String: Int] = [:]

                for (playerId, value) in rawScores {
                    if let intValue = value as? Int {
                        scores[playerId] = intValue
                    } else if let int64Value = value as? Int64 {
                        scores[playerId] = Int(int64Value)
                    } else if let doubleValue = value as? Double {
                        scores[playerId] = Int(doubleValue)
                    } else if let numberValue = value as? NSNumber {
                        scores[playerId] = numberValue.intValue
                    }
                }

                next[hole] = scores
            }

            Task { @MainActor in
                self.applyGolfSnapshot(next)
            }
        }

        listeners.append(listener)
    }


    private func listenGolfGroupScorecards() {
        let ref = gameRef(.bucketGolfInd18).collection("group_scorecards")

        let listener = ref.addSnapshotListener { [weak self] snap, error in
            guard let self else { return }

            if let error {
                print("❌ listenGolfGroupScorecards:", error.localizedDescription)
                return
            }

            var next: [String: [Int: [String: Int]]] = [:]

            for doc in snap?.documents ?? [] {
                let scorerId = doc.documentID
                let data = doc.data()
                let rawHoleScores = data["holeScores"] as? [String: Any] ?? [:]
                var holes: [Int: [String: Int]] = [:]

                for (holeText, rawScoresAny) in rawHoleScores {
                    guard let hole = Int(holeText) else { continue }
                    let rawScores = rawScoresAny as? [String: Any] ?? [:]
                    var scores: [String: Int] = [:]

                    for (playerId, value) in rawScores {
                        if let intValue = value as? Int {
                            scores[playerId] = intValue
                        } else if let int64Value = value as? Int64 {
                            scores[playerId] = Int(int64Value)
                        } else if let doubleValue = value as? Double {
                            scores[playerId] = Int(doubleValue)
                        } else if let numberValue = value as? NSNumber {
                            scores[playerId] = numberValue.intValue
                        }
                    }

                    holes[hole] = scores
                }

                next[scorerId] = holes
            }

            Task { @MainActor in
                self.golfGroupScorecards = next
                self.golfRefreshToken = UUID()
            }
        }

        listeners.append(listener)
    }

    private func listenDeka() {
        let ref = gameRef(.cornholeDeka).collection("round_scores")

        let listener = ref.addSnapshotListener { [weak self] snap, error in
            guard let self else { return }

            if let error {
                print("❌ listenDeka:", error.localizedDescription)
                return
            }

            var next: [Int: [String: Int]] = [:]

            for doc in snap?.documents ?? [] {
                let data = doc.data()
                let round = data["round"] as? Int ?? Int(doc.documentID) ?? 0
                let rawScores = data["scores"] as? [String: Any] ?? [:]

                var scores: [String: Int] = [:]

                for (playerId, value) in rawScores {
                    if let intValue = value as? Int {
                        scores[playerId] = intValue
                    } else if let doubleValue = value as? Double {
                        scores[playerId] = Int(doubleValue)
                    }
                }

                next[round] = scores
            }

            Task { @MainActor in
                self.dekaRoundScores = next
            }
        }

        listeners.append(listener)
    }

    private func listenFinalScores() {
        let games = BackyardGameId.allCases.filter { $0.usesFinalScoreInput }

        for game in games {
            let ref = gameRef(game)
                .collection("final_scores")
                .document("results")

            let listener = ref.addSnapshotListener { [weak self] snap, error in
                guard let self else { return }

                if let error {
                    print("❌ listenFinalScores \(game.rawValue):", error.localizedDescription)
                    return
                }

                let rawScores = snap?.data()?["scores"] as? [String: Any] ?? [:]
                var scores: [String: Double] = [:]

                for (playerId, value) in rawScores {
                    if let doubleValue = value as? Double {
                        scores[playerId] = doubleValue
                    } else if let intValue = value as? Int {
                        scores[playerId] = Double(intValue)
                    }
                }

                Task { @MainActor in
                    self.finalScoresByGame[game] = scores
                }
            }

            listeners.append(listener)
        }
    }

    private func listenRelay() {
        let ref = gameRef(.relayRace)
            .collection("team_results")
            .document("results")

        let listener = ref.addSnapshotListener { [weak self] snap, error in
            guard let self else { return }

            if let error {
                print("❌ listenRelay:", error.localizedDescription)
                return
            }

            let rawTeams = snap?.data()?["teams"] as? [String: [String: Any]] ?? [:]

            var teamSeconds: [String: Double] = [:]
            var splits: [String: [String: Double]] = [:]

            for (teamId, payload) in rawTeams {
                if let total = payload["totalSeconds"] as? Double {
                    teamSeconds[teamId] = total
                } else if let total = payload["totalSeconds"] as? Int {
                    teamSeconds[teamId] = Double(total)
                }

                let rawSplits = payload["splits"] as? [String: Any] ?? [:]
                var convertedSplits: [String: Double] = [:]

                for (playerId, value) in rawSplits {
                    if let doubleValue = value as? Double {
                        convertedSplits[playerId] = doubleValue
                    } else if let intValue = value as? Int {
                        convertedSplits[playerId] = Double(intValue)
                    }
                }

                splits[teamId] = convertedSplits
            }

            Task { @MainActor in
                self.relayTeamSeconds = teamSeconds
                self.relaySplits = splits
            }
        }

        listeners.append(listener)
    }

    private func listenClosestToPin() {
        let ref = gameRef(.bucketGolfClosest)
            .collection("state")
            .document("current")

        let listener = ref.addSnapshotListener { [weak self] snap, error in
            guard let self else { return }

            if let error {
                print("❌ listenClosestToPin:", error.localizedDescription)
                return
            }

            let data = snap?.data() ?? [:]

            let mulligansRaw = data["mulligans"] as? [String: Any] ?? [:]
            let placesRaw = data["eliminatedPlaces"] as? [String: Any] ?? [:]
            let closestRaw = data["holeClosest"] as? [String: Any] ?? [:]
            let furthestRaw = data["holeFurthest"] as? [String: Any] ?? [:]

            var mulligans = Dictionary(uniqueKeysWithValues: self.players.map { ($0.id, 1) })
            var places: [String: Int] = [:]
            var closest: [Int: String] = [:]
            var furthest: [Int: String] = [:]

            for (playerId, value) in mulligansRaw {
                if let intValue = value as? Int {
                    mulligans[playerId] = intValue
                } else if let doubleValue = value as? Double {
                    mulligans[playerId] = Int(doubleValue)
                }
            }

            for (playerId, value) in placesRaw {
                if let intValue = value as? Int {
                    places[playerId] = intValue
                } else if let doubleValue = value as? Double {
                    places[playerId] = Int(doubleValue)
                }
            }

            for (holeText, value) in closestRaw {
                if let hole = Int(holeText), let playerId = value as? String {
                    closest[hole] = playerId
                }
            }

            for (holeText, value) in furthestRaw {
                if let hole = Int(holeText), let playerId = value as? String {
                    furthest[hole] = playerId
                }
            }

            Task { @MainActor in
                self.closestMulligans = mulligans
                self.closestEliminatedPlaces = places
                self.closestByHole = closest
                self.furthestByHole = furthest
            }
        }

        listeners.append(listener)
    }

    private func listenCornholeSingles() {
        for bracket in CornholeSinglesBracket.allCases {
            let ref = gameRef(.cornholeSingles)
                .collection("brackets")
                .document(bracket.rawValue)

            let listener = ref.addSnapshotListener { [weak self] snap, error in
                guard let self else { return }

                if let error {
                    print("❌ listenCornholeSingles:", error.localizedDescription)
                    return
                }

                let winners = snap?.data()?["gameWinners"] as? [String: String] ?? [:]

                Task { @MainActor in
                    self.cornholeSinglesWinners[bracket] = winners
                }
            }

            listeners.append(listener)
        }
    }

    /// Score shown in the dropdown for a scorer entering a player.
    /// Self-score comes from `hole_scores` and feeds the live leaderboard.
    /// Non-self score comes from `group_scorecards` and is audit-only.
    private func listenCornholeSinglesDirectPlacements() {
        for bracket in CornholeSinglesBracket.allCases {
            let ref = gameRef(.cornholeSingles)
                .collection("direct_placements")
                .document(bracket.rawValue)

            let listener = ref.addSnapshotListener { [weak self] snap, error in
                guard let self else { return }

                if let error {
                    print("❌ listenCornholeSinglesDirectPlacements:", error.localizedDescription)
                    return
                }

                let raw = snap?.data()?["placements"] as? [String: Any] ?? [:]
                var placements: [String: Int] = [:]

                for (playerId, value) in raw {
                    if let intValue = value as? Int {
                        placements[playerId] = intValue
                    } else if let doubleValue = value as? Double {
                        placements[playerId] = Int(doubleValue)
                    }
                }

                Task { @MainActor in
                    self.cornholeSinglesDirectPlacements[bracket] = placements
                }
            }

            listeners.append(listener)
        }
    }

    func saveCornholeSingleDirectPlacement(bracket: CornholeSinglesBracket, playerId: String, place: Int) async {
        // Optimistic local update
        var local = cornholeSinglesDirectPlacements[bracket] ?? [:]
        local[playerId] = place
        cornholeSinglesDirectPlacements[bracket] = local

        let ref = gameRef(.cornholeSingles)
            .collection("direct_placements")
            .document(bracket.rawValue)

        do {
            try await ref.setData([
                "placements.\(playerId)": place,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("❌ saveCornholeSingleDirectPlacement \(bracket.rawValue) \(playerId):", error.localizedDescription)
            // Roll back
            var rollback = cornholeSinglesDirectPlacements[bracket] ?? [:]
            rollback.removeValue(forKey: playerId)
            cornholeSinglesDirectPlacements[bracket] = rollback
        }
    }

    func bucketGolfDisplayedScore(scorerId: String, playerId: String, hole: Int) -> Int? {
        if scorerId == playerId {
            return golfHoleScores[hole]?[playerId]
        }

        return golfGroupScorecards[scorerId]?[hole]?[playerId]
    }

    /// Picker value used by the 18-hole input screen.
    /// -1 means "not entered" so the UI can show a dash.
    /// 0 is a real possible Bucket Golf score and should be saved.
    func bucketGolfPickerValue(scorerId: String, playerId: String, hole: Int) -> Int {
        bucketGolfDisplayedScore(scorerId: scorerId, playerId: playerId, hole: hole) ?? -1
    }

    func updateBucketGolfScore(scorerId: String, playerId: String, hole: Int, strokes: Int) {
        if scorerId == playerId {
            updateGolfHoleScore(hole: hole, playerId: playerId, strokes: strokes)
        } else {
            updateGolfAuditScore(scorerId: scorerId, playerId: playerId, hole: hole, strokes: strokes)
        }
    }

    func clearBucketGolfScore(scorerId: String, playerId: String, hole: Int) {
        if scorerId == playerId {
            clearGolfHoleScore(hole: hole, playerId: playerId)
        } else {
            clearGolfAuditScore(scorerId: scorerId, playerId: playerId, hole: hole)
        }
    }

    private func updateGolfAuditScore(scorerId: String, playerId: String, hole: Int, strokes: Int) {
        guard (1...18).contains(hole), (0...15).contains(strokes) else { return }

        var next = golfGroupScorecards
        var scorerScores = next[scorerId] ?? [:]
        var holeScores = scorerScores[hole] ?? [:]
        holeScores[playerId] = strokes
        scorerScores[hole] = holeScores
        next[scorerId] = scorerScores
        golfGroupScorecards = next
        golfRefreshToken = UUID()

        Task {
            await writeGolfAuditScoreToFirestore(scorerId: scorerId, playerId: playerId, hole: hole, strokes: strokes)
        }
    }

    private func clearGolfAuditScore(scorerId: String, playerId: String, hole: Int) {
        guard (1...18).contains(hole) else { return }

        var next = golfGroupScorecards
        var scorerScores = next[scorerId] ?? [:]
        var holeScores = scorerScores[hole] ?? [:]
        holeScores.removeValue(forKey: playerId)
        scorerScores[hole] = holeScores
        next[scorerId] = scorerScores
        golfGroupScorecards = next
        golfRefreshToken = UUID()

        Task {
            await clearGolfAuditScoreFromFirestore(scorerId: scorerId, playerId: playerId, hole: hole)
        }
    }

    private func writeGolfAuditScoreToFirestore(scorerId: String, playerId: String, hole: Int, strokes: Int) async {
        let ref = gameRef(.bucketGolfInd18)
            .collection("group_scorecards")
            .document(scorerId)

        do {
            try await ref.setData([
                "scorerId": scorerId,
                "groupPlayerIds": BackyardPlayer.bucketGolfGroupPlayerIds(for: scorerId),
                "holeScores.\(hole).\(playerId)": strokes,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("❌ writeGolfAuditScoreToFirestore:", error.localizedDescription)
        }
    }

    private func clearGolfAuditScoreFromFirestore(scorerId: String, playerId: String, hole: Int) async {
        let ref = gameRef(.bucketGolfInd18)
            .collection("group_scorecards")
            .document(scorerId)

        do {
            try await ref.setData([
                "scorerId": scorerId,
                "groupPlayerIds": BackyardPlayer.bucketGolfGroupPlayerIds(for: scorerId),
                "holeScores.\(hole).\(playerId)": FieldValue.delete(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("❌ clearGolfAuditScoreFromFirestore:", error.localizedDescription)
        }
    }

    func golfScore(for playerId: String, hole: Int) -> Int {
        golfHoleScores[hole]?[playerId] ?? 0
    }

    /// Picker value used by the 18-hole input screen.
    /// -1 means "not entered" so the UI can show a dash.
    /// 0 is a real possible Bucket Golf score and should be saved.
    func golfScorePickerValue(for playerId: String, hole: Int) -> Int {
        golfHoleScores[hole]?[playerId] ?? -1
    }

    func bucketGolfPar(for hole: Int) -> Int {
        bucketGolf18Pars[hole] ?? 3
    }

    func bucketGolfParThrough(_ hole: Int) -> Int {
        guard hole > 0 else { return 0 }
        return (1...min(hole, 18)).reduce(0) { $0 + bucketGolfPar(for: $1) }
    }

    /// Use this from the UI. It updates the local @Published state immediately,
    /// then writes the same value to Firestore in the background.
    func updateGolfHoleScore(hole: Int, playerId: String, strokes: Int) {
        guard (1...18).contains(hole), (0...15).contains(strokes) else { return }

        let key = golfPendingKey(hole: hole, playerId: playerId)
        pendingGolfHoleScoreOverrides[key] = PendingGolfWrite(value: strokes)

        // Force a brand-new Dictionary assignment so SwiftUI redraws immediately.
        var nextScores = golfHoleScores
        var holeScores = nextScores[hole] ?? [:]
        holeScores[playerId] = strokes
        nextScores[hole] = holeScores

        objectWillChange.send()
        golfHoleScores = nextScores
        golfRefreshToken = UUID()

        Task {
            await writeGolfHoleScoreToFirestore(hole: hole, playerId: playerId, strokes: strokes)
            // Pending value is cleared only after the Firestore listener confirms it.
        }
    }


    /// Use the dash option from the dropdown as "no score yet". This removes the score locally
    /// and from Firestore so the hole does not count as played. A score of 0 is valid and saved.
    func clearGolfHoleScore(hole: Int, playerId: String) {
        guard (1...18).contains(hole) else { return }

        let key = golfPendingKey(hole: hole, playerId: playerId)
        pendingGolfHoleScoreOverrides[key] = PendingGolfWrite(value: nil)

        var nextScores = golfHoleScores
        var holeScores = nextScores[hole] ?? [:]
        holeScores.removeValue(forKey: playerId)
        nextScores[hole] = holeScores
        golfHoleScores = nextScores
        golfRefreshToken = UUID()

        Task {
            await clearGolfHoleScoreFromFirestore(hole: hole, playerId: playerId)
            await reloadGolf18ScoresFromFirestore()
            // Pending value is cleared only after the Firestore listener confirms it.
        }
    }

    private func clearGolfHoleScoreFromFirestore(hole: Int, playerId: String) async {
        let ref = gameRef(.bucketGolfInd18)
            .collection("hole_scores")
            .document("\(hole)")

        do {
            try await ref.setData([
                "hole": hole,
                "scores.\(playerId)": FieldValue.delete(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("❌ clearGolfHoleScoreFromFirestore:", error.localizedDescription)
        }
    }

    /// Kept for older views/admin tools that may still call the async save directly.
    func saveGolfHoleScore(hole: Int, playerId: String, strokes: Int) async {
        guard (1...18).contains(hole), (0...15).contains(strokes) else { return }

        let key = golfPendingKey(hole: hole, playerId: playerId)
        pendingGolfHoleScoreOverrides[key] = PendingGolfWrite(value: strokes)

        var nextScores = golfHoleScores
        var holeScores = nextScores[hole] ?? [:]
        holeScores[playerId] = strokes
        nextScores[hole] = holeScores
        golfHoleScores = nextScores
        golfRefreshToken = UUID()

        await writeGolfHoleScoreToFirestore(hole: hole, playerId: playerId, strokes: strokes)
        // Pending value is cleared only after the Firestore listener confirms it.
    }

    private func writeGolfHoleScoreToFirestore(hole: Int, playerId: String, strokes: Int) async {
        let ref = gameRef(.bucketGolfInd18)
            .collection("hole_scores")
            .document("\(hole)")

        do {
            try await ref.setData([
                "hole": hole,
                "scores.\(playerId)": strokes,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("❌ writeGolfHoleScoreToFirestore:", error.localizedDescription)
        }
    }

    func reloadGolf18ScoresFromFirestore() async {
        let ref = gameRef(.bucketGolfInd18).collection("hole_scores")

        do {
            let snap = try await ref.getDocuments()
            var next: [Int: [String: Int]] = [:]

            for doc in snap.documents {
                let data = doc.data()
                let hole = data["hole"] as? Int ?? Int(doc.documentID) ?? 0
                let rawScores = data["scores"] as? [String: Any] ?? [:]

                var scores: [String: Int] = [:]

                for (playerId, value) in rawScores {
                    if let intValue = value as? Int {
                        scores[playerId] = intValue
                    } else if let int64Value = value as? Int64 {
                        scores[playerId] = Int(int64Value)
                    } else if let doubleValue = value as? Double {
                        scores[playerId] = Int(doubleValue)
                    } else if let numberValue = value as? NSNumber {
                        scores[playerId] = numberValue.intValue
                    }
                }

                next[hole] = scores
            }

            applyGolfSnapshot(next)
        } catch {
            print("❌ reloadGolf18ScoresFromFirestore:", error.localizedDescription)
        }
    }

    func saveDekaScore(round: Int, playerId: String, score: Int) async {
        let ref = gameRef(.cornholeDeka)
            .collection("round_scores")
            .document("\(round)")

        do {
            try await ref.setData([
                "round": round,
                "scores.\(playerId)": score,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            var local = dekaRoundScores
            var roundScores = local[round] ?? [:]
            roundScores[playerId] = score
            local[round] = roundScores
            dekaRoundScores = local
        } catch {
            print("❌ saveDekaScore:", error.localizedDescription)
        }
    }

    func saveFinalScore(gameId: BackyardGameId, playerId: String, score: Double) async {
        // Optimistic local update — UI responds immediately, Firestore confirms in background
        var local = finalScoresByGame
        var scores = local[gameId] ?? [:]
        scores[playerId] = score
        local[gameId] = scores
        finalScoresByGame = local

        let ref = gameRef(gameId)
            .collection("final_scores")
            .document("results")

        do {
            try await ref.setData([
                "scores.\(playerId)": score,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("❌ saveFinalScore \(gameId.rawValue) \(playerId):", error.localizedDescription)
            // Roll back optimistic update on failure
            var rollback = finalScoresByGame
            rollback[gameId]?.removeValue(forKey: playerId)
            finalScoresByGame = rollback
        }
    }

    func saveRelayTeamTime(teamId: String, totalSeconds: Double) async {
        let ref = gameRef(.relayRace)
            .collection("team_results")
            .document("results")

        do {
            try await ref.setData([
                "teams.\(teamId).totalSeconds": totalSeconds,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            relayTeamSeconds[teamId] = totalSeconds
        } catch {
            print("❌ saveRelayTeamTime:", error.localizedDescription)
        }
    }

    func saveRelaySplit(teamId: String, playerId: String, seconds: Double) async {
        let ref = gameRef(.relayRace)
            .collection("team_results")
            .document("results")

        do {
            try await ref.setData([
                "teams.\(teamId).splits.\(playerId)": seconds,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            var teamSplits = relaySplits[teamId] ?? [:]
            teamSplits[playerId] = seconds
            relaySplits[teamId] = teamSplits
        } catch {
            print("❌ saveRelaySplit:", error.localizedDescription)
        }
    }

    func seedClosestIfNeeded() async throws {
        let ref = gameRef(.bucketGolfClosest)
            .collection("state")
            .document("current")

        let snap = try await ref.getDocument()

        guard !snap.exists else {
            return
        }

        let mulligans = Dictionary(uniqueKeysWithValues: players.map { ($0.id, 1) })

        try await ref.setData([
            "mulligans": mulligans,
            "eliminatedPlaces": [:],
            "holeClosest": [:],
            "holeFurthest": [:],
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func spendMulligan(playerId: String) async {
        let current = closestMulligans[playerId] ?? 0

        guard current > 0 else {
            return
        }

        let next = current - 1

        let ref = gameRef(.bucketGolfClosest)
            .collection("state")
            .document("current")

        do {
            try await ref.setData([
                "mulligans.\(playerId)": next,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            closestMulligans[playerId] = next
        } catch {
            print("❌ spendMulligan:", error.localizedDescription)
        }
    }

    func saveClosestHoleResult(
        hole: Int,
        closestPlayerId: String,
        furthestPlayerId: String,
        eliminate: Bool
    ) async {
        let ref = gameRef(.bucketGolfClosest)
            .collection("state")
            .document("current")

        let currentMulligans = closestMulligans[closestPlayerId] ?? 1
        let nextMulligans = currentMulligans + 1

        let placeToAssign = nextClosestEliminationPlace()
        let shouldEliminate = eliminate && closestEliminatedPlaces[furthestPlayerId] == nil

        var updates: [String: Any] = [
            "holeClosest.\(hole)": closestPlayerId,
            "holeFurthest.\(hole)": furthestPlayerId,
            "mulligans.\(closestPlayerId)": nextMulligans,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if shouldEliminate {
            updates["eliminatedPlaces.\(furthestPlayerId)"] = placeToAssign
        }

        do {
            try await ref.setData(updates, merge: true)

            closestByHole[hole] = closestPlayerId
            furthestByHole[hole] = furthestPlayerId
            closestMulligans[closestPlayerId] = nextMulligans

            if shouldEliminate {
                closestEliminatedPlaces[furthestPlayerId] = placeToAssign
            }
        } catch {
            print("❌ saveClosestHoleResult:", error.localizedDescription)
        }
    }

    private func nextClosestEliminationPlace() -> Int {
        return 12 - closestEliminatedPlaces.count
    }

    func saveCornholeSinglesWinner(
        bracket: CornholeSinglesBracket,
        gameKey: String,
        winnerId: String
    ) async {
        let ref = gameRef(.cornholeSingles)
            .collection("brackets")
            .document(bracket.rawValue)

        do {
            try await ref.setData([
                "gameWinners.\(gameKey)": winnerId,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)

            var local = cornholeSinglesWinners[bracket] ?? [:]
            local[gameKey] = winnerId
            cornholeSinglesWinners[bracket] = local
        } catch {
            print("❌ saveCornholeSinglesWinner:", error.localizedDescription)
        }
    }

    // ── Hardcoded final results ─────────────────────────────────────────────
    // The backyard challenge is complete. All leaderboard functions now return
    // the official hardcoded results from BackyardHardcodedResults.
    // Firestore listeners are still active but leaderboard display is static.

    func golf18Leaderboard() -> [BackyardStandingRow] {
        BackyardHardcodedResults.golf18Rows()
    }

    func dekaLeaderboard() -> [BackyardStandingRow] {
        BackyardHardcodedResults.dekaRows()
    }

    func closestToPinLeaderboard() -> [BackyardStandingRow] {
        BackyardHardcodedResults.closestToPinRows()
    }

    func altShotRows() -> [BackyardStandingRow] {
        BackyardHardcodedResults.altShotRows()
    }

    func ladderBallRows() -> [BackyardStandingRow] {
        BackyardHardcodedResults.ladderBallRows()
    }

    func qb54Rows() -> [BackyardStandingRow] {
        BackyardHardcodedResults.qb54Rows()
    }

    func finalScoreLeaderboard(
        gameId: BackyardGameId,
        multiplier: Int? = nil,
        doublesScoring: Bool = false
    ) -> [BackyardStandingRow] {
        let scores = finalScoresByGame[gameId] ?? [:]
        var rows: [BackyardStandingRow] = []

        for player in players {
            rows.append(BackyardStandingRow(
                playerId: player.id,
                displayName: player.displayName,
                rawScore: scores[player.id] ?? 0,
                points: 0,
                thru: nil
            ))
        }

        rows.sort { left, right in
            if left.rawScore == right.rawScore { return left.displayName < right.displayName }
            if gameId.lowerIsBetter { return left.rawScore < right.rawScore }
            return left.rawScore > right.rawScore
        }

        var finalRows: [BackyardStandingRow] = []

        for (index, row) in rows.enumerated() {
            let points: Int

            if doublesScoring {
                points = BackyardScoring.doublesPoints(rankIndex: index)
            } else if let multiplier {
                points = BackyardScoring.marioKartPoints(rankIndex: index, multiplier: multiplier)
            } else {
                points = 0
            }

            finalRows.append(BackyardStandingRow(
                playerId: row.playerId,
                displayName: row.displayName,
                rawScore: row.rawScore,
                points: points,
                thru: nil
            ))
        }

        return finalRows
    }

    func cornholeSinglesBonusRows() -> [BackyardStandingRow] {
        BackyardHardcodedResults.cornholeSinglesRows()
    }

    func cornholeOverallRows() -> [BackyardStandingRow] {
        BackyardHardcodedResults.cornholeTotalRows()
    }

    func bucketGolfOverallRows() -> [BackyardStandingRow] {
        BackyardHardcodedResults.golfTotalRows()
    }

    func overallLeaderboard() -> [BackyardStandingRow] {
        BackyardHardcodedResults.overallRows()
    }

    private func emptyTotals() -> [String: Int] {
        var totals: [String: Int] = [:]
        for player in players { totals[player.id] = 0 }
        return totals
    }

    private func rowsFromTotals(_ totals: [String: Int]) -> [BackyardStandingRow] {
        var rows: [BackyardStandingRow] = []

        for player in players {
            let points = totals[player.id] ?? 0
            rows.append(BackyardStandingRow(playerId: player.id, displayName: player.displayName, rawScore: Double(points), points: points, thru: nil))
        }

        rows.sort { left, right in
            if left.points == right.points { return left.displayName < right.displayName }
            return left.points > right.points
        }

        return rows
    }

    func cornholeSeeds() -> [BackyardPlayer] {
        let rows = dekaLeaderboard()
        var seeded: [BackyardPlayer] = []

        for row in rows {
            if let player = players.first(where: { $0.id == row.playerId }) {
                seeded.append(player)
            }
        }

        return seeded
    }

    func cornholePlayers(for bracket: CornholeSinglesBracket) -> [BackyardPlayer] {
        let seeded = cornholeSeeds()
        let range = bracket.seedRange
        var result: [BackyardPlayer] = []

        for seedNumber in range {
            let index = seedNumber - 1
            if seeded.indices.contains(index) {
                result.append(seeded[index])
            }
        }

        return result
    }

    func cornholePlacements(for bracket: CornholeSinglesBracket) -> [String: Int] {
        let players = cornholePlayers(for: bracket)
        guard players.count == 4 else { return [:] }

        let winners = cornholeSinglesWinners[bracket] ?? [:]

        let g1A = players[0]
        let g1B = players[3]
        let g2A = players[1]
        let g2B = players[2]

        guard let g1WinnerId = winners["game1"],
              let g2WinnerId = winners["game2"] else {
            return [:]
        }

        let g1Loser = g1WinnerId == g1A.id ? g1B : g1A
        let g2Loser = g2WinnerId == g2A.id ? g2B : g2A

        var placements: [String: Int] = [:]

        if let game3WinnerId = winners["game3"] {
            placements[game3WinnerId] = 3
            let game3Loser = game3WinnerId == g1Loser.id ? g2Loser : g1Loser
            placements[game3Loser.id] = 4
        }

        if let game4WinnerId = winners["game4"] {
            placements[game4WinnerId] = 1
            let game4LoserId = game4WinnerId == g1WinnerId ? g2WinnerId : g1WinnerId
            placements[game4LoserId] = 2
        }

        return placements
    }

    func teamsFromCurrentOverallStandings() -> [BackyardTeam] {
        let rows = overallLeaderboard()
        var ranked: [BackyardPlayer] = []

        for row in rows {
            if let player = players.first(where: { $0.id == row.playerId }) {
                ranked.append(player)
            }
        }

        guard ranked.count >= 12 else { return [] }

        return [
            BackyardTeam(id: "team_1", name: "Team 1", players: [ranked[0], ranked[5], ranked[6], ranked[11]]),
            BackyardTeam(id: "team_2", name: "Team 2", players: [ranked[1], ranked[4], ranked[7], ranked[10]]),
            BackyardTeam(id: "team_3", name: "Team 3", players: [ranked[2], ranked[3], ranked[8], ranked[9]])
        ]
    }

    func doublesTeamsFromStandings(rows: [BackyardStandingRow]) -> [BackyardTeam] {
        var ranked: [BackyardPlayer] = []

        for row in rows {
            if let player = players.first(where: { $0.id == row.playerId }) {
                ranked.append(player)
            }
        }

        guard ranked.count >= 12 else { return [] }

        return [
            BackyardTeam(id: "team_1_12", name: "1 + 12", players: [ranked[0], ranked[11]]),
            BackyardTeam(id: "team_2_11", name: "2 + 11", players: [ranked[1], ranked[10]]),
            BackyardTeam(id: "team_3_10", name: "3 + 10", players: [ranked[2], ranked[9]]),
            BackyardTeam(id: "team_4_9", name: "4 + 9", players: [ranked[3], ranked[8]]),
            BackyardTeam(id: "team_5_8", name: "5 + 8", players: [ranked[4], ranked[7]]),
            BackyardTeam(id: "team_6_7", name: "6 + 7", players: [ranked[5], ranked[6]])
        ]
    }

    func fullResetForTesting() async {
        do {
            for game in BackyardGameId.allCases {
                let basePath = "backyard_challenge_events/\(eventId)/games/\(game.rawValue)"

                try await deleteCollection(path: "\(basePath)/hole_scores")
                try await deleteCollection(path: "\(basePath)/round_scores")
                try await deleteCollection(path: "\(basePath)/final_scores")
                try await deleteCollection(path: "\(basePath)/team_results")
                try await deleteCollection(path: "\(basePath)/state")
                try await deleteCollection(path: "\(basePath)/brackets")
                try await deleteCollection(path: "\(basePath)/group_scorecards")
            }

            golfHoleScores = [:]
            golfGroupScorecards = [:]
            dekaRoundScores = [:]
            finalScoresByGame = [:]
            relayTeamSeconds = [:]
            relaySplits = [:]
            closestMulligans = Dictionary(uniqueKeysWithValues: players.map { ($0.id, 1) })
            closestEliminatedPlaces = [:]
            closestByHole = [:]
            furthestByHole = [:]
            cornholeSinglesWinners = [:]

            try await seedClosestIfNeeded()
        } catch {
            print("❌ fullResetForTesting:", error.localizedDescription)
        }
    }

    private func deleteCollection(path: String, batchSize: Int = 50) async throws {
        let collection = db.collection(path)
        let snapshot = try await collection.limit(to: batchSize).getDocuments()

        guard !snapshot.documents.isEmpty else {
            return
        }

        let batch = db.batch()

        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }

        try await batch.commit()

        if snapshot.documents.count == batchSize {
            try await deleteCollection(path: path, batchSize: batchSize)
        }
    }
}
