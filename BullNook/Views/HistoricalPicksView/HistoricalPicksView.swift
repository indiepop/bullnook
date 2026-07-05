import SwiftUI
import SwiftData

struct HistoricalPicksView: View {
    @Environment(\.modelContext) private var context
    @State private var cache: StockCache?
    @State private var picks: [HistoricalPick] = []
    @State private var sortByPerformance = false

    var body: some View {
        NavigationStack {
            List {
                Toggle("按涨跌幅排序", isOn: $sortByPerformance)
                    .foregroundStyle(Color.appTextPrimary)

                ForEach(groupedPicks.keys.sorted(by: >), id: \.self) { date in
                    Section(date) {
                        ForEach(displayedPicks(for: date)) { pick in
                            historicalRow(pick: pick)
                        }
                    }
                }
            }
            .navigationTitle("历史推荐")
            .background(Color.appBackground.ignoresSafeArea())
            .onAppear {
                if cache == nil {
                    cache = StockCache(context: context)
                }
                picks = cache?.historicalPicks() ?? []
            }
            .onChange(of: sortByPerformance) { _, _ in
                picks = cache?.historicalPicks() ?? []
            }
        }
    }

    private var groupedPicks: [String: [HistoricalPick]] {
        Dictionary(grouping: picks, by: { $0.date })
    }

    private func displayedPicks(for date: String) -> [HistoricalPick] {
        let group = groupedPicks[date] ?? []
        if sortByPerformance {
            return group.sorted { $0.performanceSincePick > $1.performanceSincePick }
        }
        return group.sorted { $0.rank < $1.rank }
    }

    private func historicalRow(pick: HistoricalPick) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(pick.rank). \(pick.stockName)")
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)
                Text(pick.stockCode)
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f%%", pick.performanceSincePick))
                    .font(.headline)
                    .foregroundStyle(pick.performanceSincePick >= 0 ? Color.appUp : Color.appDown)
                Text("得分 \(String(format: "%.1f", pick.score))")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}
