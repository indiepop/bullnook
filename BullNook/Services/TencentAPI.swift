import Foundation

struct TencentAPI {
    static func realTimeQuotes(symbols: [String]) async -> [RealTimeQuote] {
        guard !symbols.isEmpty else { return [] }
        let list = symbols.joined(separator: ",")
        guard let url = URL(string: "https://qt.gtimg.cn/q=\(list)") else { return [] }

        do {
            let raw = try await NetworkClient.shared.fetchString(url)
            return parseQuotes(raw: raw, symbols: symbols)
        } catch {
            print("Tencent real-time quote fetch failed: \(error)")
            return []
        }
    }

    private static func parseQuotes(raw: String, symbols: [String]) -> [RealTimeQuote] {
        var quotes: [RealTimeQuote] = []
        for symbol in symbols {
            let key = "v_\(symbol)"
            guard let range = raw.range(of: "\(key)=\""),
                  let endRange = raw[range.upperBound...].range(of: "\";") else { continue }
            let content = String(raw[range.upperBound..<endRange.lowerBound])
            let parts = content.split(separator: "~").map(String.init)
            guard parts.count >= 45 else { continue }

            let name = parts[1]
            let currentPrice = Double(parts[3]) ?? 0
            let previousClose = Double(parts[4]) ?? 0
            let open = Double(parts[5]) ?? 0
            let high = Double(parts[33]) ?? 0
            let low = Double(parts[34]) ?? 0
            let volume = Double(parts[36]) ?? 0
            let amount = Double(parts[37]) ?? 0

            quotes.append(RealTimeQuote(
                symbol: symbol,
                name: name,
                currentPrice: currentPrice,
                previousClose: previousClose,
                open: open,
                high: high,
                low: low,
                volume: volume,
                amount: amount,
                dateTime: parts[30]
            ))
        }
        return quotes
    }
}
