//
//  EventsRootView.swift
//  Best Man Challenge
//
//  Created by Bret Clemetson on 1/20/26.
//


import SwiftUI

struct EventsRootView: View {
    @StateObject private var store = EventsStore()
    @EnvironmentObject var session: SessionStore

    enum Mode: String, CaseIterable {
        case list = "List"
        case calendar = "Calendar"
    }

    @State private var mode: Mode = .list

    var body: some View {
        ThemedScreen {
            VStack(spacing: 12) {

                Picker("", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if let err = store.loadError {
                    Text(err).foregroundStyle(.red)
                }

                switch mode {
                case .list:
                    eventsList
                case .calendar:
                    eventsCalendar
                }
            }
            .onAppear { store.startListening() }
            .onDisappear { store.stopListening() }
            .navigationTitle("Events")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var eventsList: some View {
        List {
            Section("In Person Events") {
                ForEach(store.events) { e in
                    NavigationLink {
                        EventDetailView(event: e)
                            .environmentObject(store)
                            .environmentObject(session)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(e.title).font(.headline)
                            Text(dateRangeText(e))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var eventsCalendar: some View {
        VStack(spacing: 12) {
            DatePicker(
                "Select date",
                selection: $store.selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal)

            let todays = store.events(on: store.selectedDate)

            if todays.isEmpty {
                Text("No in-person events on this day.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            } else {
                List {
                    Section(dateHeader(store.selectedDate)) {
                        ForEach(todays) { e in
                            NavigationLink {
                                EventDetailView(event: e)
                                    .environmentObject(store)
                                    .environmentObject(session)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(e.title).font(.headline)
                                    Text(dateRangeText(e))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func dateHeader(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .full
        return f.string(from: d)
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
