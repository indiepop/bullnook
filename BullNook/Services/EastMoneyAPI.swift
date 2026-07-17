import Foundation

struct StockNews {
    let title: String
    let url: String
    let publishTime: String
}

struct EastMoneyAPI {

    // MARK: - Helpers

    private static func secid(for symbol: String) -> String {
        if symbol.hasPrefix("sh") { return "1.\(String(symbol.dropFirst(2)))" }
        if symbol.hasPrefix("sz") { return "0.\(String(symbol.dropFirst(2)))" }
        return "1.\(symbol)"
    }

    private static func klt(for period: KLinePeriod) -> String {
        switch period {
        case .daily: return "101"
        case .weekly: return "102"
        case .monthly: return "103"
        }
    }

    // MARK: - Real-time Quotes (fallback)

    static func realTimeQuotes(symbols: [String]) async -> [RealTimeQuote] {
        var quotes: [RealTimeQuote] = []
        for symbol in symbols {
            if let quote = await realTimeQuote(symbol: symbol) {
                quotes.append(quote)
            }
        }
        return quotes
    }

    private static func realTimeQuote(symbol: String) async -> RealTimeQuote? {
        let sec = secid(for: symbol)
        let urlString = "https://push2.eastmoney.com/api/qt/stock/get?ut=fa5fd1943c7b386f172d6893dbfba10b&fltt=2&invt=2&volt=2&fields=f43,f57,f58,f169,f170,f44,f45,f46,f47,f48,f60,f61,f116,f117&secid=\(sec)"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let headers = ["User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
                           "Referer": "https://quote.eastmoney.com/"]
            let raw = try await NetworkClient.shared.fetchString(url, headers: headers)
            guard let data = raw.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["data"] as? [String: Any] else { return nil }

            let name = stringValue(result["f58"])
            // 行情字段通常以“分”为单位，fltt=2 时除以 100 得到元
            let currentPrice = parseDouble(result["f43"]) / 100
            let previousClose = parseDouble(result["f169"]) / 100
            let open = parseDouble(result["f170"]) / 100
            let high = parseDouble(result["f44"]) / 100
            let low = parseDouble(result["f45"]) / 100
            let volume = parseDouble(result["f47"])
            let amount = parseDouble(result["f48"])

            return RealTimeQuote(
                symbol: symbol,
                name: name,
                currentPrice: currentPrice,
                previousClose: previousClose,
                open: open,
                high: high,
                low: low,
                volume: volume,
                amount: amount,
                dateTime: ""
            )
        } catch {
            print("EastMoney real-time quote fetch failed for \(symbol): \(error)")
            return nil
        }
    }

    // MARK: - KLine

    static func kline(symbol: String, period: KLinePeriod = .daily, start: String, end: String) async -> [KLineData] {
        let sec = secid(for: symbol)
        let klt = klt(for: period)
        let urlString = "https://push2his.eastmoney.com/api/qt/stock/kline/get?secid=\(sec)&fields1=f1,f2,f3,f4,f5,f6&fields2=f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61&klt=\(klt)&fqt=1&beg=\(start)&end=\(end)"
        guard let url = URL(string: urlString) else { return [] }

        do {
            let headers = ["User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
                           "Referer": "https://quote.eastmoney.com/"]
            let raw = try await NetworkClient.shared.fetchString(url, headers: headers)
            let parsed = parseKLine(raw: raw, symbol: symbol)
            if validate(kline: parsed, for: period) {
                print("[KLine] EastMoney \(symbol) \(period.rawValue) returned \(parsed.count) records")
                return parsed
            }
            print("[KLine] EastMoney \(symbol) returned mismatched period \(period.rawValue), falling back")
        } catch {
            print("[KLine] EastMoney \(symbol) fetch failed: \(error)")
        }

        // Fallback: 日线用新浪接口兜底；周线/月线用日线聚合兜底
        guard period != .daily else {
            print("[KLine] EastMoney daily empty for \(symbol), falling back to Sina")
            let sinaKline = await SinaAPI.kline(symbol: symbol, period: .daily, count: 250)
            print("[KLine] Sina \(symbol) daily returned \(sinaKline.count) records")
            return sinaKline
        }
        let daily = await kline(symbol: symbol, period: .daily, start: start, end: end)
        return aggregate(kline: daily, to: period)
    }

    private static func parseKLine(raw: String, symbol: String) -> [KLineData] {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["data"] as? [String: Any],
              let klines = result["klines"] as? [String] else { return [] }

        return klines.compactMap { line -> KLineData? in
            let parts = line.split(separator: ",").map(String.init)
            guard parts.count >= 9 else { return nil }
            return KLineData(
                symbol: symbol,
                date: parts[0],
                open: Double(parts[1]) ?? 0,
                high: Double(parts[3]) ?? 0,
                low: Double(parts[4]) ?? 0,
                close: Double(parts[2]) ?? 0,
                volume: Double(parts[5]) ?? 0,
                amount: Double(parts[6]) ?? 0,
                amplitude: Double(parts[7]) ?? 0,
                changePercent: Double(parts[8]) ?? 0,
                changeAmount: Double(parts[9]) ?? 0,
                turnover: Double(parts.count > 10 ? parts[10] : "0") ?? 0
            )
        }
    }

    // MARK: - KLine Validation / Aggregation

    /// 检查返回的数据间隔是否符合目标周期，避免接口错误地返回日线数据。
    private static func validate(kline: [KLineData], for period: KLinePeriod) -> Bool {
        guard kline.count >= 2 else { return true }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dates = kline.compactMap { formatter.date(from: $0.date) }
        guard dates.count == kline.count else { return false }

        let sorted = dates.sorted()
        let gaps = zip(sorted.dropFirst(), sorted).map { $0.timeIntervalSince($1) }
        let avgGap = gaps.reduce(0, +) / Double(gaps.count)
        let day: TimeInterval = 24 * 60 * 60

        switch period {
        case .daily:
            return avgGap <= 5 * day
        case .weekly:
            return avgGap >= 5 * day
        case .monthly:
            return avgGap >= 20 * day
        }
    }

    private static func aggregate(kline: [KLineData], to period: KLinePeriod) -> [KLineData] {
        guard !kline.isEmpty else { return [] }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: kline) { item -> String in
            guard let date = formatter.date(from: item.date) else { return item.date }
            switch period {
            case .weekly:
                guard let weekEnd = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))
                else { return item.date }
                return formatter.string(from: weekEnd)
            case .monthly:
                let components = calendar.dateComponents([.year, .month], from: date)
                guard let monthEnd = calendar.date(from: components) else { return item.date }
                return formatter.string(from: monthEnd)
            default:
                return item.date
            }
        }

        return grouped.values.compactMap { group -> KLineData? in
            guard let first = group.first else { return nil }
            let sorted = group.sorted { $0.date < $1.date }
            guard let last = sorted.last else { return nil }
            let high = sorted.map(\.high).max() ?? last.high
            let low = sorted.map(\.low).min() ?? last.low
            let volume = sorted.reduce(0) { $0 + $1.volume }
            let amount = sorted.reduce(0) { $0 + $1.amount }
            let changeAmount = last.close - first.open
            let changePercent = first.open > 0 ? changeAmount / first.open * 100 : 0
            return KLineData(
                symbol: last.symbol,
                date: last.date,
                open: first.open,
                high: high,
                low: low,
                close: last.close,
                volume: volume,
                amount: amount,
                changePercent: changePercent,
                changeAmount: changeAmount
            )
        }
        .sorted { $0.date < $1.date }
    }

    // MARK: - Dragon Tiger

    static func dragonTiger(pageSize: Int = 500) async -> [DragonTigerData] {
        let urlString = "https://datacenter-web.eastmoney.com/api/data/v1/get?sortColumns=SECURITY_CODE,TRADE_DATE&sortTypes=-1,-1&pageSize=\(pageSize)&pageNumber=1&reportName=RPT_DMSK_TS_LSTOCKT&columns=ALL&source=WEB&client=WEB"
        guard let url = URL(string: urlString) else { return [] }

        do {
            let raw = try await NetworkClient.shared.fetchString(url)
            return parseDragonTiger(raw: raw)
        } catch {
            print("EastMoney dragon tiger fetch failed: \(error)")
            return []
        }
    }

    private static func parseDragonTiger(raw: String) -> [DragonTigerData] {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let rows = result["data"] as? [[String: Any]] else { return [] }

        return rows.compactMap { row -> DragonTigerData? in
            guard let code = row["SECURITY_CODE"] as? String,
                  let name = row["SECURITY_NAME_ABBR"] as? String,
                  let date = row["TRADE_DATE"] as? String else { return nil }
            let netBuy = (row["NET_BUY_AMT"] as? Double) ?? 0
            let buySeats = (row["BUY_STOCK"] as? String) ?? ""
            let sellSeats = (row["SELL_STOCK"] as? String) ?? ""
            return DragonTigerData(
                id: "\(code)_\(date)",
                symbol: codeToSymbol(code),
                name: name,
                date: String(date.prefix(10)),
                netBuyAmount: netBuy,
                buySeats: buySeats,
                sellSeats: sellSeats
            )
        }
    }

    // MARK: - Sectors

    static func sectorList() async -> [SectorData] {
        var allSectors: [SectorData] = []
        var pageNumber = 1
        let pageSize = 500

        while true {
            let urlString = "https://push2.eastmoney.com/api/qt/clist/get?pn=\(pageNumber)&pz=\(pageSize)&po=1&np=1&fltt=2&invt=2&fid=f3&fs=m:90+t:2&fields=f12,f14,f2,f3,f4,f5,f6,f7,f8,f9,f10,f20,f21,f22"
            guard let url = URL(string: urlString) else { break }

            do {
                let raw = try await NetworkClient.shared.fetchString(url)
                let (sectors, total) = parseSectors(raw: raw)
                allSectors.append(contentsOf: sectors)
                if allSectors.count >= total || sectors.isEmpty {
                    break
                }
                pageNumber += 1
            } catch {
                print("EastMoney sector list fetch failed: \(error)")
                break
            }
        }

        return allSectors
    }

    private static func parseSectors(raw: String) -> (sectors: [SectorData], total: Int) {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["data"] as? [String: Any],
              let diff = result["diff"] as? [[String: Any]] else { return ([], 0) }

        let total = (result["total"] as? Int) ?? diff.count
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        let sectors = diff.compactMap { item -> SectorData? in
            guard let name = item["f14"] as? String else { return nil }
            let change = (item["f3"] as? Double) ?? 0
            let inflow = (item["f22"] as? Double) ?? 0
            return SectorData(
                id: "\(name)_\(today)",
                name: name,
                date: today,
                changePercent: change,
                netInflow: inflow,
                limitUpCount: 0
            )
        }
        return (sectors, total)
    }

    // MARK: - News

    static func stockNews(symbol: String, pageSize: Int = 20) async -> [StockNews] {
        let code = String(symbol.dropFirst(2))
        let urlString = "https://searchapi.eastmoney.com/api/sns/get?type=14&cb=jQuery&keyword=\(code)&pageindex=1&pagesize=\(pageSize)"
        guard let url = URL(string: urlString) else { return [] }

        do {
            let raw = try await NetworkClient.shared.fetchString(url)
            return parseNews(raw: raw)
        } catch {
            print("EastMoney news fetch failed: \(error)")
            return []
        }
    }

    private static func parseNews(raw: String) -> [StockNews] {
        guard let start = raw.range(of: "(")?.upperBound,
              let end = raw.range(of: ")")?.lowerBound else { return [] }
        let jsonString = String(raw[start..<end])
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let posts = result["posts"] as? [[String: Any]] else { return [] }

        return posts.compactMap { post -> StockNews? in
            guard let title = post["title"] as? String,
                  let url = post["url"] as? String,
                  let time = post["pub_time"] as? String else { return nil }
            return StockNews(title: title, url: url, publishTime: time)
        }
    }

    // MARK: - F10

    static func f10(symbol: String) async -> F10Metric? {
        let sec = secid(for: symbol)
        let code = String(symbol.dropFirst(2))

        let metric = F10Metric(symbol: symbol)
        metric.source = "eastmoney"

        // 1. 实时行情接口：PE、PB、市值、行业、概念
        let quoteFields = "f43,f57,f58,f60,f61,f116,f117,f128,f129,f135,f136,f137,f138,f139,f140,f141,f142,f143,f144,f145,f146,f147,f148,f149,f184,f185"
        let quoteURLString = "https://push2.eastmoney.com/api/qt/stock/get?ut=fa5fd1943c7b386f172d6893dbfba10b&fltt=2&invt=2&volt=2&fields=\(quoteFields)&secid=\(sec)"

        if let quote = await fetchQuote(urlString: quoteURLString) {
            metric.pe = quote.pe
            metric.pb = quote.pb
            metric.totalMarketCap = quote.totalMarketCap
            metric.circulatingMarketCap = quote.circulatingMarketCap
            metric.industry = quote.industry
            metric.concepts = quote.concepts
        }

        // 2. 财务指标接口：ROE、营收增速、净利润增速
        let financeURLString = "https://datacenter-web.eastmoney.com/api/data/v1/get?sortColumns=REPORT_DATE&sortTypes=-1&pageSize=1&pageNumber=1&reportName=RPT_FCI_MAIN_DATA&columns=SECURITY_CODE,REPORT_DATE,TOTAL_OPERATE_INCOME_SQ,PARENT_NETPROFIT_SQ,WEIGHTAVG_ROS&filter=(SECURITY_CODE=\"\(code)\")"

        if let finance = await fetchFinance(urlString: financeURLString) {
            metric.roe = finance.roe
            metric.revenueGrowth = finance.revenueGrowth
            metric.profitGrowth = finance.profitGrowth
        }

        // 3. 如果概念/行业缺失，尝试搜索引擎兜底补充
        if metric.concepts.isEmpty {
            if let search = await SearchEngineAPI.searchF10(keyword: "\(code) \(metric.industry) 所属概念 财务指标") {
                if metric.industry.isEmpty { metric.industry = search.industry }
                metric.concepts = search.concepts
                if metric.pe == 0 { metric.pe = search.pe }
                if metric.pb == 0 { metric.pb = search.pb }
                if metric.roe == 0 { metric.roe = search.roe }
                if metric.revenueGrowth == 0 { metric.revenueGrowth = search.revenueGrowth }
                if metric.profitGrowth == 0 { metric.profitGrowth = search.profitGrowth }
                metric.source = "search"
            }
        }

        // 只要拿到任意有效信息就返回，避免全部为零时无意义展示
        let hasData = metric.pe != 0 || metric.pb != 0 || metric.roe != 0
            || metric.revenueGrowth != 0 || metric.profitGrowth != 0
            || !metric.industry.isEmpty || !metric.concepts.isEmpty
            || metric.totalMarketCap != 0
        return hasData ? metric : nil
    }

    // MARK: - F10 Helpers

    private struct QuoteInfo {
        let pe: Double
        let pb: Double
        let totalMarketCap: Double
        let circulatingMarketCap: Double
        let industry: String
        let concepts: String
    }

    private static func fetchQuote(urlString: String) async -> QuoteInfo? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let headers = ["User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
                           "Referer": "https://quote.eastmoney.com/"]
            let raw = try await NetworkClient.shared.fetchString(url, headers: headers)
            guard let data = raw.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["data"] as? [String: Any] else { return nil }

            let pe = parseDouble(result["f60"])
            let pb = parseDouble(result["f61"])
            // 总市值/流通市值接口返回单位：万元，转换为元
            let totalMarketCap = parseDouble(result["f116"]) * 10_000
            let circulatingMarketCap = parseDouble(result["f117"]) * 10_000

            let industry = stringValue(result["f128"])
                .replacingOccurrences(of: "—", with: "")
                .trimmingCharacters(in: .whitespaces)

            var conceptParts: [String] = []
            for key in ["f129", "f184", "f185", "f135", "f136", "f137", "f138", "f139",
                        "f140", "f141", "f142", "f143", "f144", "f145", "f146", "f147", "f148", "f149"] {
                let value = stringValue(result[key])
                    .replacingOccurrences(of: "—", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !value.isEmpty && value != "0" {
                    conceptParts.append(contentsOf: value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
                }
            }
            let concepts = Array(Set(conceptParts)).joined(separator: ", ")

            return QuoteInfo(pe: pe, pb: pb, totalMarketCap: totalMarketCap,
                             circulatingMarketCap: circulatingMarketCap,
                             industry: industry, concepts: concepts)
        } catch {
            print("EastMoney quote fetch failed: \(error)")
            return nil
        }
    }

    private struct FinanceInfo {
        let roe: Double
        let revenueGrowth: Double
        let profitGrowth: Double
    }

    private static func fetchFinance(urlString: String) async -> FinanceInfo? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let headers = ["User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
                           "Referer": "https://f10.eastmoney.com/"]
            let raw = try await NetworkClient.shared.fetchString(url, headers: headers)
            guard let data = raw.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let rows = result["data"] as? [[String: Any]],
                  let first = rows.first else { return nil }

            return FinanceInfo(
                roe: normalizePercent(parseDouble(first["WEIGHTAVG_ROS"])),
                revenueGrowth: normalizePercent(parseDouble(first["TOTAL_OPERATE_INCOME_SQ"])),
                profitGrowth: normalizePercent(parseDouble(first["PARENT_NETPROFIT_SQ"]))
            )
        } catch {
            print("EastMoney finance fetch failed: \(error)")
            return nil
        }
    }

    /// 东方财富部分字段以百分数形式返回（如 15.3 表示 15.3%），也有以 0.153 返回的。统一转成百分比数值。
    private static func normalizePercent(_ value: Double) -> Double {
        if value > 10 {
            return value // 已经是百分比
        } else if value > 0 {
            return value * 100
        }
        return value
    }

    private static func parseDouble(_ value: Any?) -> Double {
        if let num = value as? Double { return num }
        if let num = value as? Int { return Double(num) }
        if let str = value as? String { return Double(str) ?? 0 }
        return 0
    }

    private static func stringValue(_ value: Any?) -> String {
        if let str = value as? String { return str }
        if let num = value as? NSNumber { return num.stringValue }
        return ""
    }

    // MARK: - Utilities

    private static func codeToSymbol(_ code: String) -> String {
        if code.hasPrefix("6") { return "sh\(code)" }
        if code.hasPrefix("0") || code.hasPrefix("3") { return "sz\(code)" }
        return code
    }
}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f
    }()
}
