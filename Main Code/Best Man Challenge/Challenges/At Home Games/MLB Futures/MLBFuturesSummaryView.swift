import SwiftUI

struct MLBFuturesSummaryView: View {
    @ObservedObject var store: MLBFuturesStore

    private var sortedRows: [MLBFuturesTeamSummary] {
        store.summaryRows.sorted {
            if $0.championPickCount != $1.championPickCount {
                return $0.championPickCount > $1.championPickCount
            }
            if $0.worldSeriesPickCount != $1.worldSeriesPickCount {
                return $0.worldSeriesPickCount > $1.worldSeriesPickCount
            }
            if $0.csPickCount != $1.csPickCount {
                return $0.csPickCount > $1.csPickCount
            }
            if $0.dsPickCount != $1.dsPickCount {
                return $0.dsPickCount > $1.dsPickCount
            }
            return $0.averageDivisionFinish < $1.averageDivisionFinish
        }
    }

    private var totalPicks: Int {
        max(store.picks.count, 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                if store.picks.isEmpty {
                    ContentUnavailableView(
                        "No Picks Yet",
                        systemImage: "chart.bar",
                        description: Text("Summary data will appear once players submit their picks.")
                    )
                    .padding(.top, 40)

                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Futures Market")
                            .font(.title2.bold())

                        Text("Based on \(store.picks.count) submitted pick\(store.picks.count == 1 ? "" : "s").")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    LazyVStack(spacing: 12) {
                        ForEach(sortedRows, id: \.teamId) { row in
                            futuresMarketCard(for: row)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .padding(.top)
        }
        .navigationTitle("Summary")
    }

    @ViewBuilder
    private func futuresMarketCard(for row: MLBFuturesTeamSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(MLBFuturesConstants.teamName(row.teamId))
                        .font(.headline)

                    Text(row.divisionLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Avg Finish")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(String(format: "%.2f", row.averageDivisionFinish))
                        .font(.headline)
                }
            }

            Divider()

            VStack(spacing: 10) {
                marketMetricRow(
                    title: "Division Series",
                    count: row.dsPickCount,
                    total: totalPicks
                )

                marketMetricRow(
                    title: "Championship Series",
                    count: row.csPickCount,
                    total: totalPicks
                )

                marketMetricRow(
                    title: "World Series",
                    count: row.worldSeriesPickCount,
                    total: totalPicks
                )

                marketMetricRow(
                    title: "Champion",
                    count: row.championPickCount,
                    total: totalPicks,
                    highlight: true
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func marketMetricRow(
        title: String,
        count: Int,
        total: Int,
        highlight: Bool = false
    ) -> some View {
        let pct = percentage(count: count, total: total)

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .fontWeight(highlight ? .semibold : .regular)

                Spacer()

                Text("\(count)/\(total)")
                    .foregroundStyle(.secondary)

                Text("\(pct)%")
                    .fontWeight(highlight ? .bold : .medium)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))

                    Capsule()
                        .fill(highlight ? Color.yellow.opacity(0.85) : Color.blue.opacity(0.85))
                        .frame(width: geo.size.width * CGFloat(pct) / 100.0)
                }
            }
            .frame(height: 10)
        }
    }

    private func percentage(count: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(count) / Double(total) * 100).rounded())
    }
}
