import SwiftUI
import AVKit

struct BMCMissionInfoView: View {
    let config: BMCCoinConfig

    var body: some View {
        List {
            Section(config.rulesTitle) {
                Text(config.rulesText)
                    .font(.body)

                if let urlString = config.rulesVideoURL,
                   let url = URL(string: urlString),
                   !urlString.isEmpty {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    Link("Open rules video", destination: url)
                } else {
                    Text("Add a rulesVideoURL field to coin_config/global when your explainer video is ready.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("How Missions Work") {
                Label("Missions open every Saturday from 12:00 AM to 11:59 PM.", systemImage: "calendar")
                Label("Submit the required proof: code, photo, video, note, or a combination.", systemImage: "paperclip")
                Label("Your claim goes to admin review before coins are awarded.", systemImage: "checkmark.seal")
            }

            Section("Coins") {
                Label("Approved missions add coins to your wallet.", systemImage: "dollarsign.circle")
                Label("Denied claims do not award coins, but you can resubmit if the mission is still live.", systemImage: "arrow.clockwise")
            }

            Section("Power-Ups") {
                Label("Coins can be spent in the Power-Up Shop.", systemImage: "cart.fill")
                Label("Cards must be presented before use. No secret cards.", systemImage: "eye.fill")
                Label("Current plan: one chaos card and one shop card per matchup.", systemImage: "rectangle.stack.fill")
            }
        }
        .navigationTitle("Rules & Info")
    }
}
