import SwiftUI

struct BackyardAdminResetView: View {
    @EnvironmentObject private var store: BackyardChallengeStore

    @State private var showConfirm = false
    @State private var isResetting = false

    var body: some View {
        ThemedScreen {
            List {
                Section("Testing Reset") {
                    Text("This will delete all Backyard Challenge scores, hole entries, round entries, bracket results, closest-to-the-pin state, and relay times from Firestore.")
                        .foregroundStyle(.secondary)

                    Button(role: .destructive) {
                        showConfirm = true
                    } label: {
                        HStack {
                            if isResetting {
                                ProgressView()
                            }

                            Text(isResetting ? "Resetting..." : "Full Reset All Backyard Scores")
                        }
                    }
                    .disabled(isResetting)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Admin Reset")
            .alert("Are you sure?", isPresented: $showConfirm) {
                Button("Cancel", role: .cancel) {}

                Button("Reset Everything", role: .destructive) {
                    Task {
                        isResetting = true
                        await store.fullResetForTesting()
                        isResetting = false
                    }
                }
            } message: {
                Text("This is only for testing. This cannot be undone.")
            }
        }
    }
}
