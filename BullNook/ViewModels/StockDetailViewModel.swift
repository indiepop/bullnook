import Foundation
import SwiftData

@Observable
@MainActor
final class StockDetailViewModel {
    private let cache: StockCache
    private let llmAnalyzer = LLMAnalyzer()
    let pick: DailyPick

    var kline: [KLineData] = []
    var selectedPeriod: KLinePeriod = .daily
    var f10: F10Metric?
    var isInWatchlist = false
    var isLoading = false
    var isLLMConfigured = false
    var isAnalysisLoading = false

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
        isLLMConfigured = KeychainManager.load()?.apiKey.isEmpty == false
        print("[Watchlist] StockDetail loadData, isInWatchlist=\(isInWatchlist), isLLMConfigured=\(isLLMConfigured)")

        // 如果已配置 LLM 但分析仍是占位/失败摘要，自动补做一次 LLM 分析
        await enrichAnalysisIfNeeded(symbol: symbol)
    }

    private func enrichAnalysisIfNeeded(symbol: String) async {
        guard let config = KeychainManager.load(), !config.apiKey.isEmpty else {
            print("[LLM] StockDetail skip enrichment, no config")
            return
        }
        guard pick.analysis.isEmpty || pick.analysis.contains("规则摘要") else {
            print("[LLM] StockDetail analysis already enriched")
            return
        }

        isAnalysisLoading = true
        defer { isAnalysisLoading = false }

        print("[LLM] StockDetail enriching analysis for \(pick.stockCode)")
        let quotes = await SinaAPI.realTimeQuotes(symbols: [symbol])
        let quote = quotes.first
        let news = await EastMoneyAPI.stockNews(symbol: symbol)

        let today = DateFormatter.yyyyMMdd.string(from: Date())
        let sectors = cache.sectors(for: today)
        let sectorSummary = sectors.isEmpty
            ? "板块数据暂不可用。"
            : generateSectorSummary(sectors: sectors)

        let context = LLMAnalysisContext(
            pick: pick,
            allPicks: [pick],
            quote: quote,
            f10: f10,
            kline: kline,
            news: news,
            sectorSummary: sectorSummary
        )

        let analysis = await llmAnalyzer.analyze(context: context, config: config)
        pick.analysis = analysis
        cache.save(dailyPicks: [pick])
        print("[LLM] StockDetail enriched analysis for \(pick.stockCode): \(analysis.prefix(50))...")
    }

    private func generateSectorSummary(sectors: [SectorData]) -> String {
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
