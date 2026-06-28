//
//  WorldCup2026KnockoutSeeder.swift
//  Best Man Challenge
//
//  Seeds all 31 knockout bracket match documents to Firestore.
//  Run once from the Admin panel before Phase 2 opens.
//
//  FIFA 2026 official bracket (matches 73–104, excluding match 103 — 3rd place game).
//
//  Slot notation:
//    "1A"  = Winner of Group A       "2B" = Runner-up of Group B
//    "3rd-ABCDF" = Best 3rd from those groups (admin sets actual team after group stage)
//    "W73" = Winner of FIFA match 73 (resolved at runtime from knockout results)

import SwiftUI
import FirebaseFirestore

@MainActor
final class WorldCup2026KnockoutSeeder {

    static let bracketId = "world_cup_2026"

    // MARK: - Match Definitions
    // (id, round, fifaMatchNumber, sortOrder, team1Slot, team2Slot)

    static let matchDefs: [(id: String, round: String, num: Int, sort: Int, t1: String, t2: String)] = [
        // ── Round of 32 (FIFA matches 73–88) ─────────────────────────────────
        ("m73",  "r32",   73,  73,  "2A",           "2B"),
        ("m74",  "r32",   74,  74,  "1E",           "3rd-ABCDF"),
        ("m75",  "r32",   75,  75,  "1F",           "2C"),
        ("m76",  "r32",   76,  76,  "1C",           "2F"),
        ("m77",  "r32",   77,  77,  "1I",           "3rd-CDFGH"),
        ("m78",  "r32",   78,  78,  "2E",           "2I"),
        ("m79",  "r32",   79,  79,  "1A",           "3rd-CEFHI"),
        ("m80",  "r32",   80,  80,  "1L",           "3rd-EHIJK"),
        ("m81",  "r32",   81,  81,  "1D",           "3rd-BEFIJ"),
        ("m82",  "r32",   82,  82,  "1G",           "3rd-AEHIJ"),
        ("m83",  "r32",   83,  83,  "2K",           "2L"),
        ("m84",  "r32",   84,  84,  "1H",           "2J"),
        ("m85",  "r32",   85,  85,  "1B",           "3rd-EFGIJ"),
        ("m86",  "r32",   86,  86,  "1J",           "2H"),
        ("m87",  "r32",   87,  87,  "1K",           "3rd-DEIJL"),
        ("m88",  "r32",   88,  88,  "2D",           "2G"),

        // ── Round of 16 (FIFA matches 89–96) ─────────────────────────────────
        ("m89",  "r16",   89,  89,  "W74",          "W77"),
        ("m90",  "r16",   90,  90,  "W73",          "W75"),
        ("m91",  "r16",   91,  91,  "W76",          "W78"),
        ("m92",  "r16",   92,  92,  "W79",          "W80"),
        ("m93",  "r16",   93,  93,  "W83",          "W84"),
        ("m94",  "r16",   94,  94,  "W81",          "W82"),
        ("m95",  "r16",   95,  95,  "W86",          "W88"),
        ("m96",  "r16",   96,  96,  "W85",          "W87"),

        // ── Quarterfinals (FIFA matches 97–100) ──────────────────────────────
        ("m97",  "qf",    97,  97,  "W89",          "W90"),
        ("m98",  "qf",    98,  98,  "W93",          "W94"),
        ("m99",  "qf",    99,  99,  "W91",          "W92"),
        ("m100", "qf",   100, 100,  "W95",          "W96"),

        // ── Semifinals (FIFA matches 101–102) ─────────────────────────────────
        ("m101", "sf",   101, 101,  "W97",          "W98"),
        ("m102", "sf",   102, 102,  "W99",          "W100"),

        // ── Final (FIFA match 104) ─────────────────────────────────────────────
        ("m104", "final", 104, 104, "W101",         "W102"),
    ]

    // MARK: - Seed

    static func seedBracket() async throws {
        let db = Firestore.firestore()
        let collectionRef = db.collection("brackets")
            .document(bracketId)
            .collection("knockoutMatches")

        // Delete existing docs
        let existing = try await collectionRef.getDocuments()
        if !existing.documents.isEmpty {
            var delBatch = db.batch()
            for (i, doc) in existing.documents.enumerated() {
                delBatch.deleteDocument(doc.reference)
                if (i + 1) % 400 == 0 {
                    try await delBatch.commit()
                    delBatch = db.batch()
                }
            }
            try await delBatch.commit()
        }

        // Write all match documents
        var batch = db.batch()
        for (i, m) in matchDefs.enumerated() {
            let ref = collectionRef.document(m.id)
            batch.setData([
                "round":           m.round,
                "fifaMatchNumber": m.num,
                "sortOrder":       m.sort,
                "team1Slot":       m.t1,
                "team2Slot":       m.t2
            ], forDocument: ref)
            if (i + 1) % 400 == 0 {
                try await batch.commit()
                batch = db.batch()
            }
        }
        try await batch.commit()
        print("✅ KnockoutSeeder: \(matchDefs.count) matches seeded")
    }

    // MARK: - Set 3rd-Place Team Slots

    /// The 7 confirmed 3rd-place slot assignments from the R32 bracket.
    /// m85 (Switzerland vs 3rd-EFGIJ) is handled separately — Iran or Algeria,
    /// pending Group J Matchday 3 result (Algeria vs Austria).
    static let confirmed3rdPlaceSlots: [(matchId: String, field: String, teamId: String)] = [
        ("m74", "team2Slot", "PAR"),  // Germany vs Paraguay (Group D 3rd)
        ("m77", "team2Slot", "SWE"),  // France vs Sweden (Group F 3rd)
        ("m79", "team2Slot", "ECU"),  // Mexico vs Ecuador (Group E 3rd)
        ("m80", "team2Slot", "COD"),  // England vs DR Congo (Group K 3rd)
        ("m81", "team2Slot", "BIH"),  // USA vs Bosnia-Herz. (Group B 3rd)
        ("m82", "team2Slot", "SEN"),  // Belgium vs Senegal (Group I 3rd)
        ("m87", "team2Slot", "GHA"),  // Colombia vs Ghana (Group L 3rd)
    ]

    /// Updates the 7 confirmed 3rd-place match slots in Firestore with actual team IDs.
    /// After this runs, the bracket shows real team names instead of "3rd-XXXX" labels.
    static func seed3rdPlaceSlots() async throws {
        let db = Firestore.firestore()
        let collectionRef = db.collection("brackets")
            .document(bracketId)
            .collection("knockoutMatches")

        var batch = db.batch()
        for slot in confirmed3rdPlaceSlots {
            let ref = collectionRef.document(slot.matchId)
            batch.updateData([slot.field: slot.teamId], forDocument: ref)
        }
        try await batch.commit()
        print("✅ KnockoutSeeder: \(confirmed3rdPlaceSlots.count) 3rd-place slots set")
    }

    /// Sets the m85 slot (Switzerland vs TBD 3rd from G/J).
    /// Call with "IRN" for Iran or "ALG" for Algeria once Group J final result is confirmed.
    static func setM85ThirdPlaceSlot(teamId: String) async throws {
        let db = Firestore.firestore()
        try await db.collection("brackets")
            .document(bracketId)
            .collection("knockoutMatches")
            .document("m85")
            .updateData(["team2Slot": teamId])
        print("✅ KnockoutSeeder: m85 set to \(teamId)")
    }
}

// MARK: - Admin Seed Button

struct WorldCup2026KnockoutSeedButton: View {
    @State private var isSeeding = false
    @State private var resultText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task {
                    isSeeding = true
                    do {
                        try await WorldCup2026KnockoutSeeder.seedBracket()
                        resultText = "✅ Seeded \(WorldCup2026KnockoutSeeder.matchDefs.count) matches"
                    } catch {
                        resultText = "❌ \(error.localizedDescription)"
                    }
                    isSeeding = false
                }
            } label: {
                Label(isSeeding ? "Seeding…" : "Seed Knockout Bracket", systemImage: "arrow.down.circle")
            }
            .disabled(isSeeding)

            if !resultText.isEmpty {
                Text(resultText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("⚠️ Run 'Set 3rd Place Teams' below after seeding to assign actual teams.")
                .font(.caption2)
                .foregroundStyle(.orange)
        }
    }
}

// MARK: - Set 3rd Place Teams Button

struct WorldCup2026Set3rdPlaceButton: View {
    @State private var isUpdating = false
    @State private var resultText = ""
    @State private var m85Team: String = "IRN"  // Iran or Algeria — set once Group J result is in

    private let m85Options: [(id: String, label: String)] = [
        ("IRN", "🇮🇷 Iran (Group G 3rd)"),
        ("ALG", "🇩🇿 Algeria (Group J 3rd)"),
        ("AUT", "🇦🇹 Austria (Group J 3rd)"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Set 3rd-Place Teams")
                .font(.footnote.bold())

            // m85 picker (Switzerland vs TBD)
            VStack(alignment: .leading, spacing: 4) {
                Text("M85 · Switzerland vs ??? (3rd from G/J)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("M85 opponent", selection: $m85Team) {
                    ForEach(m85Options, id: \.id) { opt in
                        Text(opt.label).tag(opt.id)
                    }
                }
                .pickerStyle(.segmented)
            }

            Button {
                Task {
                    isUpdating = true
                    do {
                        try await WorldCup2026KnockoutSeeder.seed3rdPlaceSlots()
                        try await WorldCup2026KnockoutSeeder.setM85ThirdPlaceSlot(teamId: m85Team)
                        resultText = "✅ All 8 third-place slots set"
                    } catch {
                        resultText = "❌ \(error.localizedDescription)"
                    }
                    isUpdating = false
                }
            } label: {
                Label(isUpdating ? "Updating…" : "Set All 3rd-Place Teams", systemImage: "person.3.fill")
            }
            .disabled(isUpdating)
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            if !resultText.isEmpty {
                Text(resultText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Sets 7 confirmed teams (Paraguay, Sweden, Ecuador, DR Congo, Bosnia, Senegal, Ghana) and the M85 team you select above. Run once after Group J Matchday 3 result is confirmed.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
