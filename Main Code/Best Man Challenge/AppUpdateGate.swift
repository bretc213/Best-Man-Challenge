//
//  AppUpdateGate.swift
//  Best Man Challenge
//
//  Forces users onto TestFlight to update when their installed build is older
//  than the minimum version set remotely in Firestore.
//
//  Firestore config (create once):
//    Collection: app_config
//    Document:   ios
//    Fields:
//      minimum_version : String  e.g. "6.8.0"   (required — the lowest build allowed)
//      message         : String  (optional — custom text shown on the update screen)
//
//  To force everyone to update: bump minimum_version in Firestore to your newest
//  build's version. No app rebuild needed.
//

import SwiftUI
import FirebaseFirestore

// MARK: - Checker

@MainActor
final class AppUpdateChecker: ObservableObject {
    /// True only after Firestore confirms the installed build is too old.
    @Published var updateRequired = false
    /// Optional custom message from Firestore to show on the update screen.
    @Published var message: String?

    /// The app's marketing version, e.g. "6.8.0" (CFBundleShortVersionString).
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Reads the minimum required version from Firestore and compares.
    /// Fails OPEN: any error or missing config leaves the app usable so a
    /// Firestore hiccup can never lock everyone out.
    func check() async {
        do {
            let snap = try await Firestore.firestore()
                .collection("app_config")
                .document("ios")
                .getDocument()

            guard
                snap.exists,
                let data = snap.data(),
                let minimum = (data["minimum_version"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                !minimum.isEmpty
            else {
                updateRequired = false
                return
            }

            message = data["message"] as? String

            // Numeric compare handles multi-digit segments correctly
            // (e.g. "6.9.0" < "6.10.0").
            let current = Self.currentVersion
            updateRequired = current.compare(minimum, options: .numeric) == .orderedAscending

            if updateRequired {
                print("⛔️ Update required — installed \(current) < minimum \(minimum)")
            }
        } catch {
            print("⚠️ Version check failed (allowing app to continue): \(error.localizedDescription)")
            updateRequired = false
        }
    }
}

// MARK: - Blocking screen

struct UpdateRequiredView: View {
    /// Optional custom message from Firestore.
    var message: String?

    // TestFlight app URL scheme, with an App Store fallback if TestFlight
    // isn't installed.
    private let testFlightScheme = URL(string: "itms-beta://")!
    private let testFlightAppStore = URL(string: "https://apps.apple.com/app/testflight/id899247664")!

    var body: some View {
        ThemedScreen {
            VStack(spacing: 18) {
                Spacer(minLength: 20)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 96, height: 96)

                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(Color.accent)
                }

                Text("Update Required")
                    .font(.title2.bold())
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message ?? "A newer version of Best Man Challenge is available. Please update in TestFlight to keep playing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Button {
                    openTestFlight()
                } label: {
                    Text("Update in TestFlight")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accent)
                .padding(.horizontal, 32)
                .padding(.top, 4)

                Text("You’re on version \(AppUpdateChecker.currentVersion)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 20)
            }
            .padding()
        }
        // No dismiss, no tabs — this screen fully blocks the app.
        .interactiveDismissDisabled(true)
    }

    private func openTestFlight() {
        if UIApplication.shared.canOpenURL(testFlightScheme) {
            UIApplication.shared.open(testFlightScheme)
        } else {
            UIApplication.shared.open(testFlightAppStore)
        }
    }
}

#Preview {
    UpdateRequiredView()
}
