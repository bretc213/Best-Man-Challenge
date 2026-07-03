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
    @State private var arrivalOption: String = ""
    @State private var isSaving = false
    @State private var error: String?
    @State private var showSaved = false
    @State private var existingRsvp: EventsStore.StoredRSVP?
    @State private var isLoadingRsvp = true

    private var needsReconfirmation: Bool {
        guard let rsvp = existingRsvp else { return false }
        return rsvp.rsvpVersion != event.rsvpVersion
    }

    var body: some View {
        ThemedScreen {
            VStack(alignment: .leading, spacing: 14) {
                Text(event.title)
                    .font(.title2.bold())

                Text(dateRangeText(event))
                    .foregroundStyle(.secondary)

                if let loc = event.location, !loc.isEmpty, loc != "TBD" {
                    Text("Location: \(loc)")
                        .foregroundStyle(.secondary)
                }

                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider().opacity(0.3)

                if isLoadingRsvp {
                    ProgressView()
                } else {
                    // Reconfirmation or confirmation banner
                    if needsReconfirmation {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                            Text("Event details changed — please re-confirm your RSVP.")
                                .font(.subheadline)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.15))
                        .cornerRadius(8)
                    } else if let rsvp = existingRsvp {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("You RSVPed: \(rsvp.status.label)")
                                .font(.subheadline)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.green.opacity(0.15))
                        .cornerRadius(8)
                    }

                    // Arrival options (multi-day trips only)
                    if let options = event.arrivalOptions, !options.isEmpty, selected == .yes || selected == .maybe {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("When are you arriving?")
                                .font(.headline)
                            ForEach(options, id: \.self) { option in
                                Button {
                                    arrivalOption = option
                                } label: {
                                    HStack {
                                        Text(option)
                                            .foregroundStyle(Color.primary)
                                        Spacer()
                                        if arrivalOption == option {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.accent)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(10)
                                    .background(arrivalOption == option ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                                    .cornerRadius(8)
                                }
                            }
                        }

                        Divider().opacity(0.3)
                    }

                    Text(existingRsvp == nil ? "RSVP" : "Update RSVP")
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
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Event")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadExistingRsvp() }
            .alert("Saved", isPresented: $showSaved) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your RSVP was saved.")
            }
        }
    }

    private func loadExistingRsvp() async {
        guard let id = event.id else { isLoadingRsvp = false; return }
        existingRsvp = await store.fetchMyRSVP(eventId: id)
        if let rsvp = existingRsvp {
            selected = rsvp.status
            reason = rsvp.reason
            arrivalOption = rsvp.arrivalOption ?? ""
        } else if let options = event.arrivalOptions, !options.isEmpty {
            arrivalOption = options[0] // default to first option
        }
        isLoadingRsvp = false
    }

    private func save() async {
        guard let id = event.id else { return }
        isSaving = true
        error = nil
        defer { isSaving = false }

        do {
            let name = session.profile?.displayName
            let arrival = (event.arrivalOptions?.isEmpty == false && !arrivalOption.isEmpty) ? arrivalOption : nil
            try await store.submitRSVP(eventId: id, status: selected, reason: reason, displayName: name, rsvpVersion: event.rsvpVersion, arrivalOption: arrival)
            existingRsvp = EventsStore.StoredRSVP(status: selected, reason: reason, rsvpVersion: event.rsvpVersion, arrivalOption: arrival)
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
