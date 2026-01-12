// BeerPongModule.swift
// Drop‑in models + views to run Bret's Beer Pong tournaments (12 players)
// Mode toggle = Individual / Team. Teams are formed from Individual seeds.
//
// Notes:
// • Individual flow strictly follows your rules.
// • Team flow auto‑seeds 6 teams: (1,12),(2,11),(3,10),(4,9),(5,8),(6,7) and runs a standard 6‑team double elimination.
// • Tie handling: by default uses a manual tie‑breaker hook you can implement in the UI.
// • All logic is deterministic and UI‑friendly; persist TournamentState to disk if you like.

import SwiftUI

// MARK: - Core Models

struct Contestant: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    init(id: UUID = UUID(), name: String) { self.id = id; self.name = name }
}

struct Team: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var members: [Contestant] // size 2
    var seed: Int // 1...6
    init(id: UUID = UUID(), name: String, members: [Contestant], seed: Int) {
        self.id = id; self.name = name; self.members = members; self.seed = seed
    }
}

enum TournamentMode: String, Codable, CaseIterable, Identifiable { case individual, team; var id: String { rawValue } }

// MARK: - Individual Tournament (12 players)
// R1: 10 shots (10 cups) → bottom 4 placed 9–12
// R2: 6 shots (6 cups) → bottom 4 placed 5–8
// R3: 3 shots (3 cups) → bottom 2 placed 3–4
// Championship: Best to 3 makes, win by 2, sudden death, "make it, shoot again"

struct IndividualRoundScore: Codable, Hashable {
    var shotsAllowed: Int
    var makes: Int // 0...shotsAllowed
}

struct ChampionshipPlay: Codable, Hashable {
    var shooter: UUID // contestant id
    var made: Bool
}

struct IndividualTournamentState: Codable {
    var contestants: [Contestant] // mutates as rounds progress (current field)
    var initialContestants: [Contestant] // original 12 (never changes)

    // Scores by round (only for contestants still alive in that round)
    var round1: [UUID: IndividualRoundScore] = [:] // 10 shots
    var round2: [UUID: IndividualRoundScore] = [:] // 6 shots
    var round3: [UUID: IndividualRoundScore] = [:] // 3 shots

    // Placements as final positions (1..12). Higher = worse.
    // e.g. placements[contestantID] = 9 means finished 9th.
    var placements: [UUID: Int] = [:]

    // Championship tracking
    var finalists: [UUID] = [] // 2 ids
    var championshipPlays: [ChampionshipPlay] = []
    var champion: UUID? // 1st place
    var runnerUp: UUID? // 2nd place

    init(contestants: [Contestant]) {
        precondition(contestants.count == 12, "Beer Pong Individual requires exactly 12 contestants")
        self.contestants = contestants
        self.initialContestants = contestants
    }
}

final class IndividualTournamentEngine {
    typealias TieBreakHandler = (_ tied: [Contestant], _ context: String) -> [Contestant]
    private let tieBreak: TieBreakHandler

    init(tieBreak: @escaping TieBreakHandler = { tied, _ in tied.sorted { $0.name < $1.name } }) { // default alphabetical
        self.tieBreak = tieBreak
    }

    // MARK: Round helpers
    func setScore(state: inout IndividualTournamentState, round: Int, contestant: Contestant, makes: Int) {
        switch round {
        case 1: state.round1[contestant.id] = .init(shotsAllowed: 10, makes: clamp(makes, 0, 10))
        case 2: state.round2[contestant.id] = .init(shotsAllowed: 6, makes: clamp(makes, 0, 6))
        case 3: state.round3[contestant.id] = .init(shotsAllowed: 3, makes: clamp(makes, 0, 3))
        default: assertionFailure("Invalid round"); return
        }
    }

    // Finalize each round and assign placements per rules
    func finalizeRound1(state: inout IndividualTournamentState) {
        let r1Contestants = state.contestants
        let scored = r1Contestants.map { ($0, state.round1[$0.id]?.makes ?? 0) }
        let ordered = rankContestants(scored)
        // bottom 4 → places 12,11,10,9 (assign worst to 12)
        let bottom4 = Array(ordered.suffix(4))
        for (index, c) in bottom4.enumerated() { state.placements[c.id] = 12 - index }
        // survivors advance
        let survivors = Array(ordered.prefix(8))
        state.contestants = survivors
    }

    func finalizeRound2(state: inout IndividualTournamentState) {
        precondition(state.contestants.count == 8, "Round 2 expects 8 survivors")
        let scored = state.contestants.map { ($0, state.round2[$0.id]?.makes ?? 0) }
        let ordered = rankContestants(scored)
        let bottom4 = Array(ordered.suffix(4))
        // next 4 spots: 8,7,6,5
        for (index, c) in bottom4.enumerated() { state.placements[c.id] = 8 - index }
        state.contestants = Array(ordered.prefix(4))
    }

    func finalizeRound3(state: inout IndividualTournamentState) {
        precondition(state.contestants.count == 4, "Round 3 expects 4 survivors")
        let scored = state.contestants.map { ($0, state.round3[$0.id]?.makes ?? 0) }
        let ordered = rankContestants(scored)
        let bottom2 = Array(ordered.suffix(2))
        // places 4 and 3
        state.placements[bottom2[1].id] = 4
        state.placements[bottom2[0].id] = 3
        // finalists are top 2
        state.finalists = Array(ordered.prefix(2)).map { $0.id }
    }

    // MARK: Championship logic ("make it, shoot again"; first to 3, win by 2)
    // Feed plays in order as they occur. Engine validates win condition.

    func recordChampPlay(state: inout IndividualTournamentState, shooter: Contestant, made: Bool) {
        precondition(state.finalists.contains(shooter.id), "Shooter must be a finalist")
        state.championshipPlays.append(.init(shooter: shooter.id, made: made))
        evaluateChampionship(state: &state)
    }

    private func evaluateChampionship(state: inout IndividualTournamentState) {
        guard state.champion == nil, state.finalists.count == 2 else { return }
        let a = state.finalists[0], b = state.finalists[1]
        var score: [UUID: Int] = [a: 0, b: 0]
        var shooter: UUID? = nil
        for play in state.championshipPlays {
            if shooter == nil { shooter = play.shooter } // first shooter established by first record
            if play.made {
                score[play.shooter, default: 0] += 1
                // shooter continues (make = shoot again)
            } else {
                // miss passes ball to the other finalist
                shooter = (play.shooter == a) ? b : a
            }
            // check win condition: first to 3 AND lead >= 2
            let sa = score[a, default: 0], sb = score[b, default: 0]
            if (sa >= 3 || sb >= 3) && abs(sa - sb) >= 2 {
                state.champion = (sa > sb) ? a : b
                state.runnerUp = (sa > sb) ? b : a
                state.placements[state.champion!] = 1
                state.placements[state.runnerUp!] = 2
                break
            }
        }
    }

    // Seeds = final placements ascending (1..12)
    func computeSeeds(from placements: [UUID: Int], contestants all: [Contestant]) -> [Contestant] {
        // Build map from unique IDs
        let map = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        // (Optional) assertions for safety
        assert(map.count == 12, "Expected 12 unique contestants for seeding")
        assert(Set(placements.values).count == 12, "Expected unique placements 1...12")
        return placements.sorted { $0.value < $1.value }.compactMap { map[$0.key] }
    }

    private func rankContestants(_ pairs: [(Contestant, Int)]) -> [Contestant] {
        // Sort by makes desc; resolve ties via handler
        var buckets: [Int: [Contestant]] = [:]
        for (c, s) in pairs { buckets[s, default: []].append(c) }
        let scoresDesc = buckets.keys.sorted(by: >)
        var ordered: [Contestant] = []
        for s in scoresDesc {
            let group = buckets[s]!
            if group.count == 1 { ordered.append(group[0]) }
            else { ordered.append(contentsOf: tieBreak(group, "Tie at score=\(s)")) }
        }
        return ordered
    }

    private func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { min(max(v, lo), hi) }
}

// MARK: - Team seeding

struct TeamSeeding {
    static func makeTeams(from seededContestants: [Contestant]) -> [Team] {
        precondition(seededContestants.count == 12, "Need 12 seeded contestants")
        // seededContestants[0] = seed 1, ...
        let pairs: [(Int, Int)] = [(1,12),(2,11),(3,10),(4,9),(5,8),(6,7)]
        return pairs.enumerated().map { (idx, pair) in
            let (s1, s2) = pair
            let c1 = seededContestants[s1 - 1]
            let c2 = seededContestants[s2 - 1]
            let seed = idx + 1 // teams seeded 1..6 by pair order
            return Team(name: "Team \(c1.name) & \(c2.name)", members: [c1,c2], seed: seed)
        }
    }
}

// MARK: - Double Elimination (6 teams, seeds 1&2 byes)
// Bracket layout IDs:
// WB-A: (3) vs (6)
// WB-B: (4) vs (5)
// WB-C: (1) vs Winner(B)
// WB-D: (2) vs Winner(A)
// WB-F: Winners Final: Winner(C) vs Winner(D)
// LB-A: Loser(B) vs Loser(C)
// LB-B: Loser(A) vs Loser(D)
// LB-C: Winner(LB-A) vs Loser(WB-F)
// LB-D: Winner(LB-B) vs Winner(LB-C)
// GF-1: Winner(WB-F) vs Winner(LB-D)
// GF-2 (if needed reset): only if Winner(LB-D) wins GF‑1 (classic true double‑elim)

struct MatchID: Hashable, Codable, CustomStringConvertible { let raw: String; var description: String { raw } }

struct Match: Identifiable, Codable, Hashable {
    var id: MatchID
    var roundName: String
    var participants: [Team?] // 2 slots
    var scores: [Int?] // parallel to participants
    var winner: Team? { if let s0 = scores[0], let s1 = scores[1], let t0 = participants[0], let t1 = participants[1] { return s0 > s1 ? t0 : t1 } else { return nil } }
    var loser: Team? { if let s0 = scores[0], let s1 = scores[1], let t0 = participants[0], let t1 = participants[1] { return s0 > s1 ? t1 : t0 } else { return nil } }
}

struct DoubleElimState: Codable {
    var teams: [Team] // 6 teams
    var matches: [MatchID: Match]
    var champion: Team?
}

final class DoubleElimEngine {
    func bootstrap(teams: [Team]) -> DoubleElimState {
        precondition(teams.count == 6, "Double‑elim requires 6 teams here")
        // Index by seed for convenience
        let bySeed = Dictionary(uniqueKeysWithValues: teams.map { ($0.seed, $0) })
        var state = DoubleElimState(teams: teams, matches: [:], champion: nil)
        // Winners bracket
        state.matches[.wb("A")] = Match(id: .wb("A"), roundName: "WB R1 A", participants: [bySeed[3], bySeed[6]], scores: [nil, nil])
        state.matches[.wb("B")] = Match(id: .wb("B"), roundName: "WB R1 B", participants: [bySeed[4], bySeed[5]], scores: [nil, nil])
        state.matches[.wb("C")] = Match(id: .wb("C"), roundName: "WB R2 C", participants: [bySeed[1], nil], scores: [nil, nil])
        state.matches[.wb("D")] = Match(id: .wb("D"), roundName: "WB R2 D", participants: [bySeed[2], nil], scores: [nil, nil])
        state.matches[.wb("F")] = Match(id: .wb("F"), roundName: "Winners Final", participants: [nil, nil], scores: [nil, nil])
        // Losers bracket
        state.matches[.lb("A")] = Match(id: .lb("A"), roundName: "LB A", participants: [nil, nil], scores: [nil, nil])
        state.matches[.lb("B")] = Match(id: .lb("B"), roundName: "LB B", participants: [nil, nil], scores: [nil, nil])
        state.matches[.lb("C")] = Match(id: .lb("C"), roundName: "LB C", participants: [nil, nil], scores: [nil, nil])
        state.matches[.lb("D")] = Match(id: .lb("D"), roundName: "LB D", participants: [nil, nil], scores: [nil, nil])
        // Grand finals
        state.matches[.gf(1)] = Match(id: .gf(1), roundName: "Grand Final 1", participants: [nil, nil], scores: [nil, nil])
        state.matches[.gf(2)] = Match(id: .gf(2), roundName: "Grand Final 2 (if needed)", participants: [nil, nil], scores: [nil, nil])
        return state
    }

    // Record a finished match and wire next participants automatically
    func submit(state: inout DoubleElimState, match id: MatchID, scores: (Int, Int)) {
        guard var m = state.matches[id] else { return }
        m.scores = [scores.0, scores.1]
        state.matches[id] = m
        route(state: &state, from: id)
    }

    private func route(state: inout DoubleElimState, from id: MatchID) {
        guard let m = state.matches[id], let winner = m.winner, let loser = m.loser else { return }
        switch id.raw {
        case "WB-A":
            // Winner → WB-D vs seed2; Loser → LB-B slot 0
            insertParticipant(&state, .wb("D"), slot: 1, team: winner)
            insertParticipant(&state, .lb("B"), slot: 0, team: loser)
        case "WB-B":
            // Winner → WB-C vs seed1; Loser → LB-A slot 0
            insertParticipant(&state, .wb("C"), slot: 1, team: winner)
            insertParticipant(&state, .lb("A"), slot: 0, team: loser)
        case "WB-C":
            // Winner → WB-F slot 0; Loser → LB-A slot 1
            insertParticipant(&state, .wb("F"), slot: 0, team: winner)
            insertParticipant(&state, .lb("A"), slot: 1, team: loser)
        case "WB-D":
            // Winner → WB-F slot 1; Loser → LB-B slot 1
            insertParticipant(&state, .wb("F"), slot: 1, team: winner)
            insertParticipant(&state, .lb("B"), slot: 1, team: loser)
        case "WB-F":
            // Winner → GF1 slot 0; Loser → LB-C slot 1
            insertParticipant(&state, .gf(1), slot: 0, team: winner)
            insertParticipant(&state, .lb("C"), slot: 1, team: loser)
        case "LB-A":
            // Winner → LB-C slot 0; Loser eliminated
            insertParticipant(&state, .lb("C"), slot: 0, team: winner)
        case "LB-B":
            // Winner → LB-D slot 0; Loser eliminated
            insertParticipant(&state, .lb("D"), slot: 0, team: winner)
        case "LB-C":
            // Winner → LB-D slot 1; Loser eliminated
            insertParticipant(&state, .lb("D"), slot: 1, team: winner)
        case "LB-D":
            // Winner → GF1 slot 1; Loser eliminated
            insertParticipant(&state, .gf(1), slot: 1, team: winner)
        case "GF-1":
            // If WB champ wins → champion crowned; else → reset (GF-2)
            if let wbFinal = state.matches[.wb("F")], let wbWinner = wbFinal.winner, winner.id == wbWinner.id {
                state.champion = winner
            } else {
                // reset; both teams now have one loss → play GF-2
                insertParticipant(&state, .gf(2), slot: 0, team: m.participants[0]!)
                insertParticipant(&state, .gf(2), slot: 1, team: m.participants[1]!)
            }
        case "GF-2":
            state.champion = winner
        default: break
        }
    }

    private func insertParticipant(_ state: inout DoubleElimState, _ id: MatchID, slot: Int, team: Team) {
        guard var m = state.matches[id] else { return }
        if m.participants.count > slot { m.participants[slot] = team }
        state.matches[id] = m
    }
}

extension MatchID {
    static func wb(_ s: String) -> MatchID { .init(raw: "WB-\(s)") }
    static func lb(_ s: String) -> MatchID { .init(raw: "LB-\(s)") }
    static func gf(_ n: Int) -> MatchID { .init(raw: "GF-\(n)") }
}

// MARK: - SwiftUI: Mode Toggle & Basic Screens

struct BeerPongHomeView: View {
    @State private var mode: TournamentMode = .individual
    @State private var indivState: IndividualTournamentState
    @State private var seededContestants: [Contestant] = []
    @State private var teamState: DoubleElimState?
    private let indivEngine = IndividualTournamentEngine()
    private let teamEngine = DoubleElimEngine()

    init(players: [String]) {
        let contestants = players.map { Contestant(name: $0) }
        _indivState = State(initialValue: IndividualTournamentState(contestants: contestants))
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("Mode", selection: $mode) {
                Text("Individual").tag(TournamentMode.individual)
                Text("Team").tag(TournamentMode.team)
            }
            .pickerStyle(.segmented)

            if mode == .individual {
                IndividualView(state: $indivState, engine: indivEngine, onDone: finalizeIndividuals)
            } else {
                if let teamState {
                    TeamBracketView(state: teamState, submit: { id, s0, s1 in
                        var copy = teamState
                        teamEngine.submit(state: &copy, match: id, scores: (s0,s1))
                        self.teamState = copy
                    })
                } else {
                    VStack(spacing: 12) {
                        Text("Run Individual first to generate seeds.")
                        Button("Create Teams from Seeds") {
                            guard seededContestants.count == 12 else { return }
                            let teams = TeamSeeding.makeTeams(from: seededContestants)
                            self.teamState = teamEngine.bootstrap(teams: teams)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .padding()
        .navigationTitle("Beer Pong — 12 Player")
    }

    private func finalizeIndividuals(_ placements: [UUID: Int], all: [Contestant]) {
        self.seededContestants = indivEngine.computeSeeds(from: placements, contestants: all)
        self.mode = .team // auto‑switch to Team once seeds exist
    }
}

// MARK: - Individual View (minimal, scoreboard entry)

struct IndividualView: View {
    @Binding var state: IndividualTournamentState
    let engine: IndividualTournamentEngine
    var onDone: (_ placements: [UUID:Int], _ all: [Contestant]) -> Void

    var body: some View {
        ScrollView {
            roundSection(title: "Round 1 — 10 shots", allowed: 10, round: 1)
            Button("Finalize Round 1") { engine.finalizeRound1(state: &state) }
                .buttonStyle(.borderedProminent)
                .padding(.bottom)

            if state.contestants.count == 8 {
                roundSection(title: "Round 2 — 6 shots", allowed: 6, round: 2)
                Button("Finalize Round 2") { engine.finalizeRound2(state: &state) }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
            }

            if state.contestants.count == 4 {
                roundSection(title: "Round 3 — 3 shots", allowed: 3, round: 3)
                Button("Finalize Round 3") { engine.finalizeRound3(state: &state) }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
            }

            if state.finalists.count == 2 {
                ChampionshipSection(state: $state, engine: engine)
                if let champ = state.champion,
                   let c = state.initialContestants.first(where: { $0.id == champ }) {
                    Text("Champion: \(c.name)")
                        .font(.title3).padding(.top)
                    Button("Use Final Placements for Team Seeding") {
                        onDone(state.placements, state.initialContestants)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func roundSection(title: String, allowed: Int, round: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ForEach(state.contestants) { c in
                HStack {
                    Text(c.name)
                    Spacer()
                    Stepper(value: Binding(
                        get: { score(for: c, round: round) },
                        set: { engine.setScore(state: &state, round: round, contestant: c, makes: $0) }
                    ), in: 0...allowed) {
                        Text("\(score(for: c, round: round)) / \(allowed)")
                    }
                    .frame(maxWidth: 220)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func score(for c: Contestant, round: Int) -> Int {
        switch round {
        case 1: return state.round1[c.id]?.makes ?? 0
        case 2: return state.round2[c.id]?.makes ?? 0
        case 3: return state.round3[c.id]?.makes ?? 0
        default: return 0
        }
    }
}

struct ChampionshipSection: View {
    @Binding var state: IndividualTournamentState
    let engine: IndividualTournamentEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Championship — First to 3, win by 2 (make = shoot again)").font(.headline)
            HStack {
                if state.finalists.count == 2 {
                    let ids = state.finalists
                    let a = ids[0], b = ids[1]
                    Button("\(name(a)) made") { engine.recordChampPlay(state: &state, shooter: by(id: a), made: true) }
                    Button("\(name(a)) missed") { engine.recordChampPlay(state: &state, shooter: by(id: a), made: false) }
                    Button("\(name(b)) made") { engine.recordChampPlay(state: &state, shooter: by(id: b), made: true) }
                    Button("\(name(b)) missed") { engine.recordChampPlay(state: &state, shooter: by(id: b), made: false) }
                }
            }
            ScrollView(.horizontal) {
                HStack {
                    ForEach(state.championshipPlays.indices, id: \.self) { i in
                        let p = state.championshipPlays[i]
                        Text("\(name(p.shooter)): \(p.made ? "✅" : "❌")")
                            .padding(6)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func name(_ id: UUID) -> String { by(id: id).name }
    private func by(id: UUID) -> Contestant {
        if let c = state.contestants.first(where: { $0.id == id }) { return c }
        if let c = state.initialContestants.first(where: { $0.id == id }) { return c }
        return Contestant(name: "?")
    }
}

// MARK: - Team Bracket View (compact)

struct TeamBracketView: View {
    var state: DoubleElimState
    var submit: (_ id: MatchID, _ s0: Int, _ s1: Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Winners Bracket").font(.headline)
            matchRow(.wb("A"))
            matchRow(.wb("B"))
            matchRow(.wb("C"))
            matchRow(.wb("D"))
            matchRow(.wb("F"))

            Divider()
            Text("Losers Bracket").font(.headline)
            matchRow(.lb("A"))
            matchRow(.lb("B"))
            matchRow(.lb("C"))
            matchRow(.lb("D"))

            Divider()
            Text("Grand Finals").font(.headline)
            matchRow(.gf(1))
            matchRow(.gf(2))

            if let champ = state.champion {
                Text("Team Champion: \(champ.name)").font(.title3).padding(.top)
            }
        }
    }

    @ViewBuilder private func matchRow(_ id: MatchID) -> some View {
        if let m = state.matches[id] {
            HStack {
                Text(m.roundName).frame(width: 160, alignment: .leading)
                Text(m.participants[0]?.name ?? "TBD").frame(maxWidth: .infinity, alignment: .leading)
                Text("vs").foregroundColor(.secondary)
                Text(m.participants[1]?.name ?? "TBD").frame(maxWidth: .infinity, alignment: .leading)
                if m.scores[0] == nil || m.scores[1] == nil {
                    StepperInput(label: "Score L", onCommit: { s0, s1 in submit(id, s0, s1) })
                } else if let s0 = m.scores[0], let s1 = m.scores[1] {
                    Text("Final: \(s0)-\(s1)")
                        .bold()
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}

struct StepperInput: View {
    let label: String
    var onCommit: (_ s0: Int, _ s1: Int) -> Void
    @State private var s0: Int = 0
    @State private var s1: Int = 0
    var body: some View {
        HStack(spacing: 8) {
            Stepper("", value: $s0, in: 0...50).labelsHidden()
            Text("\(s0)")
            Text(":")
            Stepper("", value: $s1, in: 0...50).labelsHidden()
            Text("\(s1)")
            Button("Submit") { onCommit(s0, s1) }
                .buttonStyle(.bordered)
        }
    }
}

// MARK: - Preview (for quick smoke test)
#if DEBUG
struct BeerPongHomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            BeerPongHomeView(players: ["P1","P2","P3","P4","P5","P6","P7","P8","P9","P10","P11","P12"]) }
        .preferredColorScheme(.dark)
    }
}
#endif
