import SwiftUI

struct InPersonEventsView: View {

    private let pokerNightEventId = "poker_night_001"

    enum EventType: Hashable, Identifiable {
        case vegasOdds
        case pokerNight
        case backyardChallenge
        case golfSimulator
        case drinkingGames
        case weekendTrip
        case boardVideoGames
        case closingCeremonies

        var id: String { title }

        var title: String {
            switch self {
            case .vegasOdds:         return "Vegas Odds"
            case .pokerNight:        return "Poker Night"
            case .backyardChallenge: return "Backyard Challenge"
            case .golfSimulator:     return "Golf Simulator"
            case .drinkingGames:     return "Drinking Games"
            case .weekendTrip:       return "Weekend Trip"
            case .boardVideoGames:   return "Board/Video Games"
            case .closingCeremonies: return "Closing Ceremonies"
            }
        }

        var subtitle: String {
            switch self {
            case .vegasOdds:         return "Prop bets and odds challenges"
            case .pokerNight:        return "Texas hold 'em tournament"
            case .backyardChallenge: return "Outdoor head-to-head games"
            case .golfSimulator:     return "Simulator round scoring"
            case .drinkingGames:     return "King of the table"
            case .weekendTrip:       return "Points across the full trip"
            case .boardVideoGames:   return "Game night competition"
            case .closingCeremonies: return "Final awards and ceremony"
            }
        }

        var systemImage: String {
            switch self {
            case .vegasOdds:         return "suit.diamond.fill"
            case .pokerNight:        return "suit.spade.fill"
            case .backyardChallenge: return "figure.outdoor.cycle"
            case .golfSimulator:     return "figure.golf"
            case .drinkingGames:     return "wineglass.fill"
            case .weekendTrip:       return "airplane"
            case .boardVideoGames:   return "gamecontroller.fill"
            case .closingCeremonies: return "trophy.fill"
            }
        }

        static let all: [EventType] = [
            .vegasOdds,
            .pokerNight,
            .backyardChallenge,
            .golfSimulator,
            .drinkingGames,
            .weekendTrip,
            .boardVideoGames,
            .closingCeremonies
        ]
    }

    var body: some View {
        NavigationStack {
            ThemedScreen {
                List {
                    Section {
                        ForEach(EventType.all) { event in
                            NavigationLink(value: event) {
                                eventRow(event)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.background)
                .navigationTitle("In Person Events")
                .navigationDestination(for: EventType.self) { event in
                    switch event {
                    case .vegasOdds:
                        VegasOddsHomeView()
                    case .pokerNight:
                        PokerNightView(eventId: pokerNightEventId)
                    case .backyardChallenge:
                        BackyardChallengeHomeView(eventId: "backyard_2026")
                    default:
                        ComingSoonView(title: event.title)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func eventRow(_ event: EventType) -> some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 46, height: 46)
                Image(systemName: event.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accent)
            }

            // Title + subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                Text(event.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
