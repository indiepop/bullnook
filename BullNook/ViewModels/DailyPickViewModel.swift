import Foundation
import SwiftData

@Observable
@MainActor
final class DailyPickViewModel {
    private let context: ModelContext
    private let cache: StockCache
    private let pickEngine = PickEngine()
    private let llmAnalyzer = LLMAnalyzer()

    var picks: [DailyPick] = []
    var isLoading = false
    var isRefreshingSectorSummary = false
    var errorMessage: String?
    var showAPIKeyAlert = false
    var sectorSummary: String = ""
    var lastRefreshedAt: Date?

    var currentPickDate: String {
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        return picks.first?.date ?? today
    }

    var hasRefreshedToday: Bool {
        // 只有真正存在今日推荐数据时，才显示“已刷新”
        guard !picks.isEmpty else { return false }
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        guard picks.contains(where: { $0.date == today }) else { return false }

        if let last = lastRefreshedAt, Calendar.current.isDateInToday(last) {
            return true
        }
        return picks.contains { Calendar.current.isDateInToday($0.generatedAt) }
    }

    var hasSectorData: Bool {
        let effectiveDate = effectiveTradingDate(for: Date())
        return !cache.sectors(for: effectiveDate).isEmpty
    }

    init(context: ModelContext) {
        self.context = context
        self.cache = StockCache(context: context)
        loadCachedPicks()
    }

    func loadCachedPicks() {
        let effectiveDate = effectiveTradingDate(for: Date())

        // 优先加载有效交易日（今日或最近交易日）已生成的推荐，固定展示
        if loadPicksIfAvailable(for: effectiveDate) {
            return
        }

        // 有效交易日无数据时自动后台生成
        Task {
            await refreshPicks()
        }
    }

    @discardableResult
    private func loadPicksIfAvailable(for date: String) -> Bool {
        let cached = cache.dailyPicks(for: date)
        guard !cached.isEmpty else { return false }

        picks = cached
        if let latest = cached.map({ $0.generatedAt }).max() {
            lastRefreshedAt = latest
        }

        let sectors = cache.sectors(for: date)
        sectorSummary = generateSectorSummary(sectors: sectors, date: date)

        Task {
            await loadRealTimeQuotes()
        }
        return true
    }

    func refreshPicks() async {
        guard !isLoading else { return }

        let effectiveDate = effectiveTradingDate(for: Date())

        // 有效交易日推荐已存在时只刷新实时行情，不再重新生成
        if !cache.dailyPicks(for: effectiveDate).isEmpty {
            loadPicksIfAvailable(for: effectiveDate)
            await loadRealTimeQuotes()
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // 1. 拉取板块、龙虎榜、候选股 K 线/新闻
        let sectors = await EastMoneyAPI.sectorList()
        let dragonTigers = await EastMoneyAPI.dragonTiger()
        print("[DailyPick] sectors: \(sectors.count), dragonTigers: \(dragonTigers.count)")

        let candidateStocks = await loadCandidateStocks()

        var klines: [String: [KLineData]] = [:]
        var news: [String: [StockNews]] = [:]
        for stock in candidateStocks {
            async let kline = EastMoneyAPI.kline(symbol: stock.symbol, period: .daily, start: "20240101", end: effectiveDate)
            async let stockNews = EastMoneyAPI.stockNews(symbol: stock.symbol)
            let (k, n) = await (kline, stockNews)
            klines[stock.symbol] = k
            news[stock.symbol] = n
            print("[DailyPick] \(stock.symbol) kline: \(k.count), news: \(n.count)")
        }

        // 2. 本地评分生成 Top5
        let inputs = PickInputs(stocks: candidateStocks, klines: klines, sectors: sectors, dragonTigers: dragonTigers, news: news)
        var generated = await pickEngine.generatePicks(inputs: inputs, date: effectiveDate)

        guard !generated.isEmpty else {
            errorMessage = "未能生成今日推荐，请检查网络后下拉重试。"
            print("[DailyPick] generatePicks returned empty for \(effectiveDate)")
            return
        }

        // 3. 获取实时行情并立即展示（无需等 LLM）
        let quotes = await SinaAPI.realTimeQuotes(symbols: generated.map { codeToSymbol($0.stockCode) })
        var quoteMap = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })
        if quoteMap.isEmpty {
            print("[Quote] Sina returned empty during refresh, falling back to EastMoney")
            let fallbackQuotes = await EastMoneyAPI.realTimeQuotes(symbols: generated.map { codeToSymbol($0.stockCode) })
            quoteMap = Dictionary(uniqueKeysWithValues: fallbackQuotes.map { ($0.symbol, $0) })
        }
        for index in generated.indices {
            let symbol = codeToSymbol(generated[index].stockCode)
            if let quote = quoteMap[symbol] {
                generated[index].currentPrice = quote.currentPrice
                generated[index].changePercent = quote.changePercent
            }
        }

        let sectorSummary = generateSectorSummary(sectors: sectors, date: effectiveDate)

        // 4. 先保存并展示，让用户立即看到今日推荐
        cache.deleteAllDailyPicks(for: effectiveDate)
        cache.save(dailyPicks: generated)
        cache.save(sectors: sectors)

        let historical = generated.map { HistoricalPick(from: $0, performanceSincePick: 0, pickPrice: $0.currentPrice, currentPrice: $0.currentPrice) }
        cache.deleteAllHistoricalPicks(for: effectiveDate)
        cache.save(historicalPicks: historical)

        self.sectorSummary = sectorSummary
        lastRefreshedAt = Date()
        picks = generated
        print("[DailyPick] picks displayed immediately, starting LLM enrichment")

        // 5. 后台异步填充 F10 + LLM 分析，不阻塞主流程
        Task {
            await enrichPicksWithLLM(
                generated: generated,
                quoteMap: quoteMap,
                klines: klines,
                news: news,
                sectorSummary: sectorSummary,
                date: effectiveDate
            )
        }
    }

    func refreshSectorSummary() async {
        guard !isRefreshingSectorSummary else { return }

        isRefreshingSectorSummary = true
        errorMessage = nil
        defer { isRefreshingSectorSummary = false }

        let effectiveDate = effectiveTradingDate(for: Date())
        let sectors = await EastMoneyAPI.sectorList()

        guard !sectors.isEmpty else {
            errorMessage = "板块数据获取失败，请检查网络后重试。"
            print("[DailyPick] sectorList returned empty for \(effectiveDate)")
            return
        }

        cache.save(sectors: sectors)
        sectorSummary = generateSectorSummary(sectors: sectors, date: effectiveDate)
        lastRefreshedAt = Date()
        print("[DailyPick] sector summary refreshed for \(effectiveDate)")
    }

    private func enrichPicksWithLLM(
        generated: [DailyPick],
        quoteMap: [String: RealTimeQuote],
        klines: [String: [KLineData]],
        news: [String: [StockNews]],
        sectorSummary: String,
        date: String
    ) async {
        // Fetch F10 for generated picks to enrich LLM analysis
        var f10Map: [String: F10Metric] = [:]
        for pick in generated {
            let symbol = codeToSymbol(pick.stockCode)
            if let cached = cache.f10(symbol: symbol) {
                f10Map[symbol] = cached
            } else if let fetched = await EastMoneyAPI.f10(symbol: symbol) {
                cache.save(f10: fetched)
                f10Map[symbol] = fetched
            }
        }

        let config = KeychainManager.load()
        let enriched = await withTaskGroup(of: DailyPick.self) { group in
            for pick in generated {
                group.addTask {
                    let mutable = pick
                    let symbol = codeToSymbol(pick.stockCode)
                    let context = LLMAnalysisContext(
                        pick: pick,
                        allPicks: generated,
                        quote: quoteMap[symbol],
                        f10: f10Map[symbol],
                        kline: klines[symbol] ?? [],
                        news: news[symbol] ?? [],
                        sectorSummary: sectorSummary
                    )
                    let analysis = await self.llmAnalyzer.analyze(context: context, config: config)
                    mutable.analysis = analysis
                    return mutable
                }
            }
            var results: [DailyPick] = []
            for await pick in group {
                results.append(pick)
            }
            return results.sorted { $0.rank < $1.rank }
        }

        // 只更新分析文本，不再整体替换，避免 UI 跳动
        var updated = false
        for enrichedPick in enriched {
            if let index = picks.firstIndex(where: { $0.id == enrichedPick.id }) {
                picks[index].analysis = enrichedPick.analysis
                updated = true
            }
        }
        if updated {
            cache.deleteAllDailyPicks(for: date)
            cache.save(dailyPicks: picks)
        }
        print("[DailyPick] LLM enrichment completed, updated: \(updated)")
    }

    func loadRealTimeQuotes() async {
        guard !picks.isEmpty else { return }
        let symbols = picks.map { codeToSymbol($0.stockCode) }
        var quotes = await SinaAPI.realTimeQuotes(symbols: symbols)
        if quotes.isEmpty {
            print("[Quote] Sina returned empty, falling back to EastMoney")
            quotes = await EastMoneyAPI.realTimeQuotes(symbols: symbols)
        }
        let quoteMap = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })

        let updatedPicks = picks
        for index in updatedPicks.indices {
            let symbol = codeToSymbol(updatedPicks[index].stockCode)
            if let quote = quoteMap[symbol] {
                updatedPicks[index].currentPrice = quote.currentPrice
                updatedPicks[index].changePercent = quote.changePercent
            }
        }
        picks = updatedPicks
    }

    private func generateSectorSummary(sectors: [SectorData], date: String) -> String {
        guard !sectors.isEmpty else {
            return "板块数据暂不可用，下拉刷新后可获取最新板块风向。"
        }

        let sorted = sectors.sorted { $0.changePercent > $1.changePercent }
        let topRisers = Array(sorted.prefix(3))
        let topFallers = Array(sorted.suffix(3).reversed())

        let avgChange = sectors.reduce(0) { $0 + $1.changePercent } / Double(sectors.count)
        let upCount = sectors.filter { $0.changePercent > 0 }.count
        let downCount = sectors.filter { $0.changePercent < 0 }.count

        var parts: [String] = []
        parts.append("沪深两市共 \(sectors.count) 个板块，上涨 \(upCount) 个、下跌 \(downCount) 个，平均涨跌 \(String(format: "%.2f", avgChange))%。")

        let riserNames = topRisers.map { "\($0.name)(\(String(format: "+%.2f", $0.changePercent))%)" }.joined(separator: "、")
        parts.append("涨幅前三：\(riserNames)。")

        let fallerNames = topFallers.map { "\($0.name)(\(String(format: "%.2f", $0.changePercent))%)" }.joined(separator: "、")
        parts.append("跌幅前三：\(fallerNames)。")

        return parts.joined(separator: "")
    }

    private func loadCandidateStocks() async -> [Stock] {
        return [
            Stock(id: "600519", symbol: "sh600519", name: "贵州茅台", industry: "白酒", marketCap: 2_000_000_000_000),
            Stock(id: "000001", symbol: "sz000001", name: "平安银行", industry: "银行", marketCap: 200_000_000_000),
            Stock(id: "000333", symbol: "sz000333", name: "美的集团", industry: "家电", marketCap: 400_000_000_000),
            Stock(id: "002594", symbol: "sz002594", name: "比亚迪", industry: "汽车", marketCap: 700_000_000_000),
            Stock(id: "300750", symbol: "sz300750", name: "宁德时代", industry: "电池", marketCap: 800_000_000_000),
            Stock(id: "601318", symbol: "sh601318", name: "中国平安", industry: "保险", marketCap: 900_000_000_000),
            Stock(id: "600036", symbol: "sh600036", name: "招商银行", industry: "银行", marketCap: 800_000_000_000),
            Stock(id: "000858", symbol: "sz000858", name: "五粮液", industry: "白酒", marketCap: 600_000_000_000),
            Stock(id: "002475", symbol: "sz002475", name: "立讯精密", industry: "电子", marketCap: 250_000_000_000),
            Stock(id: "600276", symbol: "sh600276", name: "恒瑞医药", industry: "医药", marketCap: 300_000_000_000)
        ]
    }
    private func effectiveTradingDate(for date: Date) -> String {
        if isTradingDay(date) {
            return DateFormatter.yyyyMMdd.string(from: date)
        }
        return previousTradingDay(before: date) ?? DateFormatter.yyyyMMdd.string(from: date)
    }

    private func isTradingDay(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        // 1 = 周日，7 = 周六；A股周末休市
        return weekday != 1 && weekday != 7
    }

    private func previousTradingDay(before date: Date) -> String? {
        var candidate = date
        let calendar = Calendar.current
        for _ in 0..<30 {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: candidate) else { return nil }
            candidate = previous
            if isTradingDay(candidate) {
                return DateFormatter.yyyyMMdd.string(from: candidate)
            }
        }
        return nil
    }
}

private func codeToSymbol(_ code: String) -> String {
    if code.hasPrefix("6") { return "sh\(code)" }
    if code.hasPrefix("0") || code.hasPrefix("3") { return "sz\(code)" }
    return code
}
