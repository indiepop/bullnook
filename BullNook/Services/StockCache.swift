import Foundation
import SwiftData

@MainActor
final class StockCache {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Daily Picks

    func dailyPicks(for date: String) -> [DailyPick] {
        let descriptor = FetchDescriptor<DailyPick>(
            predicate: #Predicate { $0.date == date },
            sortBy: [SortDescriptor(\.rank)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func latestDailyPicks(limit: Int = 5) -> [DailyPick] {
        let descriptor = FetchDescriptor<DailyPick>(
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.rank)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return Array(all.prefix(limit))
    }

    func save(dailyPicks: [DailyPick]) {
        for pick in dailyPicks {
            context.insert(pick)
        }
        try? context.save()
    }

    func deleteAllDailyPicks(for date: String) {
        let descriptor = FetchDescriptor<DailyPick>(predicate: #Predicate { $0.date == date })
        guard let items = try? context.fetch(descriptor) else { return }
        for item in items {
            context.delete(item)
        }
        try? context.save()
    }

    // MARK: - Historical Picks

    func historicalPicks() -> [HistoricalPick] {
        let descriptor = FetchDescriptor<HistoricalPick>(
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.rank)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func save(historicalPicks: [HistoricalPick]) {
        for pick in historicalPicks {
            context.insert(pick)
        }
        try? context.save()
    }

    // MARK: - KLine

    func kline(symbol: String, period: KLinePeriod) -> [KLineData] {
        let descriptor = FetchDescriptor<KLineData>(
            predicate: #Predicate { $0.symbol == symbol },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func save(kline: [KLineData]) {
        for item in kline {
            context.insert(item)
        }
        try? context.save()
    }

    // MARK: - Watchlist

    func watchlistItems() -> [WatchlistItem] {
        let descriptor = FetchDescriptor<WatchlistItem>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func addToWatchlist(stockCode: String, stockName: String, industry: String = "") {
        let item = WatchlistItem(id: stockCode, stockCode: stockCode, stockName: stockName, industry: industry)
        context.insert(item)
        try? context.save()
    }

    func removeFromWatchlist(stockCode: String) {
        let descriptor = FetchDescriptor<WatchlistItem>(predicate: #Predicate { $0.stockCode == stockCode })
        guard let items = try? context.fetch(descriptor) else { return }
        for item in items {
            context.delete(item)
        }
        try? context.save()
    }

    func isInWatchlist(stockCode: String) -> Bool {
        let descriptor = FetchDescriptor<WatchlistItem>(predicate: #Predicate { $0.stockCode == stockCode })
        return (try? context.fetchCount(descriptor)) ?? 0 > 0
    }

    func updateWatchlist(items: [WatchlistItem]) {
        try? context.save()
    }

    // MARK: - Sectors / Dragon Tiger / F10

    func sectors(for date: String) -> [SectorData] {
        let descriptor = FetchDescriptor<SectorData>(predicate: #Predicate { $0.date == date })
        return (try? context.fetch(descriptor)) ?? []
    }

    func save(sectors: [SectorData]) {
        for item in sectors { context.insert(item) }
        try? context.save()
    }

    func dragonTiger(for date: String) -> [DragonTigerData] {
        let descriptor = FetchDescriptor<DragonTigerData>(predicate: #Predicate { $0.date == date })
        return (try? context.fetch(descriptor)) ?? []
    }

    func save(dragonTiger: [DragonTigerData]) {
        for item in dragonTiger { context.insert(item) }
        try? context.save()
    }

    func f10(symbol: String) -> F10Metric? {
        let descriptor = FetchDescriptor<F10Metric>(predicate: #Predicate { $0.symbol == symbol })
        return try? context.fetch(descriptor).first
    }

    func save(f10: F10Metric) {
        context.insert(f10)
        try? context.save()
    }
}
