import SwiftUI

struct WeeklyChallengeAdminWrapperView: View {
    @EnvironmentObject var session: SessionStore

    // ✅ Injected shared manager (do NOT create a new one here)
    @ObservedObject var manager: WeeklyChallengeManager

    private var isExec: Bool {
        let role = (session.profile?.role ?? "").lowercased()
        return role == "owner" || role == "commish" || role == "ref"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            if !isExec {
                Text("Admin only.")
                    .foregroundStyle(.secondary)
                Spacer()

            } else {
                switch manager.state {
                case .idle, .loading:
                    ProgressView("Loading...")
                        .padding(.top, 8)

                case .empty:
                    Text("No active weekly challenge.")
                        .foregroundStyle(.secondary)

                case .failed(let msg):
                    Text("Couldn’t load: \(msg)")
                        .foregroundStyle(.secondary)

                case .loaded:
                    if let ch = manager.currentChallenge {
                        WeeklyChallengeAdminAnswerKeyView(challenge: ch)
                    } else {
                        Text("No active weekly challenge.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.top, 8)
        .onAppear {
            // ✅ Keep manager user context fresh (optional but safe)
            manager.setUserContext(
                linkedPlayerId: session.profile?.linkedPlayerId,
                displayName: session.profile?.displayName
            )
        }
    }
}
