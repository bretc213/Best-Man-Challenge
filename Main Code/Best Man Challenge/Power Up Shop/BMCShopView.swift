import SwiftUI

struct BMCShopView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var configStore = BMCCoinConfigStore()
    @StateObject private var walletStore = BMCCoinWalletStore()
    @StateObject private var shopStore = BMCShopStore()

    @State private var showAlert = false
    @State private var alertMessage = ""

    private var playerId: String {
        session.profile?.linkedPlayerId ?? session.profile?.accountId ?? "unknown"
    }

    private var displayName: String {
        session.profile?.displayName ?? "Player"
    }

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(configStore.config.currencyName)
                            .font(.headline)
                        Text("Use your coins on power-ups for upcoming events.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(walletStore.wallet?.balance ?? 0)")
                        .font(.title3.weight(.bold))
                }
                .padding(.vertical, 4)
            }

            Section("Power-Ups") {
                if shopStore.items.isEmpty {
                    Text("No shop items are live right now.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(shopStore.items) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.headline)
                                    Text(item.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(item.coinCost)")
                                    .font(.headline)
                            }

                            Text(item.rulesText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            HStack {
                                if let itemId = item.id {
                                    let owned = shopStore.ownedCount(for: itemId)
                                    if owned > 0 {
                                        Text("Owned: \(owned)")
                                            .font(.footnote.weight(.semibold))
                                    }
                                }

                                Spacer()

                                Button("Buy") {
                                    buy(item)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled((walletStore.wallet?.balance ?? 0) < item.coinCost)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Shop")
        .task {
            configStore.start()
            walletStore.start(playerId: playerId, displayName: displayName)
            shopStore.start(playerId: playerId)
        }
        .alert("Shop", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func buy(_ item: BMCCoinShopItem) {
        Task {
            do {
                try await shopStore.purchase(item: item, playerId: playerId, displayName: displayName)
                alertMessage = "Purchased \(item.title)."
                showAlert = true
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}
