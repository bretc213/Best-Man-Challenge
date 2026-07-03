//
//  EventRSVPListView.swift
//  Best Man Challenge
//
//  Admin view: all players' RSVPs for a single event, grouped by status.
//

import SwiftUI
import FirebaseFirestore

struct AdminRSVPEntry: Identifiable {
    var id: String          // uid
    var displayName: String
    var status: RSVPStatus
    var reason: String
    var arrivalOption: String?
}

struct EventRSVPListView: View {
    let event: AppEvent

    @State private var entries: [AdminRSVPEntry] = []
    @State private var isLoading = true

    private var yeses:  [AdminRSVPEntry] { entries.filter { $0.status == .yes   } }
    private var nos:    [AdminRSVPEntry] { entries.filter { $0.status == .no    } }
    private var maybes: [AdminRSVPEntry] { entries.filter { $0.status == .maybe } }

    var body: some View {
        ThemedScreen {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if entries.isEmpty {
                    Text("No RSVPs yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if !yeses.isEmpty {
                            Section("✅ Going (\(yeses.count))") {
                                ForEach(yeses) { rsvpRow($0) }
                            }
                        }
                        if !maybes.isEmpty {
                            Section("🤔 Maybe (\(maybes.count))") {
                                ForEach(maybes) { rsvpRow($0) }
                            }
                        }
                        if !nos.isEmpty {
                            Section("❌ Not Going (\(nos.count))") {
                                ForEach(nos) { rsvpRow($0) }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.background)
                }
            }
            .navigationTitle(event.title)
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadRSVPs() }
        }
    }

    @ViewBuilder
    private func rsvpRow(_ entry: AdminRSVPEntry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.displayName.isEmpty ? "Unknown Player" : entry.displayName)
                .font(.headline)
            if let arrival = entry.arrivalOption, !arrival.isEmpty {
                Label(arrival, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !entry.reason.isEmpty {
                Text("\"\(entry.reason)\"")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 2)
    }

    private func loadRSVPs() async {
        guard let id = event.id else { isLoading = false; return }
        guard let snap = try? await Firestore.firestore()
            .collection("events").document(id).collection("rsvps")
            .getDocuments() else { isLoading = false; return }

        entries = snap.documents.compactMap { doc -> AdminRSVPEntry? in
            let data = doc.data()
            guard let rawStatus = data["status"] as? String,
                  let status = RSVPStatus(rawValue: rawStatus) else { return nil }
            return AdminRSVPEntry(
                id: doc.documentID,
                displayName: data["displayName"] as? String ?? "",
                status: status,
                reason: data["reason"] as? String ?? "",
                arrivalOption: data["arrivalOption"] as? String
            )
        }
        .sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }

        isLoading = false
    }
}
