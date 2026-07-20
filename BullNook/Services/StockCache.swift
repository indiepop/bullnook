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
        let items = (try? context.fetch(descriptor)) ?? []
        print("[DailyPick] fetched \(items.count) picks for \(date)")
        return items
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
        do {
            try context.save()
            print("[DailyPick] saved \(dailyPicks.count) records")
        } catch {
            print("[DailyPick] save failed: \(error)")
        }
    }

    func deleteAllDailyPicks(for date: String) {
        let descriptor = FetchDescriptor<DailyPick>(predicate: #Predicate { $0.date == date })
        guard let items = try? context.fetch(descriptor) else { return }
        for item in items {
            context.delete(item)
        }
        do {
            try context.save()
            print("[DailyPick] deleted \(items.count) records for \(date)")
        } catch {
            print("[DailyPick] delete failed: \(error)")
        }
    }

    // MARK: - Historical Picks

    func historicalPicks() -> [HistoricalPick] {
        let descriptor = FetchDescriptor<HistoricalPick>(
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.rank)]
        )
        let items = (try? context.fetch(descriptor)) ?? []
        print("[HistoricalPick] fetched \(items.count) records")
        return items
    }

    func save(historicalPicks: [HistoricalPick]) {
        for pick in historicalPicks {
            context.insert(pick)
        }
        do {
            try context.save()
            print("[HistoricalPick] saved \(historicalPicks.count) records")
        } catch {
            print("[HistoricalPick] save failed: \(error)")
        }
    }

    func deleteAllHistoricalPicks(for date: String) {
        let descriptor = FetchDescriptor<HistoricalPick>(predicate: #Predicate { $0.date == date })
        guard let items = try? context.fetch(descriptor) else { return }
        for item in items {
            context.delete(item)
        }
        try? context.save()
    }

    // MARK: - KLine

    func kline(symbol: String, period: KLinePeriod) -> [KLineData] {
        let key = klineKey(symbol: symbol, period: period)
        let descriptor = FetchDescriptor<KLineData>(
            predicate: #Predicate { $0.symbol == key },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func save(kline: [KLineData], symbol: String, period: KLinePeriod) {
        let key = klineKey(symbol: symbol, period: period)

        // 清理旧版缓存（未区分周期的 raw symbol）以及同一 symbol+period 的旧数据
        let legacyDescriptor = FetchDescriptor<KLineData>(predicate: #Predicate { $0.symbol == symbol })
        if let legacy = try? context.fetch(legacyDescriptor) {
            for item in legacy {
                context.delete(item)
            }
        }

        let descriptor = FetchDescriptor<KLineData>(predicate: #Predicate { $0.symbol == key })
        if let stale = try? context.fetch(descriptor) {
            for item in stale {
                context.delete(item)
            }
        }

        for var item in kline {
            item.symbol = key
            context.insert(item)
        }
        try? context.save()
    }

    private func klineKey(symbol: String, period: KLinePeriod) -> String {
        "\(symbol)-\(period.rawValue)"
    }

    // MARK: - Watchlist

    func watchlistItems() -> [WatchlistItem] {
        let descriptor = FetchDescriptor<WatchlistItem>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        let items = (try? context.fetch(descriptor)) ?? []
        print("[Watchlist] fetch items: \(items.count), context=\(ObjectIdentifier(context))")
        return items
    }

    func addToWatchlist(stockCode: String, stockName: String, industry: String = "") {
        print("[Watchlist] add request \(stockCode), context=\(ObjectIdentifier(context))")
        guard !isInWatchlist(stockCode: stockCode) else {
            print("[Watchlist] \(stockCode) already in watchlist, skip")
            return
        }

        let item = WatchlistItem(id: stockCode, stockCode: stockCode, stockName: stockName, industry: industry)
        context.insert(item)
        do {
            try context.save()
            print("[Watchlist] added \(stockCode) \(stockName) ok")
        } catch {
            print("[Watchlist] add failed: \(error)")
        }
    }

    func removeFromWatchlist(stockCode: String) {
        print("[Watchlist] remove request \(stockCode), context=\(ObjectIdentifier(context))")
        let descriptor = FetchDescriptor<WatchlistItem>(predicate: #Predicate { $0.stockCode == stockCode })
        do {
            let items = try context.fetch(descriptor)
            guard !items.isEmpty else {
                print("[Watchlist] remove skipped, \(stockCode) not found")
                return
            }
            for item in items {
                context.delete(item)
            }
            try context.save()
            print("[Watchlist] removed \(stockCode) ok")
        } catch {
            print("[Watchlist] remove failed: \(error)")
        }
    }

    func isInWatchlist(stockCode: String) -> Bool {
        let descriptor = FetchDescriptor<WatchlistItem>(predicate: #Predicate { $0.stockCode == stockCode })
        let count = (try? context.fetchCount(descriptor)) ?? 0
        print("[Watchlist] isInWatchlist \(stockCode): \(count > 0) (count=\(count))")
        return count > 0
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
        if let date = sectors.first?.date {
            deleteAllSectors(for: date)
        }
        for item in sectors { context.insert(item) }
        try? context.save()
    }

    func deleteAllSectors(for date: String) {
        let descriptor = FetchDescriptor<SectorData>(predicate: #Predicate { $0.date == date })
        guard let items = try? context.fetch(descriptor) else { return }
        for item in items {
            context.delete(item)
        }
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
        let symbol = f10.symbol
        let descriptor = FetchDescriptor<F10Metric>(predicate: #Predicate { $0.symbol == symbol })
        if let existing = try? context.fetch(descriptor) {
            for item in existing {
                context.delete(item)
            }
        }
        context.insert(f10)
        try? context.save()
    }
}
