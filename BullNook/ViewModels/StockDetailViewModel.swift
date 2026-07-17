import Foundation
import SwiftData

@Observable
@MainActor
final class StockDetailViewModel {
    private let cache: StockCache
    let pick: DailyPick

    var kline: [KLineData] = []
    var selectedPeriod: KLinePeriod = .daily
    var f10: F10Metric?
    var isInWatchlist = false
    var isLoading = false

    init(pick: DailyPick, context: ModelContext) {
        self.pick = pick
        self.cache = StockCache(context: context)
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        let symbol = codeToSymbol(pick.stockCode)
        await loadKLine(symbol: symbol)
        await loadF10(symbol: symbol)
        isInWatchlist = cache.isInWatchlist(stockCode: pick.stockCode)
        print("[Watchlist] StockDetail loadData, isInWatchlist=\(isInWatchlist)")
    }

    private func loadKLine(symbol: String) async {
        let cached = cache.kline(symbol: symbol, period: selectedPeriod)
        if cached.count >= minCount(for: selectedPeriod) {
            kline = cached
            print("[KLine] use cache \(symbol) \(selectedPeriod.rawValue) count=\(cached.count)")
            return
        }

        let today = DateFormatter.yyyyMMdd.string(from: Date())
        var fetched = await EastMoneyAPI.kline(symbol: symbol, period: selectedPeriod, start: "20240101", end: today)
        print("[KLine] EastMoney \(symbol) \(selectedPeriod.rawValue) count=\(fetched.count)")

        // Fallback to Sina K-line
        if fetched.isEmpty {
            fetched = await SinaAPI.kline(symbol: symbol, period: selectedPeriod, count: 250)
            print("[KLine] Sina fallback \(symbol) \(selectedPeriod.rawValue) count=\(fetched.count)")
        }

        if !fetched.isEmpty {
            kline = fetched
            cache.save(kline: fetched, symbol: symbol, period: selectedPeriod)
        } else if cached.isEmpty {
            kline = []
        }
    }

    private func loadF10(symbol: String) async {
        f10 = cache.f10(symbol: symbol)
        if f10 != nil {
            print("[F10] use cache \(symbol)")
            return
        }

        var fetched = await EastMoneyAPI.f10(symbol: symbol)
        print("[F10] EastMoney \(symbol) result=\(fetched != nil ? "ok" : "empty")")

        // Fallback to search engine
        if fetched == nil || !hasMeaningfulData(fetched) {
            let code = pick.stockCode
            let search = await SearchEngineAPI.searchF10(keyword: "\(code) \(pick.stockName) F10 所属概念 财务指标")
            if let search = search {
                fetched = F10Metric(
                    symbol: symbol,
                    pe: search.pe,
                    pb: search.pb,
                    roe: search.roe,
                    revenueGrowth: search.revenueGrowth,
                    profitGrowth: search.profitGrowth,
                    industry: search.industry,
                    concepts: search.concepts,
                    source: "search"
                )
                print("[F10] search fallback \(symbol) ok")
            }
        }

        if let fetched = fetched {
            f10 = fetched
            cache.save(f10: fetched)
        }
    }

    private func hasMeaningfulData(_ f10: F10Metric?) -> Bool {
        guard let f10 = f10 else { return false }
        return f10.pe != 0 || f10.pb != 0 || f10.roe != 0
            || f10.revenueGrowth != 0 || f10.profitGrowth != 0
            || !f10.industry.isEmpty || !f10.concepts.isEmpty
            || f10.totalMarketCap != 0
    }

    func toggleWatchlist() {
        if isInWatchlist {
            cache.removeFromWatchlist(stockCode: pick.stockCode)
        } else {
            cache.addToWatchlist(stockCode: pick.stockCode, stockName: pick.stockName, industry: pick.industry)
        }
        // 以数据库实际状态为准，避免 UI 与持久化不一致
        isInWatchlist = cache.isInWatchlist(stockCode: pick.stockCode)
    }

    func switchPeriod(_ period: KLinePeriod) async {
        // 先清空当前 K 线，让 UI 立刻感知周期切换，避免旧周期数据残留
        kline = []
        selectedPeriod = period
        await loadData()
    }

    private func minCount(for period: KLinePeriod) -> Int {
        switch period {
        case .daily: return 60
        case .weekly: return 40
        case .monthly: return 6
        }
    }
}

private func codeToSymbol(_ code: String) -> String {
    if code.hasPrefix("6") { return "sh\(code)" }
    if code.hasPrefix("0") || code.hasPrefix("3") { return "sz\(code)" }
    return code
}
