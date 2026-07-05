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
    var errorMessage: String?
    var showAPIKeyAlert = false

    init(context: ModelContext) {
        self.context = context
        self.cache = StockCache(context: context)
        loadCachedPicks()
    }

    func loadCachedPicks() {
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        let cached = cache.dailyPicks(for: today)
        if !cached.isEmpty {
            picks = cached
        } else {
            picks = cache.latestDailyPicks(limit: 5)
        }
    }

    func refreshPicks() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let today = DateFormatter.yyyyMMdd.string(from: Date())

        // Fetch sector and dragon tiger data for today
        let sectors = await EastMoneyAPI.sectorList()
        let dragonTigers = await EastMoneyAPI.dragonTiger()

        // Build a small candidate pool for MVP
        let candidateStocks = await loadCandidateStocks()

        // Fetch klines and news for candidates
        var klines: [String: [KLineData]] = [:]
        var news: [String: [StockNews]] = [:]
        for stock in candidateStocks {
            async let kline = EastMoneyAPI.kline(symbol: stock.symbol, period: .daily, start: "20240101", end: today)
            async let stockNews = EastMoneyAPI.stockNews(symbol: stock.symbol)
            let (k, n) = await (kline, stockNews)
            klines[stock.symbol] = k
            news[stock.symbol] = n
        }

        let inputs = PickInputs(stocks: candidateStocks, klines: klines, sectors: sectors, dragonTigers: dragonTigers, news: news)
        var generated = await pickEngine.generatePicks(inputs: inputs, date: today)

        // Fetch real-time quotes for generated picks
        let quotes = await SinaAPI.realTimeQuotes(symbols: generated.map { codeToSymbol($0.stockCode) })
        let quoteMap = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })

        // Enrich with LLM analysis
        let config = KeychainManager.load()
        generated = await withTaskGroup(of: DailyPick.self) { group in
            for pick in generated {
                group.addTask {
                    var mutable = pick
                    let analysis = await self.llmAnalyzer.analyze(pick: pick, allPicks: generated, config: config)
                    mutable.analysis = analysis
                    if let quote = quoteMap[codeToSymbol(pick.stockCode)] {
                        mutable.currentPrice = quote.currentPrice
                        mutable.changePercent = quote.changePercent
                    }
                    return mutable
                }
            }
            var results: [DailyPick] = []
            for await pick in group {
                results.append(pick)
            }
            return results.sorted { $0.rank < $1.rank }
        }

        // Save
        cache.deleteAllDailyPicks(for: today)
        cache.save(dailyPicks: generated)

        let historical = generated.map { HistoricalPick(from: $0, performanceSincePick: $0.changePercent) }
        cache.save(historicalPicks: historical)

        picks = generated
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
}

private func codeToSymbol(_ code: String) -> String {
    if code.hasPrefix("6") { return "sh\(code)" }
    if code.hasPrefix("0") || code.hasPrefix("3") { return "sz\(code)" }
    return code
}
