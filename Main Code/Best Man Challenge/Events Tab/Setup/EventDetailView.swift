//
//  EventDetailView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/20/26.
//


import SwiftUI

struct EventDetailView: View {
    let event: AppEvent

    @EnvironmentObject var store: EventsStore
    @EnvironmentObject var session: SessionStore

    @State private var selected: RSVPStatus = .yes
    @State private var reason: String = ""
    @State private var isSaving = false
    @State private var error: String?
    @State private var showSaved = false

    var body: some View {
        ThemedScreen {
            VStack(alignment: .leading, spacing: 14) {
                Text(event.title)
                    .font(.title2.bold())

                Text(dateRangeText(event))
                    .foregroundStyle(.secondary)

                if let loc = event.location, !loc.isEmpty {
                    Text("Location: \(loc)")
                        .foregroundStyle(.secondary)
                }

                Divider().opacity(0.3)

                Text("RSVP")
                    .font(.headline)

                HStack(spacing: 10) {
                    ForEach(RSVPStatus.allCases, id: \.self) { s in
                        Button {
                            selected = s
                            if s == .yes { reason = "" }
                        } label: {
                            Text(s.label)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(selected == s ? nil : .gray)
                    }
                }

                if selected == .no || selected == .maybe {
                    TextField("Reason (optional)", text: $reason, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                }

                if let error {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }

                Button {
                    Task { await save() }
                } label: {
                    Text(isSaving ? "Saving..." : "Submit RSVP")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)

                Spacer()
            }
            .padding()
            .navigationTitle("Event")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Saved", isPresented: $showSaved) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your RSVP was saved.")
            }
        }
    }

    private func save() async {
        guard let id = event.id else { return }
        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            let name = session.profile?.displayName
            try await store.submitRSVP(eventId: id, status: selected, reason: reason, displayName: name)
            showSaved = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func dateRangeText(_ e: AppEvent) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short

        let cal = Calendar.current
        if cal.isDate(e.startDate, inSameDayAs: e.endDate) {
            return df.string(from: e.startDate)
        } else {
            let d1 = df.string(from: e.startDate)
            let d2 = df.string(from: e.endDate)
            return "\(d1) → \(d2)"
        }
    }
}
