import SwiftUI
import SwiftData

struct HistoricalPicksView: View {
    @Environment(\.modelContext) private var context
    @State private var cache: StockCache?
    @State private var picks: [HistoricalPick] = []
    @State private var sortByPerformance = false
    @State private var isLoadingQuotes = false

    var body: some View {
        NavigationStack {
            List {
                Toggle("按涨跌幅排序", isOn: $sortByPerformance)
                    .foregroundStyle(Color.appTextPrimary)
                    .listRowBackground(Color.appCardBackground)

                ForEach(groupedPicks.keys.sorted(by: >), id: \.self) { date in
                    Section {
                        ForEach(displayedPicks(for: date)) { pick in
                            historicalRow(pick: pick)
                                .listRowBackground(Color.appCardBackground)
                        }
                    } header: {
                        Text(formattedDate(date))
                            .font(.subheadline)
                            .foregroundStyle(Color.appTextPrimary)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("历史推荐")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .background(Color.appBackground.ignoresSafeArea())
            .onAppear {
                if cache == nil {
                    cache = StockCache(context: context)
                }
                loadPicks()
            }
            .onChange(of: sortByPerformance) { _, _ in
                loadPicks()
            }
            .refreshable {
                loadPicks()
            }
        }
    }

    private func loadPicks() {
        guard let cache = cache else { return }
        picks = cache.historicalPicks()
        Task {
            await updatePerformance()
        }
    }

    private func updatePerformance() async {
        guard !picks.isEmpty else { return }
        isLoadingQuotes = true
        defer { isLoadingQuotes = false }

        let symbols = Array(Set(picks.map { codeToSymbol($0.stockCode) }))

        // 1. 获取最新行情
        var quotes = await SinaAPI.realTimeQuotes(symbols: symbols)
        if quotes.isEmpty {
            quotes = await EastMoneyAPI.realTimeQuotes(symbols: symbols)
        }
        let quoteMap = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })

        // 2. 按 symbol 分组，复用 K 线数据计算推荐日收盘价
        var klineCache: [String: [KLineData]] = [:]

        let updatedPicks = picks
        for index in updatedPicks.indices {
            let symbol = codeToSymbol(updatedPicks[index].stockCode)
            let pickDate = updatedPicks[index].date

            guard let quote = quoteMap[symbol], quote.previousClose > 0 else { continue }

            let pickPrice: Double
            if pickDate == DateFormatter.yyyyMMdd.string(from: Date()) {
                // 推荐日就是今天，直接用昨收作为成本参考
                pickPrice = quote.previousClose
            } else {
                if klineCache[symbol] == nil {
                    klineCache[symbol] = await EastMoneyAPI.kline(symbol: symbol, period: .daily, start: "20240101", end: DateFormatter.yyyyMMdd.string(from: Date()))
                }
                let kline = klineCache[symbol] ?? []
                pickPrice = kline.sorted { $0.date < $1.date }
                    .first { $0.date >= pickDate }?.close ?? quote.previousClose
            }

            guard pickPrice > 0 else { continue }
            let performance = (quote.currentPrice - pickPrice) / pickPrice * 100
            updatedPicks[index].performanceSincePick = performance
            updatedPicks[index].pickPrice = pickPrice
            updatedPicks[index].currentPrice = quote.currentPrice
        }

        picks = updatedPicks
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
        VStack(alignment: .leading, spacing: 10) {
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
                    if pick.currentPrice == 0 && isLoadingQuotes {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text(Color.formatChangePercent(pick.performanceSincePick))
                            .font(.headline)
                            .foregroundStyle(pick.performanceSincePick >= 0 ? Color.appUp : Color.appDown)
                    }
                    Text("得分 \(String(format: "%.1f", pick.score))")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }

            HStack(spacing: 16) {
                priceColumn(title: "推荐时", price: pick.pickPrice)
                priceColumn(title: "当前", price: pick.currentPrice)
            }
        }
        .padding(.vertical, 8)
    }

    private func priceColumn(title: String, price: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.appTextSecondary)
            Text(price > 0 ? String(format: "%.2f", price) : "--")
                .font(.subheadline)
                .foregroundStyle(Color.appTextPrimary)
        }
    }

    private func formattedDate(_ dateString: String) -> String {
        guard let date = DateFormatter.yyyyMMdd.date(from: dateString) else { return dateString }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
}

private func codeToSymbol(_ code: String) -> String {
    if code.hasPrefix("6") { return "sh\(code)" }
    if code.hasPrefix("0") || code.hasPrefix("3") { return "sz\(code)" }
    return code
}
