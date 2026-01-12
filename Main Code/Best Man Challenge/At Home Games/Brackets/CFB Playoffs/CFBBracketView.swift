import SwiftUI

struct CFBBracketView: View {
    @EnvironmentObject var session: SessionStore

    private enum Tab: String, CaseIterable, Identifiable {
        case standings = "Standings"
        case picks = "Picks"
        case bracket = "Bracket"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .standings

    // MARK: - Hardcoded Data (v1)

    private let entries: [CFBEntry] = [
        .init(playerId: "valentinom", displayName: "Valentino", points: 14,
              picks: ["Miami","Georgia","Indiana","Oregon","Indiana","Miami","Miami"]),
        .init(playerId: "dannyo", displayName: "Danny O", points: 8,
              picks: ["Ohio State","Georgia","Indiana","Oregon","Indiana","Georgia","Indiana"]),
        .init(playerId: "isaiahs", displayName: "Isaiah", points: 6,
              picks: ["Ohio State","Ole Miss","Indiana","Oregon","Indiana","Ohio State","Ohio State"]),
        .init(playerId: "jakeo", displayName: "Jake", points: 6,
              picks: ["Ohio State","Ole Miss","Indiana","Oregon","Indiana","Ohio State","Ohio State"]),
        .init(playerId: "joelr", displayName: "Joel Rafter", points: 8,
              picks: ["Ohio State","Georgia","Indiana","Oregon","Indiana","Ohio State","Ohio State"]),
        .init(playerId: "ronaldp", displayName: "Ronald", points: 8,
              picks: ["Ohio State","Georgia","Indiana","Oregon","Indiana","Ohio State","Ohio State"]),
        .init(playerId: "matthewp", displayName: "Matt P.", points: 8,
              picks: ["Ohio State","Georgia","Indiana","Oregon","Indiana","Georgia","Georgia"]),
        .init(playerId: "anthonyc", displayName: "Anthony", points: 2,
              picks: ["Ohio State","Georgia","Alabama","Oregon","Oregon","Georgia","Georgia"]),
        .init(playerId: "mitchz", displayName: "Mitch", points: 2,
              picks: ["Ohio State","Georgia","Alabama","Oregon","Oregon","Georgia","Georgia"]),
        .init(playerId: "kylel", displayName: "Kyle", points: 6,
              picks: ["Ohio State","Georgia","Indiana","Texas Tech","Indiana","Ohio State","Ohio State"]),
        .init(playerId: "matthewc", displayName: "Matt Carlos", points: 6,
              picks: ["Ohio State","Georgia","Indiana","Texas Tech","Indiana","Ohio State","Ohio State"]),
        .init(playerId: "bretc", displayName: "Bret", points: 0,
              picks: ["Ohio State","Georgia","Alabama","Texas Tech","Texas Tech","Georgia","Georgia"])
    ]

    private var sortedEntries: [CFBEntry] {
        entries.sorted {
            if $0.points != $1.points { return $0.points > $1.points }
            return $0.displayName < $1.displayName
        }
    }

    var body: some View {
        ThemedScreen {
            VStack(spacing: 12) {
                header()

                Picker("Tab", selection: $tab) {
                    ForEach(Tab.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch tab {
                case .standings:
                    standingsList()
                case .picks:
                    picksList()
                case .bracket:
                    bracketImageView()
                }
            }
            .navigationTitle("CFB Bracket")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Header

    private func header() -> some View {
        VStack(spacing: 6) {
            Text("College Football Playoff Pool")
                .font(.title3).bold()

        }
        .padding(.top, 10)
        .padding(.horizontal)
    }

    // MARK: - Standings

    private func standingsList() -> some View {
        List {
            Section(header: standingsHeader()) {
                ForEach(Array(sortedEntries.enumerated()), id: \.element.playerId) { idx, entry in
                    let isMe = isLoggedIn(entry.playerId)
                    standingsRow(rank: idx + 1, entry: entry, isMe: isMe)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.background)
    }

    private func standingsHeader() -> some View {
        HStack {
            Text("#").frame(width: 30, alignment: .leading)
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Pts").frame(width: 50, alignment: .trailing)
        }
        .font(.caption.bold())
        .secondaryText()
    }

    private func standingsRow(rank: Int, entry: CFBEntry, isMe: Bool) -> some View {
        HStack(spacing: 10) {
            Text("\(rank)").frame(width: 30, alignment: .leading)

            HStack(spacing: 8) {
                Text(entry.displayName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fontWeight(isMe ? .bold : .regular)

                if isMe {
                    Text("You")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accent.opacity(0.20))
                        .foregroundStyle(Color.accent)
                        .clipShape(Capsule())
                }
            }

            Text("\(entry.points)")
                .frame(width: 50, alignment: .trailing)
                .fontWeight(isMe ? .bold : .regular)
        }
        .cardStyle()
    }

    // MARK: - Picks

    private func picksList() -> some View {
        List {
            ForEach(sortedEntries, id: \.playerId) { entry in
                let isMe = isLoggedIn(entry.playerId)
                picksCard(entry: entry, isMe: isMe)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.background)
    }

    private func picksCard(entry: CFBEntry, isMe: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.displayName)
                    .font(.headline)
                    .fontWeight(isMe ? .bold : .semibold)

                if isMe {
                    Text("You")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accent.opacity(0.20))
                        .foregroundStyle(Color.accent)
                        .clipShape(Capsule())
                }

                Spacer()

                Text("\(entry.points) pts")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.picks, id: \.self) { pick in
                    HStack {
                        Text("•")
                        Text(pick)
                    }
                    .font(.footnote)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Bracket Image Tab

    private func bracketImageView() -> some View {
        ZoomableImage(assetName: "CFBBracketSheet")
            .padding(.horizontal)
            .padding(.bottom, 12)
    }

    // MARK: - Helpers

    private func isLoggedIn(_ playerId: String) -> Bool {
        guard let linked = session.profile?.linkedPlayerId else { return false }
        return linked == playerId
    }
}

// MARK: - Zoomable Image

struct ZoomableImage: View {
    let assetName: String

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            ScrollView([.vertical, .horizontal], showsIndicators: false) {
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit) // ✅ fits by default
                    .frame(width: geo.size.width)    // ✅ fit-to-screen width
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(1.0, min(lastScale * value, 4.0))
                            }
                            .onEnded { _ in
                                lastScale = scale
                            }
                    )
            }
            .background(Color.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}


// MARK: - Model

struct CFBEntry {
    let playerId: String
    let displayName: String
    let points: Int
    let picks: [String]
}
