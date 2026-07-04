//
//  MurderMysteryAccusationView.swift
//  Best Man Challenge
//
//  "Dead in the Dust" — weekly accusation form + history
//

import SwiftUI

struct MurderMysteryAccusationView: View {
    @ObservedObject var store: MurderMysteryStore

    @State private var killer = ""
    @State private var weapon = ""
    @State private var location = ""
    @State private var ddKiller = false
    @State private var ddWeapon = false
    @State private var ddLocation = false
    @State private var submitted = false

    private var canSubmit: Bool {
        store.currentWeek > 0 && !store.hasAccusedThisWeek &&
        !killer.isEmpty && !weapon.isEmpty && !location.isEmpty
    }

    private var multiplierText: String {
        let m = store.currentMultiplier
        return m == floor(m) ? "\(Int(m))×" : String(format: "%.1f×", m)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if store.currentWeek == 0 {
                    weekZeroBanner
                }

                multiplierCard
                    .opacity(store.currentWeek == 0 ? 0.5 : 1)

                accusationForm
                    .opacity(store.currentWeek == 0 ? 0.5 : 1)
                    .disabled(store.currentWeek == 0)

                if !store.history.isEmpty {
                    historySection
                }
            }
            .padding(16)
        }
        .background(Color.background)
    }

    // MARK: - Week 0

    private var weekZeroBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
            Text("Advance to Week 1 to submit your first accusation.")
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(Color.accent)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.accent.opacity(0.12)))
    }

    // MARK: - Multiplier

    private var multiplierCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("WEEK \(store.currentWeek) MULTIPLIER")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("\(multiplierText) points")
                    .font(.title3.weight(.black))
                    .foregroundStyle(Color.accent)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("PER CORRECT VARIABLE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("100 pts × \(multiplierText)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.1)))
    }

    // MARK: - Form

    private var accusationForm: some View {
        VStack(spacing: 14) {
            pickerRow(title: "Killer", selection: $killer, doubleDown: $ddKiller,
                      options: MurderMysteryData.killerOptions)
            pickerRow(title: "Weapon", selection: $weapon, doubleDown: $ddWeapon,
                      options: MurderMysteryData.weaponOptions)
            pickerRow(title: "Location", selection: $location, doubleDown: $ddLocation,
                      options: MurderMysteryData.locationOptions)

            if store.hasAccusedThisWeek {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Accusation locked in for Week \(store.currentWeek).")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(.green)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.12)))
            }

            Button {
                store.submitAccusation(killer: killer, weapon: weapon, location: location,
                                       ddKiller: ddKiller, ddWeapon: ddWeapon, ddLocation: ddLocation)
                submitted = true
            } label: {
                Text("Submit Week \(store.currentWeek) Accusation")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(canSubmit ? Color.accent : Color.white.opacity(0.1)))
                    .foregroundStyle(canSubmit ? Color.black : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.1)))
    }

    private func pickerRow(title: String, selection: Binding<String>,
                           doubleDown: Binding<Bool>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) { selection.wrappedValue = option }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue.isEmpty ? "Select \(title.lowercased())…" : selection.wrappedValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selection.wrappedValue.isEmpty ? Color.secondary : Color.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
            }

            Toggle(isOn: doubleDown) {
                Text("Double Down on \(title)")
                    .font(.footnote)
                    .foregroundStyle(Color.textPrimary)
            }
            .toggleStyle(MMCheckboxToggleStyle())
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACCUSATION HISTORY")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            ForEach(store.history.sorted { $0.week > $1.week }) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Week \(entry.week)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.accent)
                        Spacer()
                        if store.isFinaleRevealed {
                            Text(entry.multiplier == floor(entry.multiplier)
                                 ? "\(Int(entry.multiplier))× · \(entry.pointsAwarded) pts"
                                 : String(format: "%.1f× · %d pts", entry.multiplier, entry.pointsAwarded))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accent)
                        } else {
                            HStack(spacing: 4) {
                                Text(entry.multiplier == floor(entry.multiplier)
                                     ? "\(Int(entry.multiplier))×"
                                     : String(format: "%.1f×", entry.multiplier))
                                Image(systemName: "lock.fill")
                                Text("Sealed until finale")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        }
                    }
                    historyLine(label: "Killer", value: entry.killer, dd: entry.doubleDownKiller)
                    historyLine(label: "Weapon", value: entry.weapon, dd: entry.doubleDownWeapon)
                    historyLine(label: "Location", value: entry.location, dd: entry.doubleDownLocation)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
            }
        }
    }

    private func historyLine(label: String, value: String, dd: Bool) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
            if dd {
                Text("2× DD")
                    .font(.system(size: 9, weight: .black))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accent.opacity(0.25)))
                    .foregroundStyle(Color.accent)
            }
            Spacer()
        }
    }
}

// MARK: - Checkbox toggle style

struct MMCheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(configuration.isOn ? Color.accent : .secondary)
                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}
