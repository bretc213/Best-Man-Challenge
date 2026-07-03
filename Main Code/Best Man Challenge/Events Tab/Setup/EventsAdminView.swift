//
//  EventsAdminView.swift
//  Best Man Challenge
//
//  Admin-only overview of all in-person event RSVPs.
//  Shows yes / no / maybe counts per event; tap to see each player's response.
//

import SwiftUI
import FirebaseFirestore

struct EventsAdminView: View {
    @EnvironmentObject var store: EventsStore

    var body: some View {
        ThemedScreen {
            List {
                ForEach(store.events) { event in
                    NavigationLink {
                        EventRSVPListView(event: event)
                    } label: {
                        EventRSVPSummaryRow(event: event)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.background)
            .navigationTitle("RSVP Admin")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Summary row (fetches counts on appear)

struct EventRSVPSummaryRow: View {
    let event: AppEvent

    @State private var yesCount  = 0
    @State private var noCount   = 0
    @State private var maybeCount = 0
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(event.title).font(.headline)
            Text(shortDateRange(event))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if loaded {
                HStack(spacing: 16) {
                    rsvpBadge(count: yesCount,   label: "Yes",   color: .green)
                    rsvpBadge(count: noCount,    label: "No",    color: .red)
                    rsvpBadge(count: maybeCount, label: "Maybe", color: .orange)
                }
                .padding(.top, 2)
            } else {
                ProgressView().scaleEffect(0.75).padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .task { await loadCounts() }
    }

    @ViewBuilder
    private func rsvpBadge(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(count) \(label)")
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
        }
    }

    private func loadCounts() async {
        guard let id = event.id else { loaded = true; return }
        guard let snap = try? await Firestore.firestore()
            .collection("events").document(id).collection("rsvps")
            .getDocuments() else { loaded = true; return }

        var y = 0, n = 0, m = 0
        for doc in snap.documents {
            switch doc.data()["status"] as? String {
            case "yes":   y += 1
            case "no":    n += 1
            case "maybe": m += 1
            default: break
            }
        }
        yesCount = y; noCount = n; maybeCount = m
        loaded = true
    }

    private func shortDateRange(_ e: AppEvent) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        let cal = Calendar.current
        if cal.isDate(e.startDate, inSameDayAs: e.endDate) {
            return f.string(from: e.startDate)
        }
        f.dateStyle = .short
        return "\(f.string(from: e.startDate)) – \(f.string(from: e.endDate))"
    }
}
