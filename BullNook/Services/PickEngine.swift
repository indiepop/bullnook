import Foundation

struct PickInputs {
    let stocks: [Stock]
    let klines: [String: [KLineData]]
    let sectors: [SectorData]
    let dragonTigers: [DragonTigerData]
    let news: [String: [StockNews]]
}

actor PickEngine {

    func generatePicks(inputs: PickInputs, date: String) async -> [DailyPick] {
        var candidates: [DailyPick] = []
        let sectorMap = Dictionary(grouping: inputs.sectors, by: { $0.name })
        let dragonMap = Dictionary(grouping: inputs.dragonTigers, by: { $0.symbol })

        for stock in inputs.stocks {
            guard isEligible(stock: stock, klines: inputs.klines[stock.symbol]) else { continue }

            let symbol = stock.symbol
            let kline = inputs.klines[symbol] ?? []
            let stockNews = inputs.news[symbol] ?? []
            let stockDragon = dragonMap[symbol] ?? []

            let sectorScore = scoreSector(stock: stock, sectors: inputs.sectors, sectorMap: sectorMap)
            let lhbScore = scoreDragonTiger(stock: stock, dragonTigers: stockDragon)
            let trendScore = scoreTrend(kline: kline)
            let newsScore = scoreNews(news: stockNews)

            let total = (sectorScore + lhbScore + trendScore + newsScore) / 4.0
            let reason = reasonSummary(sector: sectorScore, lhb: lhbScore, trend: trendScore, news: newsScore)

            let pick = DailyPick(
                id: "\(date)_\(stock.id)",
                date: date,
                rank: 0,
                stockCode: stock.id,
                stockName: stock.name,
                industry: stock.industry,
                score: total,
                reasonSummary: reason,
                sectorScore: sectorScore,
                lhbScore: lhbScore,
                trendScore: trendScore,
                newsScore: newsScore,
                analysis: ""
            )
            candidates.append(pick)
        }

        let sorted = candidates.sorted { $0.score > $1.score }
        let top5 = Array(sorted.prefix(5)).enumerated().map { index, pick in
            DailyPick(
                id: pick.id,
                date: pick.date,
                rank: index + 1,
                stockCode: pick.stockCode,
                stockName: pick.stockName,
                industry: pick.industry,
                score: pick.score,
                reasonSummary: pick.reasonSummary,
                sectorScore: pick.sectorScore,
                lhbScore: pick.lhbScore,
                trendScore: pick.trendScore,
                newsScore: pick.newsScore,
                analysis: pick.analysis
            )
        }
        return top5
    }

    // MARK: - Filtering

    private func isEligible(stock: Stock, klines: [KLineData]?) -> Bool {
        let name = stock.name
        if name.contains("退") || name.contains("ST") || name.contains("*ST") {
            return false
        }
        let code = stock.id
        if code.hasPrefix("688") { return false }
        if code.hasPrefix("8") || code.hasPrefix("4") { return false }
        guard let klines = klines, !klines.isEmpty else {
            return false // treat missing kline as suspended
        }
        let latest = klines.sorted { $0.date < $1.date }
        guard let last = latest.last, last.close > 0 else { return false }
        return true
    }

    // MARK: - Scoring

    private func scoreSector(stock: Stock, sectors: [SectorData], sectorMap: [String: [SectorData]]) -> Double {
        guard !sectors.isEmpty else { return 50 }
        let maxChange = sectors.map { abs($0.changePercent) }.max() ?? 1
        let matched = sectors.first { stock.industry.contains($0.name) || $0.name.contains(stock.industry) }
        let change = matched?.changePercent ?? 0
        let normalized = maxChange > 0 ? (change / maxChange) * 100 : 50
        return min(max(normalized, 0), 100)
    }

    private func scoreDragonTiger(stock: Stock, dragonTigers: [DragonTigerData]) -> Double {
        guard !dragonTigers.isEmpty else { return 50 }
        let netBuy = dragonTigers.reduce(0) { $0 + $1.netBuyAmount }
        let score = 50 + min(netBuy / 1_000_000.0, 50)
        return min(score, 100)
    }

    private func scoreTrend(kline: [KLineData]) -> Double {
        guard kline.count >= 5 else { return 50 }
        let sorted = kline.sorted { $0.date < $1.date }
        guard let last = sorted.last, let fiveDaysAgo = sorted.dropLast(5).last else { return 50 }
        let change = fiveDaysAgo.close > 0 ? (last.close - fiveDaysAgo.close) / fiveDaysAgo.close * 100 : 0
        let ma5 = sorted.suffix(5).map(\.close).reduce(0, +) / 5
        let ma10 = sorted.suffix(min(10, sorted.count)).map(\.close).reduce(0, +) / Double(min(10, sorted.count))
        var score = 50 + change * 2
        if last.close > ma5 { score += 10 }
        if last.close > ma10 { score += 10 }
        return min(max(score, 0), 100)
    }

    private func scoreNews(news: [StockNews]) -> Double {
        let count = Double(news.count)
        return min(50 + count * 5, 100)
    }

    private func reasonSummary(sector: Double, lhb: Double, trend: Double, news: Double) -> String {
        let scores = [
            ("板块热度", sector),
            ("龙虎榜资金", lhb),
            ("个股走势", trend),
            ("消息链", news)
        ]
        let top = scores.max { $0.1 < $1.1 } ?? scores[0]
        return "\(top.0)表现突出，综合评分较高"
    }
}
