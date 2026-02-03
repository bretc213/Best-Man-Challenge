import SwiftUI

struct ComingSoonChallengeView: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let startsAt: Date?

    init(
        title: String,
        subtitle: String? = "Challenge details coming soon",
        systemImage: String = "clock.fill",
        startsAt: Date? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.startsAt = startsAt
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        ThemedScreen {
            VStack(spacing: 18) {
                Spacer()

                Image(systemName: systemImage)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(Color.accent)

                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                if let startsAt {
                    Text("Starts \(Self.dateFormatter.string(from: startsAt))")
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary.opacity(0.90))
                        .padding(.top, 2)
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    NavigationView {
        ComingSoonChallengeView(
            title: "March Madness",
            startsAt: Date()
        )
    }
}
