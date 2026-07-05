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
        let cached = cache.kline(symbol: symbol, period: selectedPeriod)
        if cached.count >= 60 {
            kline = cached
        } else {
            let today = DateFormatter.yyyyMMdd.string(from: Date())
            kline = await EastMoneyAPI.kline(symbol: symbol, period: selectedPeriod, start: "20240101", end: today)
            if !kline.isEmpty {
                cache.save(kline: kline)
            }
        }

        f10 = cache.f10(symbol: symbol)
        if f10 == nil {
            if let fetched = await EastMoneyAPI.f10(symbol: symbol) {
                f10 = fetched
                cache.save(f10: fetched)
            }
        }

        isInWatchlist = cache.isInWatchlist(stockCode: pick.stockCode)
    }

    func toggleWatchlist() {
        if isInWatchlist {
            cache.removeFromWatchlist(stockCode: pick.stockCode)
        } else {
            cache.addToWatchlist(stockCode: pick.stockCode, stockName: pick.stockName, industry: pick.industry)
        }
        isInWatchlist.toggle()
    }

    func switchPeriod(_ period: KLinePeriod) async {
        selectedPeriod = period
        await loadData()
    }
}

private func codeToSymbol(_ code: String) -> String {
    if code.hasPrefix("6") { return "sh\(code)" }
    if code.hasPrefix("0") || code.hasPrefix("3") { return "sz\(code)" }
    return code
}
