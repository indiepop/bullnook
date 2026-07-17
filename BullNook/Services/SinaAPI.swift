import Foundation

struct RealTimeQuote {
    let symbol: String
    let name: String
    let currentPrice: Double
    let previousClose: Double
    let open: Double
    let high: Double
    let low: Double
    let volume: Double
    let amount: Double
    let dateTime: String

    var changePercent: Double {
        guard previousClose > 0 else { return 0 }
        return (currentPrice - previousClose) / previousClose * 100
    }
}

struct SinaAPI {
    static func realTimeQuotes(symbols: [String]) async -> [RealTimeQuote] {
        guard !symbols.isEmpty else { return [] }
        let list = symbols.joined(separator: ",")
        guard let url = URL(string: "https://hq.sinajs.cn/list=\(list)") else { return [] }

        do {
            let headers = ["Referer": "https://finance.sina.com.cn"]
            let raw = try await NetworkClient.shared.fetchString(url, headers: headers)
            return parseQuotes(raw: raw, symbols: symbols)
        } catch {
            print("Sina real-time quote fetch failed: \(error)")
            return []
        }
    }

    private static func parseQuotes(raw: String, symbols: [String]) -> [RealTimeQuote] {
        var quotes: [RealTimeQuote] = []
        for symbol in symbols {
            let key = "hq_str_\(symbol)"
            guard let range = raw.range(of: "var \(key)=\""),
                  let endRange = raw[range.upperBound...].range(of: "\";") else { continue }
            let content = String(raw[range.upperBound..<endRange.lowerBound])
            let parts = content.split(separator: ",").map(String.init)
            guard parts.count >= 33 else { continue }

            quotes.append(RealTimeQuote(
                symbol: symbol,
                name: parts[0],
                currentPrice: Double(parts[3]) ?? 0,
                previousClose: Double(parts[2]) ?? 0,
                open: Double(parts[1]) ?? 0,
                high: Double(parts[4]) ?? 0,
                low: Double(parts[5]) ?? 0,
                volume: Double(parts[8]) ?? 0,
                amount: Double(parts[9]) ?? 0,
                dateTime: "\(parts[30]) \(parts[31])"
            ))
        }
        return quotes
    }

    static func kline(symbol: String, period: KLinePeriod = .daily, count: Int = 250) async -> [KLineData] {
        let d: Int
        switch period {
        case .daily: d = 1
        case .weekly: d = 7
        case .monthly: d = 30
        }
        guard let url = URL(string: "https://quotes.sina.cn/cn/api/quotes.php?symbol=\(symbol)&datalen=\(count)&fq=1&d=\(d)") else { return [] }

        do {
            let headers = ["Referer": "https://finance.sina.com.cn",
                           "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"]
            let raw = try await NetworkClient.shared.fetchString(url, headers: headers)
            return parseKLine(raw: raw, symbol: symbol)
        } catch {
            print("Sina kline fetch failed: \(error)")
            return []
        }
    }

    private static func parseKLine(raw: String, symbol: String) -> [KLineData] {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let dataArray = result["data"] as? [[String: Any]] else { return [] }

        return dataArray.compactMap { item in
            guard let day = item["d"] as? String,
                  let open = item["o"] as? Double,
                  let high = item["h"] as? Double,
                  let low = item["l"] as? Double,
                  let close = item["c"] as? Double,
                  let volume = item["v"] as? Double else { return nil }
            return KLineData(
                symbol: symbol,
                date: day,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume
            )
        }
    }
}

enum KLinePeriod: String, CaseIterable {
    case daily = "日线"
    case weekly = "周线"
    case monthly = "月线"
}
