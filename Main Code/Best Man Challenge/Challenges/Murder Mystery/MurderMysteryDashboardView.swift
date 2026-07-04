//
//  MurderMysteryDashboardView.swift
//  Best Man Challenge
//
//  "Dead in the Dust" — dashboard + admin test controls
//

import SwiftUI

struct MurderMysteryDashboardView: View {
    @EnvironmentObject var session: SessionStore
    @ObservedObject var store: MurderMysteryStore

    @State private var jumpWeek: Int = 0
    @State private var showResetConfirm = false

    private var isAdmin: Bool {
        let role = (session.profile?.role ?? "").lowercased()
        return ["admin", "owner", "ref", "commish", "commissioner"].contains(role)
    }

    private var latestDrop: Drop? {
        MurderMysteryData.drops(throughWeek: store.currentWeek)
            .sorted { ($0.week, $0.isMidweek ? 1 : 0) > ($1.week, $1.isMidweek ? 1 : 0) }
            .first
    }

    private var openLocationCount: Int {
        MurderMysteryData.openLocations(week: store.currentWeek).count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                statsGrid
                if let drop = latestDrop {
                    latestDropCard(drop)
                }
                if isAdmin {
                    adminControls
                }
            }
            .padding(16)
        }
        .background(Color.background)
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEAD IN THE DUST")
                .font(.title2.weight(.black))
                .foregroundStyle(Color.accent)
            Text("A Hargrove Ranch Mystery")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Label("Week \(store.currentWeek) of \(MurderMysteryData.finalWeek)", systemImage: "calendar")
                Spacer()
                Label(multiplierText, systemImage: "bolt.fill")
                    .foregroundStyle(Color.accent)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.1)))
    }

    private var multiplierText: String {
        let m = store.currentMultiplier
        if m == 0 { return "No multiplier yet" }
        return m == floor(m) ? "\(Int(m))× multiplier" : String(format: "%.1f× multiplier", m)
    }

    // MARK: - Stats

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(value: "\(store.totalPoints)", label: "Points", icon: "star.fill")
            statCard(value: "\(MurderMysteryData.drops(throughWeek: store.currentWeek).count)", label: "Drops Received", icon: "tray.and.arrow.down.fill")
            statCard(value: "\(store.challengesSolved)", label: "Challenges Solved", icon: "checkmark.seal.fill")
            statCard(value: "\(openLocationCount) of \(MurderMysteryData.locations.count)", label: "Locations Open", icon: "map.fill")
        }
    }

    private func statCard(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accent)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))
    }

    // MARK: - Latest drop

    private func latestDropCard(_ drop: Drop) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LATEST DROP")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(drop.isMidweek ? "Week \(drop.week) · Mid-Week" : "Week \(drop.week) · Major")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accent.opacity(0.2)))
                    .foregroundStyle(Color.accent)
            }
            Text(drop.title)
                .font(.headline)
                .foregroundStyle(Color.textPrimary)
            Text(drop.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(4)
            if let clue = drop.clueNote {
                Text(clue)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accent)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.accent.opacity(0.12)))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.1)))
    }

    // MARK: - Admin controls

    private var adminControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver.fill")
                Text("ADMIN TEST MODE")
                    .font(.caption.weight(.black))
            }
            .foregroundStyle(.orange)

            HStack {
                Text("Week \(store.currentWeek) of \(MurderMysteryData.finalWeek)")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text(multiplierText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                store.advanceWeek()
                jumpWeek = store.currentWeek
            } label: {
                Label("Next Week", systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.25)))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .disabled(store.currentWeek >= MurderMysteryData.finalWeek)

            HStack {
                Text("Jump to Week")
                    .font(.subheadline)
                Spacer()
                Stepper("\(jumpWeek)", value: $jumpWeek, in: 0...MurderMysteryData.finalWeek)
                    .font(.subheadline.weight(.bold))
                    .fixedSize()
            }
            if jumpWeek != store.currentWeek {
                Button {
                    store.setWeek(jumpWeek)
                } label: {
                    Label("Jump to Week \(jumpWeek)", systemImage: "forward.end.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.25)))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("Reset All", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.18)))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.orange.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.orange.opacity(0.4), lineWidth: 1))
        .alert("Reset Murder Mystery?", isPresented: $showResetConfirm) {
            Button("Reset Everything", role: .destructive) {
                store.resetAll()
                jumpWeek = 0
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Week, points, accusation history, and solved challenges will all be cleared.")
        }
        .onAppear { jumpWeek = store.currentWeek }
    }
}
