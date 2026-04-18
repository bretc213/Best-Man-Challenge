import SwiftUI

struct BMCCoinMissionBoardView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var configStore = BMCCoinConfigStore()
    @StateObject private var missionsStore = BMCMissionsStore()
    @StateObject private var walletStore = BMCCoinWalletStore()

    @State private var proofTextByMission: [String: String] = [:]
    @State private var alertMessage = ""
    @State private var showAlert = false

    private var playerId: String {
        session.profile?.linkedPlayerId ?? session.profile?.accountId ?? "unknown"
    }

    private var displayName: String {
        session.profile?.displayName ?? "Player"
    }

    private var isAdmin: Bool {
        let role = session.profile?.role.lowercased() ?? ""
        return role == "admin" || role == "owner" || role == "ref"
    }

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(configStore.config.currencyName)
                            .font(.headline)
                        Text("Complete missions to earn coins, then spend them in the shop.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(walletStore.wallet?.balance ?? 0)")
                        .font(.title3.weight(.bold))
                }
                .padding(.vertical, 4)

                NavigationLink {
                    BMCShopView()
                } label: {
                    HStack {
                        Label("Open Shop", systemImage: "cart.fill")
                            .font(.headline)
                        Spacer()
                        Text("Spend \(configStore.config.currencyName)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Active Missions") {
                let activeMissions = missionsStore.missions.filter { $0.isCurrentlyAvailable }

                if activeMissions.isEmpty {
                    Text("No missions are live right now.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activeMissions) { mission in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(mission.title)
                                    .font(.headline)
                                Spacer()
                                Text("+\(mission.coinReward)")
                                    .font(.subheadline.weight(.semibold))
                            }

                            Text(mission.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if mission.proofType == .text || mission.proofType == .photoAndText {
                                TextField("Add proof note", text: binding(for: mission.id ?? ""))
                                    .textFieldStyle(.roundedBorder)
                            }

                            HStack {
                                if missionsStore.hasApprovedClaim(for: mission.id ?? "") {
                                    Label("Approved", systemImage: "checkmark.seal.fill")
                                        .foregroundStyle(.green)
                                } else if missionsStore.hasPendingClaim(for: mission.id ?? "") {
                                    Label("Pending Review", systemImage: "clock.fill")
                                        .foregroundStyle(.orange)
                                } else {
                                    Button("Submit Claim") {
                                        submit(mission)
                                    }
                                    .buttonStyle(.borderedProminent)
                                }

                                Spacer()

                                if mission.repeatable {
                                    Text("Repeatable")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if isAdmin, !missionsStore.pendingClaims.isEmpty {
                Section("Pending Claims") {
                    ForEach(missionsStore.pendingClaims) { claim in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(claim.displayName)
                                .font(.headline)
                            Text("Mission: \(claim.missionId)")
                                .font(.subheadline)
                            if let proofText = claim.proofText, !proofText.isEmpty {
                                Text(proofText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Button("Approve") {
                                    approve(claim)
                                }
                                .buttonStyle(.borderedProminent)

                                Button("Deny") {
                                    deny(claim)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Missions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    BMCShopView()
                } label: {
                    Label("Shop", systemImage: "cart.fill")
                }
            }
        }
        .task {
            configStore.start()
            walletStore.start(playerId: playerId, displayName: displayName)
            missionsStore.start(forPlayerId: playerId, isAdmin: isAdmin)
        }
        .alert("Coins", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func binding(for missionId: String) -> Binding<String> {
        Binding(
            get: { proofTextByMission[missionId, default: ""] },
            set: { proofTextByMission[missionId] = $0 }
        )
    }

    private func submit(_ mission: BMCCoinMission) {
        Task {
            do {
                try await missionsStore.submitClaim(
                    mission: mission,
                    playerId: playerId,
                    displayName: displayName,
                    proofText: proofTextByMission[mission.id ?? ""],
                    proofImageURL: nil
                )
                alertMessage = "Claim submitted."
                showAlert = true
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    private func approve(_ claim: BMCCoinMissionClaim) {
        Task {
            do {
                try await missionsStore.approveClaim(claim: claim, reviewedBy: displayName, walletStore: walletStore)
                alertMessage = "Claim approved."
                showAlert = true
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    private func deny(_ claim: BMCCoinMissionClaim) {
        Task {
            do {
                try await missionsStore.denyClaim(claim: claim, reviewedBy: displayName)
                alertMessage = "Claim denied."
                showAlert = true
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}
