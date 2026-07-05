import Foundation
import SwiftData

@Observable
@MainActor
final class WatchlistViewModel {
    private let cache: StockCache

    var items: [WatchlistItem] = []
    var lastUpdated: Date?
    var isLoading = false
    private var timer: Timer?

    init(context: ModelContext) {
        self.cache = StockCache(context: context)
        loadItems()
    }

    func loadItems() {
        items = cache.watchlistItems()
    }

    func startAutoRefresh() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshQuotes()
            }
        }
        Task {
            await refreshQuotes()
        }
    }

    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    func refreshQuotes() async {
        guard !items.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        let symbols = items.map { codeToSymbol($0.stockCode) }
        let quotes = await SinaAPI.realTimeQuotes(symbols: symbols)
        let quoteMap = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })

        for item in items {
            if let quote = quoteMap[codeToSymbol(item.stockCode)] {
                item.currentPrice = quote.currentPrice
                item.changePercent = quote.changePercent
                item.lastUpdated = Date()
            }
        }

        cache.updateWatchlist(items: items)
        lastUpdated = Date()
    }

    func remove(item: WatchlistItem) {
        cache.removeFromWatchlist(stockCode: item.stockCode)
        loadItems()
    }
}

private func codeToSymbol(_ code: String) -> String {
    if code.hasPrefix("6") { return "sh\(code)" }
    if code.hasPrefix("0") || code.hasPrefix("3") { return "sz\(code)" }
    return code
}
