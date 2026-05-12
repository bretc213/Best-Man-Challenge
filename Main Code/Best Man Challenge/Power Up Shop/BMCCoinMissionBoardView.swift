import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct BMCCoinMissionBoardView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var configStore = BMCCoinConfigStore()
    @StateObject private var missionsStore = BMCMissionsStore()
    @StateObject private var walletStore = BMCCoinWalletStore()

    @State private var proofTextByMission: [String: String] = [:]
    @State private var proofCodeByMission: [String: String] = [:]
    @State private var selectedMediaByMission: [String: SelectedProofMedia] = [:]
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var isSubmittingMissionId: String?

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

    private var visibleMissions: [BMCCoinMission] {
        guard configStore.config.isMissionWindowOpenNow else { return [] }
        return missionsStore.missions.filter { $0.isCurrentlyAvailable }
    }

    var body: some View {
        List {
            walletSection
            missionWindowSection
            activeMissionSection

            if isAdmin, !missionsStore.pendingClaims.isEmpty {
                adminPreviewSection
            }
        }
        .navigationTitle("Missions")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    BMCMissionInfoView(config: configStore.config)
                } label: {
                    Label("Info", systemImage: "info.circle")
                }

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
        .alert("Missions", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var walletSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(configStore.config.currencyName)
                        .font(.headline)
                    Text("Complete missions, get approved, then spend coins in the shop.")
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
                Label("Open Power-Up Shop", systemImage: "cart.fill")
                    .font(.headline)
            }

            NavigationLink {
                BMCMissionInfoView(config: configStore.config)
            } label: {
                Label("Mission Rules & Info", systemImage: "info.circle.fill")
                    .font(.headline)
            }

            if isAdmin {
                NavigationLink {
                    BMCMissionAdminReviewView()
                } label: {
                    Label("Admin Review Claims", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                }
            }
        }
    }

    private var missionWindowSection: some View {
        Section(configStore.config.missionWindowTitle) {
            if configStore.config.isMissionWindowOpenNow {
                Label("Missions are live until 11:59 PM tonight.", systemImage: "bolt.fill")
                    .foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Missions are closed", systemImage: "lock.fill")
                        .foregroundStyle(.secondary)
                    Text(configStore.config.missionWindowClosedMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var activeMissionSection: some View {
        Section("Active Missions") {
            if visibleMissions.isEmpty {
                Text(configStore.config.isMissionWindowOpenNow ? "No missions are live right now." : configStore.config.missionWindowClosedMessage)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(visibleMissions) { mission in
                    missionRow(mission)
                }
            }
        }
    }

    private var adminPreviewSection: some View {
        Section("Pending Claims") {
            ForEach(Array(missionsStore.pendingClaims.prefix(3))) { claim in
                VStack(alignment: .leading, spacing: 6) {
                    Text(claim.displayName)
                        .font(.headline)
                    Text(claim.missionTitle ?? claim.missionId)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("+\(claim.coinReward) \(configStore.config.currencyName)")
                        .font(.caption.weight(.semibold))
                }
            }

            NavigationLink("Review All Claims") {
                BMCMissionAdminReviewView()
            }
        }
    }

    private func missionRow(_ mission: BMCCoinMission) -> some View {
        let missionId = mission.id ?? ""
        let latestClaim = missionsStore.latestClaim(for: missionId)
        let isSubmitting = isSubmittingMissionId == missionId

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mission.title)
                        .font(.headline)
                    Text(mission.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("+\(mission.coinReward)")
                    .font(.headline)
            }

            proofInputs(for: mission)

            HStack {
                claimStatusView(latestClaim)

                Spacer()

                Button(isSubmitting ? "Submitting..." : "Submit Claim") {
                    submit(mission)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting || latestClaim?.status == .pending || latestClaim?.status == .approved)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func proofInputs(for mission: BMCCoinMission) -> some View {
        let missionId = mission.id ?? ""

        if mission.proofType.needsCode {
            TextField("Enter mission code", text: codeBinding(for: missionId))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
        }

        if mission.proofType.needsText {
            TextField("Add proof note", text: textBinding(for: missionId), axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
        }

        if mission.proofType.needsMedia {
            BMCProofPickerRow(
                selectedMedia: Binding(
                    get: { selectedMediaByMission[missionId] },
                    set: { selectedMediaByMission[missionId] = $0 }
                ),
                proofType: mission.proofType
            )
        }
    }

    @ViewBuilder
    private func claimStatusView(_ claim: BMCCoinMissionClaim?) -> some View {
        switch claim?.status {
        case .approved:
            Label("Approved", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
        case .pending:
            Label("Pending Review", systemImage: "clock.fill")
                .foregroundStyle(.orange)
        case .denied:
            Label("Denied — resubmit", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .none:
            EmptyView()
        }
    }

    private func textBinding(for missionId: String) -> Binding<String> {
        Binding(
            get: { proofTextByMission[missionId, default: ""] },
            set: { proofTextByMission[missionId] = $0 }
        )
    }

    private func codeBinding(for missionId: String) -> Binding<String> {
        Binding(
            get: { proofCodeByMission[missionId, default: ""] },
            set: { proofCodeByMission[missionId] = $0 }
        )
    }

    private func submit(_ mission: BMCCoinMission) {
        Task {
            guard let missionId = mission.id else { return }

            do {
                isSubmittingMissionId = missionId

                let selectedMedia = selectedMediaByMission[missionId]
                var uploaded: BMCUploadedProofMedia?

                if mission.proofType.needsMedia {
                    guard let selectedMedia else {
                        throw NSError(domain: "BMCCoinMissionBoardView", code: 10, userInfo: [NSLocalizedDescriptionKey: "Please attach proof before submitting."])
                    }

                    uploaded = try await BMCProofUploadService.uploadProof(
                        data: selectedMedia.data,
                        playerId: playerId,
                        missionId: missionId,
                        fileExtension: selectedMedia.fileExtension,
                        contentType: selectedMedia.contentType,
                        mediaType: selectedMedia.mediaType
                    )
                }

                try await missionsStore.submitClaim(
                    mission: mission,
                    playerId: playerId,
                    displayName: displayName,
                    proofText: proofTextByMission[missionId],
                    proofCode: proofCodeByMission[missionId],
                    proofMediaURL: uploaded?.url,
                    proofMediaType: uploaded?.mediaType,
                    proofFileName: uploaded?.fileName
                )

                proofTextByMission[missionId] = ""
                proofCodeByMission[missionId] = ""
                selectedMediaByMission[missionId] = nil
                alertMessage = "Claim submitted for review. You’ll receive coins after approval."
                showAlert = true
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }

            isSubmittingMissionId = nil
        }
    }
}

struct SelectedProofMedia: Equatable {
    let data: Data
    let fileExtension: String
    let contentType: String
    let mediaType: BMCProofMediaType
}

struct BMCProofPickerRow: View {
    @Binding var selectedMedia: SelectedProofMedia?
    let proofType: BMCCoinProofType

    @State private var pickerItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var matching: PHPickerFilter {
        switch proofType {
        case .video, .videoAndText:
            return .videos
        case .anyMedia:
            return .any(of: [.images, .videos])
        default:
            return .images
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PhotosPicker(selection: $pickerItem, matching: matching) {
                Label(selectedMedia == nil ? "Attach Proof" : "Replace Proof", systemImage: "paperclip")
            }
            .buttonStyle(.bordered)
            .onChange(of: pickerItem) { newValue in
                Task { await load(newValue) }
            }

            if isLoading {
                ProgressView("Loading proof...")
            }

            if selectedMedia != nil {
                Label("Proof attached", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw BMCProofUploadError.invalidData
            }

            let contentType = item.supportedContentTypes.first
            let isVideo = contentType?.conforms(to: .movie) == true || contentType?.conforms(to: .video) == true
            let isPNG = contentType == .png
            let ext = isVideo ? "mov" : (isPNG ? "png" : "jpg")
            let mime = isVideo ? "video/quicktime" : (isPNG ? "image/png" : "image/jpeg")
            let mediaType: BMCProofMediaType = isVideo ? .video : .image

            selectedMedia = SelectedProofMedia(
                data: data,
                fileExtension: ext,
                contentType: mime,
                mediaType: mediaType
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
