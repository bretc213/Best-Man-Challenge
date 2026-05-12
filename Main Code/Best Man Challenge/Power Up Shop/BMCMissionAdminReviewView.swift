import SwiftUI

struct BMCMissionAdminReviewView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var missionsStore = BMCMissionsStore()
    @StateObject private var walletStore = BMCCoinWalletStore()

    @State private var adminNoteByClaim: [String: String] = [:]
    @State private var alertMessage = ""
    @State private var showAlert = false

    private var displayName: String {
        session.profile?.displayName ?? "Admin"
    }

    private var playerId: String {
        session.profile?.linkedPlayerId ?? session.profile?.accountId ?? "unknown"
    }

    private var isAdmin: Bool {
        let role = session.profile?.role.lowercased() ?? ""
        return role == "admin" || role == "owner" || role == "ref"
    }

    var body: some View {
        List {
            if !isAdmin {
                Section {
                    Text("You do not have access to review mission claims.")
                        .foregroundStyle(.secondary)
                }
            } else {
                pendingSection
                recentSection
            }
        }
        .navigationTitle("Review Claims")
        .task {
            missionsStore.start(forPlayerId: playerId, isAdmin: isAdmin)
            walletStore.start(playerId: playerId, displayName: displayName)
        }
        .alert("Mission Review", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var pendingSection: some View {
        Section("Pending") {
            if missionsStore.pendingClaims.isEmpty {
                Text("No claims need review right now.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(missionsStore.pendingClaims) { claim in
                    claimReviewCard(claim)
                }
            }
        }
    }

    private var recentSection: some View {
        Section("Recently Reviewed") {
            if missionsStore.reviewedClaims.isEmpty {
                Text("No recently reviewed claims.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(missionsStore.reviewedClaims.prefix(10))) { claim in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(claim.displayName)
                                .font(.headline)
                            Spacer()
                            statusBadge(claim.status)
                        }
                        Text(claim.missionTitle ?? claim.missionId)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let reviewedBy = claim.reviewedBy {
                            Text("Reviewed by \(reviewedBy)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func claimReviewCard(_ claim: BMCCoinMissionClaim) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(claim.displayName)
                        .font(.headline)
                    Text(claim.missionTitle ?? claim.missionId)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("+\(claim.coinReward)")
                    .font(.headline)
            }

            proofBlock(claim)

            TextField("Admin note (optional)", text: Binding(
                get: { adminNoteByClaim[claim.id ?? "", default: ""] },
                set: { adminNoteByClaim[claim.id ?? ""] = $0 }
            ), axis: .vertical)
            .lineLimit(2...4)
            .textFieldStyle(.roundedBorder)

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
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func proofBlock(_ claim: BMCCoinMissionClaim) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let proofCode = claim.proofCode, !proofCode.isEmpty {
                Label("Code: \(proofCode)", systemImage: "number.square.fill")
                    .font(.subheadline.weight(.semibold))
            }

            if let proofText = claim.proofText, !proofText.isEmpty {
                Text(proofText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let urlString = claim.proofMediaURL ?? claim.proofImageURL, let url = URL(string: urlString) {
                if claim.proofMediaType == .image || claim.proofType == .photo || claim.proofType == .image || claim.proofType == .photoAndText {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure:
                            Link("Open proof media", destination: url)
                        case .empty:
                            ProgressView()
                        @unknown default:
                            Link("Open proof media", destination: url)
                        }
                    }
                    .frame(maxHeight: 220)
                } else {
                    Link("Open proof video/media", destination: url)
                        .font(.subheadline.weight(.semibold))
                }
            }

            if let submittedAt = claim.submittedAt?.dateValue() {
                Text("Submitted: \(submittedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statusBadge(_ status: BMCCoinClaimStatus) -> some View {
        Group {
            switch status {
            case .approved:
                Label("Approved", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            case .pending:
                Label("Pending", systemImage: "clock.fill")
                    .foregroundStyle(.orange)
            case .denied:
                Label("Denied", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.caption.weight(.semibold))
    }

    private func approve(_ claim: BMCCoinMissionClaim) {
        Task {
            do {
                try await missionsStore.approveClaim(
                    claim: claim,
                    reviewedBy: displayName,
                    walletStore: walletStore,
                    adminNote: adminNoteByClaim[claim.id ?? ""]
                )
                alertMessage = "Claim approved and coins awarded."
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
                try await missionsStore.denyClaim(
                    claim: claim,
                    reviewedBy: displayName,
                    adminNote: adminNoteByClaim[claim.id ?? ""]
                )
                alertMessage = "Claim denied."
                showAlert = true
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}
