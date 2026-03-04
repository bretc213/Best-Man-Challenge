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
            case .vegasOdds: return "Vegas Odds"
            case .pokerNight: return "Poker Night"
            case .backyardChallenge: return "Backyard Challenge"
            case .golfSimulator: return "Golf Simulator"
            case .drinkingGames: return "Drinking Games"
            case .weekendTrip: return "Weekend Trip"
            case .boardVideoGames: return "Board/Video Games"
            case .closingCeremonies: return "Closing Ceremonies"
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
                    ForEach(EventType.all) { event in
                        NavigationLink(value: event) {
                            Text(event.title)
                                .font(.headline)
                                .padding(.vertical, 8)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .navigationTitle("In Person Events")
                .background(Color.background)
                .navigationDestination(for: EventType.self) { event in
                    switch event {

                    case .vegasOdds:
                        // ✅ New Vegas Odds flow entry point
                        VegasOddsHomeView()

                    case .pokerNight:
                        PokerNightView(eventId: pokerNightEventId)

                    default:
                        ComingSoonView(title: event.title)
                    }
                }
            }
        }
    }
}
