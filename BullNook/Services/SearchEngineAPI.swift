import Foundation

struct SearchF10Info {
    let industry: String
    let concepts: String
    let pe: Double
    let pb: Double
    let roe: Double
    let revenueGrowth: Double
    let profitGrowth: Double
}

struct SearchEngineAPI {

    /// 通过公开搜索引擎获取个股 F10 信息兜底。
    /// 当前使用 DuckDuckGo HTML 结果解析；若不可用则返回 nil。
    static func searchF10(keyword: String) async -> SearchF10Info? {
        let query = "\(keyword) 所属概念 财务指标".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let urlString = "https://html.duckduckgo.com/html/?q=\(query)"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let headers = ["User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"]
            let html = try await NetworkClient.shared.fetchString(url, headers: headers, retries: 2)
            let snippets = extractSnippets(from: html)
            return parseF10(from: snippets)
        } catch {
            print("Search engine F10 fetch failed: \(error)")
            return nil
        }
    }

    private static func extractSnippets(from html: String) -> [String] {
        // DuckDuckGo 结果摘要通常在 .result__snippet 中
        var snippets: [String] = []
        let pattern = "<[^>]*class=\"[^\"]*result__snippet[^\"]*\"[^>]*>(.*?)</a>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return snippets }
        let range = NSRange(html.startIndex..., in: html)
        regex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range(at: 1) else { return }
            if let swiftRange = Range(matchRange, in: html) {
                var snippet = String(html[swiftRange])
                snippet = snippet.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
                snippet = snippet.decodedHTMLEntities()
                snippets.append(snippet)
            }
        }
        return snippets
    }

    private static func parseF10(from snippets: [String]) -> SearchF10Info? {
        let text = snippets.joined(separator: "\n")
        guard !text.isEmpty else { return nil }

        let industry = extractValue(text, patterns: [
            "所属行业[：:]\\s*([^\\n,，。；;]+)",
            "行业分类[：:]\\s*([^\\n,，。；;]+)",
            "行业[：:]\\s*([^\\n,，。；;]+)"
        ])

        let concepts = extractValue(text, patterns: [
            "所属概念[：:]\\s*([^\\n。；;]+)",
            "概念板块[：:]\\s*([^\\n。；;]+)",
            "涉及概念[：:]\\s*([^\\n。；;]+)"
        ])

        let pe = extractNumber(text, patterns: [
            "市盈率(?:\\(TTM\\))?[：:]\\s*(-?\\d+\\.?\\d*)",
            "PE(?:\\(TTM\\))?[：:]\\s*(-?\\d+\\.?\\d*)"
        ])

        let pb = extractNumber(text, patterns: [
            "市净率[：:]\\s*(-?\\d+\\.?\\d*)",
            "PB[：:]\\s*(-?\\d+\\.?\\d*)"
        ])

        let roe = extractNumber(text, patterns: [
            "ROE[：:]\\s*(-?\\d+\\.?\\d*)%?",
            "净资产收益率[：:]\\s*(-?\\d+\\.?\\d*)%?"
        ])

        let revenueGrowth = extractNumber(text, patterns: [
            "营收(?:收入)?(?:同比)?(?:增长)?[：:]\\s*(-?\\d+\\.?\\d*)%?",
            "营业收入增长[：:]\\s*(-?\\d+\\.?\\d*)%?"
        ])

        let profitGrowth = extractNumber(text, patterns: [
            "净利润(?:同比)?(?:增长)?[：:]\\s*(-?\\d+\\.?\\d*)%?",
            "归母净利润增长[：:]\\s*(-?\\d+\\.?\\d*)%?"
        ])

        let hasData = !industry.isEmpty || !concepts.isEmpty || pe != 0 || pb != 0 || roe != 0 || revenueGrowth != 0 || profitGrowth != 0
        guard hasData else { return nil }

        return SearchF10Info(
            industry: industry,
            concepts: concepts,
            pe: pe,
            pb: pb,
            roe: roe,
            revenueGrowth: revenueGrowth,
            profitGrowth: profitGrowth
        )
    }

    private static func extractValue(_ text: String, patterns: [String]) -> String {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
                  let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range(at: 1), in: text) else { continue }
            return String(text[range]).trimmingCharacters(in: .whitespaces)
        }
        return ""
    }

    private static func extractNumber(_ text: String, patterns: [String]) -> Double {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
                  let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range(at: 1), in: text) else { continue }
            return Double(String(text[range])) ?? 0
        }
        return 0
    }
}

private extension String {
    func decodedHTMLEntities() -> String {
        var result = self
        let entities = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " "
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        return result
    }
}
