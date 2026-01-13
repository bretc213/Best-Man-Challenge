//
//  NFLFuturesView.swift
//  Best Man Challenge
//
//  Futures screen:
//  - Shows Players + Admins separately
//  - Shows AFC Champ / NFC Champ / Super Bowl Champ picks
//  - Colors: green if correct champion (when decided), red if eliminated (team has lost a decided matchup)
//  - Constant regardless of selected round (reads picks/wildcard docs via NFLFuturesStore)
//

import SwiftUI
import FirebaseFirestore

struct NFLFuturesView: View {

    @ObservedObject var futuresStore: NFLFuturesStore

    /// Map team abbrev ("LAR") to display name ("Los Angeles Rams") if you want.
    /// For now you can pass { $0 } and it will show the abbrev.
    let teamName: (String) -> String

    // ✅ Put FuturesResults in THIS file so it’s in scope
    private struct FuturesResults {
        let afcWinner: String?
        let nfcWinner: String?
        let sbWinner: String?
        let eliminated: Set<String>
    }

    // ✅ Give the nils an explicit type via FuturesResults initializer
    @State private var results: FuturesResults = .init(
        afcWinner: nil,
        nfcWinner: nil,
        sbWinner: nil,
        eliminated: []
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                Text("Futures")
                    .font(.title2.bold())

                Text("Conference champions and Super Bowl champ picks. Colors update as games are decided.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if futuresStore.isLoading {
                    ProgressView("Loading futures...")
                        .padding(.top, 8)

                } else if let err = futuresStore.errorMessage {
                    Text("Couldn’t load: \(err)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)

                } else {
                    futuresGroup(title: "Players", rows: futuresStore.players)
                    futuresGroup(title: "Admins", rows: futuresStore.admins)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .task {
            await fetchResultsOnce()
        }
    }

    // MARK: - Groups

    private func futuresGroup(title: String, rows: [NFLFuturesRow]) -> some View {
        VStack(alignment: .leading, spacing: 10) {

            Text(title)
                .font(.title3.bold())
                .padding(.top, 4)

            futuresSectionCard(
                headerTitle: "AFC Champion",
                headerAssetName: "afc_logo", // add later (safe fallback)
                picks: rows.map { ($0.displayName, $0.afc) },
                actualWinner: results.afcWinner
            )

            futuresSectionCard(
                headerTitle: "NFC Champion",
                headerAssetName: "nfc_logo", // add later (safe fallback)
                picks: rows.map { ($0.displayName, $0.nfc) },
                actualWinner: results.nfcWinner
            )

            futuresSectionCard(
                headerTitle: "Super Bowl Champion",
                headerAssetName: "NFLLogo", // add later (safe fallback)
                picks: rows.map { ($0.displayName, $0.superBowl) },
                actualWinner: results.sbWinner
            )
        }
    }

    // MARK: - Cards

    private func futuresSectionCard(
        headerTitle: String,
        headerAssetName: String,
        picks: [(String, String?)],   // (displayName, teamAbbrev)
        actualWinner: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 10) {
                // If logos aren’t in assets yet, show a system fallback.
                if UIImage(named: headerAssetName) != nil {
                    Image(headerAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                } else {
                    Image(systemName: headerTitle.contains("Super Bowl") ? "trophy.fill" : "flag.checkered")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                Text(headerTitle)
                    .font(.headline)

                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(picks, id: \.0) { row in
                    let name = row.0
                    let team = row.1

                    HStack {
                        Text(name)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(displayTeam(team))
                            .fontWeight(.semibold)
                            .foregroundStyle(colorFor(team: team, actualWinner: actualWinner))
                    }
                }
            }
        }
        .cardStyle()
    }

    private func displayTeam(_ team: String?) -> String {
        guard let team, !team.isEmpty else { return "—" }
        return teamName(team)
    }

    private func colorFor(team: String?, actualWinner: String?) -> Color {
        guard let team, !team.isEmpty else { return .secondary }

        // ✅ Green if the champion is decided and they picked the champion
        if let actualWinner, actualWinner == team {
            return .green
        }

        // ✅ Red if that team has already lost any decided game
        if results.eliminated.contains(team) {
            return .red
        }

        return .secondary
    }

    // MARK: - Results fetch (winners + eliminated)

    /// One-time fetch is enough for now; refresh by re-entering the view.
    /// If you want real-time updates, we can convert this to a snapshot listener.
    @MainActor
    private func fetchResultsOnce() async {
        do {
            let db = Firestore.firestore()

            let snap = try await db.collection("brackets")
                .document(futuresStore.bracketId)
                .collection("matchups")
                .getDocuments()

            let parsed = snap.documents.compactMap { doc -> ParsedMatchup? in
                let d = doc.data()

                // Adjust keys here if your matchup schema differs.
                let roundId = (d["roundId"] as? String) ?? (d["round"] as? String) ?? ""
                let index = d["index"] as? Int ?? 0
                let winner = d["winnerTeamId"] as? String

                guard
                    let awayMap = d["away"] as? [String: Any],
                    let homeMap = d["home"] as? [String: Any],
                    let awayId = awayMap["id"] as? String,
                    let homeId = homeMap["id"] as? String
                else { return nil }

                return ParsedMatchup(
                    roundId: roundId.lowercased(),
                    index: index,
                    winnerTeamId: winner,
                    awayId: awayId,
                    homeId: homeId
                )
            }

            // eliminated teams
            var eliminated = Set<String>()
            for m in parsed {
                guard let w = m.winnerTeamId, !w.isEmpty else { continue }
                if m.awayId != w { eliminated.insert(m.awayId) }
                if m.homeId != w { eliminated.insert(m.homeId) }
            }

            // champion winners
            // Conference: assume two matchups; first = AFC, second = NFC (by index ordering)
            let conference = parsed
                .filter { $0.roundId == "conference" }
                .sorted { $0.index < $1.index }

            let afcWinner = conference.count > 0 ? conference[0].winnerTeamId : nil
            let nfcWinner = conference.count > 1 ? conference[1].winnerTeamId : nil

            // Super Bowl: assume one matchup in superbowl round
            let sbWinner = parsed.first(where: { $0.roundId == "superbowl" || $0.roundId == "super_bowl" })?.winnerTeamId

            results = FuturesResults(
                afcWinner: afcWinner ?? nil,
                nfcWinner: nfcWinner ?? nil,
                sbWinner: sbWinner ?? nil,
                eliminated: eliminated
            )

        } catch {
            // Don’t break the page if matchups fetch fails
            results = FuturesResults(afcWinner: nil, nfcWinner: nil, sbWinner: nil, eliminated: [])
        }
    }

    // MARK: - Internal parsed matchup

    private struct ParsedMatchup {
        let roundId: String
        let index: Int
        let winnerTeamId: String?
        let awayId: String
        let homeId: String
    }
}
