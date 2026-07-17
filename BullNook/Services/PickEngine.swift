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
            guard isEligible(stock: stock, klines: inputs.klines[stock.symbol]) else {
                print("[PickEngine] \(stock.symbol) filtered out: kline missing/empty or not eligible")
                continue
            }

            let symbol = stock.symbol
            let kline = inputs.klines[symbol] ?? []
            let stockNews = inputs.news[symbol] ?? []
            let stockDragon = dragonMap[symbol] ?? []

            let sectorResult = scoreSectorWithDetails(stock: stock, sectors: inputs.sectors, sectorMap: sectorMap)
            let lhbScore = scoreDragonTiger(stock: stock, dragonTigers: stockDragon)
            let trendScore = scoreTrend(kline: kline)
            let newsScore = scoreNews(news: stockNews)

            let total = (sectorResult.score + lhbScore + trendScore + newsScore) / 4.0
            let reason = reasonSummary(
                stock: stock,
                sectorScore: sectorResult.score,
                lhbScore: lhbScore,
                trendScore: trendScore,
                newsScore: newsScore,
                matchedSector: sectorResult.sector,
                kline: kline,
                newsCount: stockNews.count,
                dragonTigers: stockDragon
            )

            let pick = DailyPick(
                id: "\(date)_\(stock.id)",
                date: date,
                rank: 0,
                stockCode: stock.id,
                stockName: stock.name,
                industry: stock.industry,
                score: total,
                reasonSummary: reason,
                sectorScore: sectorResult.score,
                lhbScore: lhbScore,
                trendScore: trendScore,
                newsScore: newsScore,
                analysis: ""
            )
            candidates.append(pick)
        }

        print("[PickEngine] candidates after filter: \(candidates.count)/\(inputs.stocks.count)")
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
        print("[PickEngine] generated top5: \(top5.count)")
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
            // K 线缺失时不再直接剔除，保留候选并用默认走势分兜底，避免某一路数据源异常导致全天无推荐
            print("[PickEngine] \(stock.symbol) kline missing, keeping with default trend score")
            return true
        }
        let latest = klines.sorted { $0.date < $1.date }
        guard let last = latest.last, last.close > 0 else { return false }
        return true
    }

    // MARK: - Scoring

    private func scoreSectorWithDetails(stock: Stock, sectors: [SectorData], sectorMap: [String: [SectorData]]) -> (score: Double, sector: SectorData?) {
        guard !sectors.isEmpty else { return (50, nil) }
        let maxChange = sectors.map { abs($0.changePercent) }.max() ?? 1
        let matched = sectors.first { stock.industry.contains($0.name) || $0.name.contains(stock.industry) }
        let change = matched?.changePercent ?? 0
        let normalized = maxChange > 0 ? (change / maxChange) * 100 : 50
        let score = min(max(normalized, 0), 100)
        return (score, matched)
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

    private func reasonSummary(
        stock: Stock,
        sectorScore: Double,
        lhbScore: Double,
        trendScore: Double,
        newsScore: Double,
        matchedSector: SectorData?,
        kline: [KLineData],
        newsCount: Int,
        dragonTigers: [DragonTigerData]
    ) -> String {
        var highlights: [String] = []

        // 板块维度：只有真正明显占优才写入理由
        if sectorScore >= 70, let sector = matchedSector {
            let sign = sector.changePercent >= 0 ? "+" : ""
            let changeStr = String(format: "%.2f", sector.changePercent)
            highlights.append("\(stock.industry)板块热度居前（\(sign)\(changeStr)%）")
        }

        // 走势维度
        if trendScore >= 70 {
            let sorted = kline.sorted { $0.date < $1.date }
            if let last = sorted.last, sorted.count >= 5 {
                let ma5 = sorted.suffix(5).map(\.close).reduce(0, +) / 5
                if last.close > ma5 {
                    highlights.append("股价站稳MA5，短期趋势向上")
                } else {
                    highlights.append("近期走势相对强势")
                }
            } else {
                highlights.append("近期走势相对强势")
            }
        }

        // 消息维度
        if newsScore >= 70, newsCount > 0 {
            highlights.append("消息链活跃，共有 \(newsCount) 条相关资讯")
        }

        // 龙虎榜维度
        if lhbScore >= 70, !dragonTigers.isEmpty {
            let netBuy = dragonTigers.reduce(0) { $0 + $1.netBuyAmount }
            let netBuyStr = formatAmount(netBuy)
            highlights.append("龙虎榜资金净流入 \(netBuyStr)，主力关注度高")
        }

        // 如果没有任何维度特别突出，取最高分维度做差异化描述
        if highlights.isEmpty {
            let scores = [
                ("板块热度", sectorScore, "板块"),
                ("龙虎榜资金", lhbScore, "资金"),
                ("个股走势", trendScore, "走势"),
                ("消息链", newsScore, "消息")
            ]
            let top = scores.max { $0.1 < $1.1 } ?? scores[0]

            switch top.2 {
            case "板块":
                if let sector = matchedSector {
                    let sign = sector.changePercent >= 0 ? "+" : ""
                    let changeStr = String(format: "%.2f", sector.changePercent)
                    highlights.append("\(stock.industry)板块相对占优（\(sign)\(changeStr)%）")
                } else {
                    highlights.append("\(stock.industry)板块维度评分相对占优")
                }
            case "走势":
                highlights.append("技术面走势维度评分相对占优")
            case "消息":
                highlights.append("消息链维度有一定活跃度")
            case "资金":
                highlights.append("龙虎榜资金维度评分相对占优")
            default:
                highlights.append("\(top.0)维度评分相对占优")
            }
        }

        // 取最突出的 1-2 个维度组合，避免千篇一律
        let selected = Array(highlights.prefix(2))
        return selected.joined(separator: "；") + "。"
    }

    private func formatAmount(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 1_0000_0000 {
            return String(format: "%.2f亿", absValue / 1_0000_0000)
        } else if absValue >= 10000 {
            return String(format: "%.2f万", absValue / 10000)
        }
        return String(format: "%.0f", absValue)
    }
}
