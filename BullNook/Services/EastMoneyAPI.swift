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

    // MARK: - KLine

    static func kline(symbol: String, period: KLinePeriod = .daily, start: String, end: String) async -> [KLineData] {
        let sec = secid(for: symbol)
        let klt = klt(for: period)
        let urlString = "https://push2his.eastmoney.com/api/qt/stock/kline/get?secid=\(sec)&fields1=f1,f2,f3,f4,f5,f6&fields2=f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61&klt=\(klt)&fqt=1&beg=\(start)&end=\(end)"
        guard let url = URL(string: urlString) else { return [] }

        do {
            let raw = try await NetworkClient.shared.fetchString(url)
            return parseKLine(raw: raw, symbol: symbol)
        } catch {
            print("EastMoney kline fetch failed: \(error)")
            return []
        }
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
        let urlString = "https://push2.eastmoney.com/api/qt/clist/get?pn=1&pz=100&po=1&np=1&fltt=2&invt=2&fid=f3&fs=m:90+t:2&fields=f12,f14,f2,f3,f4,f5,f6,f7,f8,f9,f10,f20,f21,f22"
        guard let url = URL(string: urlString) else { return [] }

        do {
            let raw = try await NetworkClient.shared.fetchString(url)
            return parseSectors(raw: raw)
        } catch {
            print("EastMoney sector list fetch failed: \(error)")
            return []
        }
    }

    private static func parseSectors(raw: String) -> [SectorData] {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["data"] as? [String: Any],
              let diff = result["diff"] as? [[String: Any]] else { return [] }

        let today = DateFormatter.yyyyMMdd.string(from: Date())
        return diff.compactMap { item -> SectorData? in
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
        let code = String(symbol.dropFirst(2))
        let urlString = "https://f10.eastmoney.com/FinancialAnalysis/Index?type=web&code=\(code)"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let raw = try await NetworkClient.shared.fetchString(url)
            return parseF10(raw: raw, symbol: symbol)
        } catch {
            print("EastMoney F10 fetch failed: \(error)")
            return nil
        }
    }

    private static func parseF10(raw: String, symbol: String) -> F10Metric? {
        // Public F10 endpoints vary; fallback to default zeros so the UI degrades gracefully.
        return F10Metric(symbol: symbol)
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
