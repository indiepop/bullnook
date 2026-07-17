import Foundation

enum LLMProvider: String, CaseIterable, Identifiable {
    case deepSeek = "DeepSeek"
    case kimi = "Kimi"
    case kimiCode = "Kimi Code"
    case qianwen = "通义千问"
    case zhipu = "智谱清言"
    case custom = "自定义 (OpenAI 兼容)"

    var id: String { rawValue }

    var defaultBaseURL: String {
        switch self {
        case .deepSeek: return "https://api.deepseek.com/chat/completions"
        case .kimi: return "https://api.moonshot.cn/v1/chat/completions"
        case .kimiCode: return "https://api.kimi.com/coding/v1/chat/completions"
        case .qianwen: return "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation"
        case .zhipu: return "https://open.bigmodel.cn/api/paas/v4/chat/completions"
        case .custom: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .deepSeek: return "deepseek-chat"
        case .kimi: return "moonshot-v1-8k"
        case .kimiCode: return "kimi-k2.7-code"
        case .qianwen: return "qwen-turbo"
        case .zhipu: return "glm-4-flash"
        case .custom: return ""
        }
    }

    var isOpenAICompatible: Bool {
        switch self {
        case .deepSeek, .kimi, .kimiCode, .zhipu, .custom:
            return true
        case .qianwen:
            return false
        }
    }
}

struct LLMConfig: Codable {
    var provider: String
    var apiKey: String
    var customBaseURL: String?
    var customModel: String?
}

struct LLMAnalysisContext {
    let pick: DailyPick
    let allPicks: [DailyPick]
    let quote: RealTimeQuote?
    let f10: F10Metric?
    let kline: [KLineData]
    let news: [StockNews]
    let sectorSummary: String
}

actor LLMAnalyzer {

    func analyze(context: LLMAnalysisContext, config: LLMConfig?) async -> String {
        guard let config = config, !config.apiKey.isEmpty else {
            return fallbackAnalysis(context: context)
        }

        guard let provider = LLMProvider(rawValue: config.provider) else {
            return fallbackAnalysis(context: context)
        }

        let prompt = buildPrompt(context: context)

        do {
            switch provider {
            case .deepSeek, .kimi, .kimiCode, .zhipu:
                return try await callOpenAICompatible(provider: provider, config: config, prompt: prompt)
            case .custom:
                return try await callCustom(config: config, prompt: prompt)
            case .qianwen:
                return try await callQianwen(apiKey: config.apiKey, prompt: prompt)
            }
        } catch {
            print("LLM analysis failed: \(error)")
            return fallbackAnalysis(context: context)
        }
    }

    private func fallbackAnalysis(context: LLMAnalysisContext) -> String {
        let pick = context.pick
        return "【规则摘要】\(pick.stockName)(\(pick.stockCode)) 今日入选原因：\(pick.reasonSummary)。四维度得分：板块热度 \(String(format: "%.1f", pick.sectorScore))，龙虎榜 \(String(format: "%.1f", pick.lhbScore))，走势 \(String(format: "%.1f", pick.trendScore))，消息 \(String(format: "%.1f", pick.newsScore))。请在设置中配置 LLM API Key 以获取智能分析。"
    }

    private func buildPrompt(context: LLMAnalysisContext) -> String {
        let pick = context.pick
        let peers = context.allPicks.filter { $0.id != pick.id }
            .map { "\($0.stockName)(\($0.stockCode)) 综合得分 \(String(format: "%.1f", $0.score))，行业 \($0.industry)" }
            .joined(separator: "\n")

        let quoteInfo: String
        if let quote = context.quote {
            quoteInfo = """
            当前股价：\(String(format: "%.2f", quote.currentPrice)) 元
            涨跌额：\(String(format: "%.2f", quote.currentPrice - quote.previousClose)) 元
            涨跌幅：\(formatChangePercent(quote.changePercent))
            开盘价：\(String(format: "%.2f", quote.open)) 元
            最高价：\(String(format: "%.2f", quote.high)) 元
            最低价：\(String(format: "%.2f", quote.low)) 元
            成交量：\(formatVolume(quote.volume))
            成交额：\(formatAmount(quote.amount))
            """
        } else {
            quoteInfo = "实时行情：暂不可用"
        }

        let f10Info: String
        if let f10 = context.f10 {
            f10Info = """
            所属行业：\(f10.industry.isEmpty ? "未获取" : f10.industry)
            所属概念：\(f10.concepts.isEmpty ? "未获取" : f10.concepts)
            市盈率 PE：\(f10.pe > 0 ? String(format: "%.2f", f10.pe) : "--")
            市净率 PB：\(f10.pb > 0 ? String(format: "%.2f", f10.pb) : "--")
            ROE：\(f10.roe != 0 ? String(format: "%.2f%%", f10.roe) : "--")
            营收增速：\(f10.revenueGrowth != 0 ? String(format: "%.2f%%", f10.revenueGrowth) : "--")
            净利润增速：\(f10.profitGrowth != 0 ? String(format: "%.2f%%", f10.profitGrowth) : "--")
            总市值：\(formatMarketCap(f10.totalMarketCap))
            流通市值：\(formatMarketCap(f10.circulatingMarketCap))
            """
        } else {
            f10Info = "F10 财务数据：暂不可用"
        }

        let trendInfo = trendSummary(kline: context.kline)
        let newsTitles = context.news.prefix(8).map { "- \($0.title)（\($0.publishTime)）" }.joined(separator: "\n")
        let newsInfo = newsTitles.isEmpty ? "近期新闻：暂无可用手动抓取的新闻" : "近期新闻：\n" + newsTitles

        return """
        你是一位资深的 A 股策略分析师，擅长结合基本面、技术面、资金面、消息面和板块轮动进行深度研判。请对以下股票进行一次详尽、透彻、结构化的投资分析，并给出明确结论。

        === 股票基本信息 ===
        股票名称：\(pick.stockName)
        股票代码：\(pick.stockCode)
        所属行业：\(pick.industry)

        === 今日行情 ===
        \(quoteInfo)

        === F10 与财务概况 ===
        \(f10Info)

        === 四维度评分（0-100） ===
        板块热度：\(String(format: "%.1f", pick.sectorScore))
        龙虎榜资金：\(String(format: "%.1f", pick.lhbScore))
        个股走势：\(String(format: "%.1f", pick.trendScore))
        消息链：\(String(format: "%.1f", pick.newsScore))
        综合得分：\(String(format: "%.1f", pick.score))，排名第 \(pick.rank)

        === 同批次入选股票 ===
        \(peers.isEmpty ? "无" : peers)

        === 板块总体概况 ===
        \(context.sectorSummary)

        === 近期走势摘要 ===
        \(trendInfo)

        === 新闻与消息 ===
        \(newsInfo)

        请按以下结构输出分析（每部分尽量详细，总字数 600-1000 字）：
        1. **投资逻辑与核心结论**：给出明确的看多/看空/中性判断及理由。
        2. **基本面与估值分析**：结合 PE、PB、ROE、营收/净利润增速、所属行业与概念进行评价。
        3. **技术面分析**：根据近期走势摘要判断趋势、支撑/压力、成交量配合等。
        4. **板块与资金驱动**：结合板块概况和龙虎榜得分，分析是否有板块轮动或资金推动。
        5. **消息与事件驱动**：结合近期新闻判断潜在催化或风险。
        6. **主要风险提示**：列出至少 2-3 条具体风险。
        7. **总结**：用 2-3 句话概括核心观点。

        要求：
        - 专业、客观、有数据支撑，避免空泛套话。
        - 不要给出具体买入价位、卖出价位或仓位建议。
        - 若某类数据缺失，明确说明“数据缺失，无法判断”，不要编造。
        """
    }

    private func trendSummary(kline: [KLineData]) -> String {
        guard kline.count >= 5 else { return "K 线数据不足，无法判断趋势" }
        let sorted = kline.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last, last.close > 0 else {
            return "K 线数据异常"
        }
        let totalChange = (last.close - first.close) / first.close * 100
        let ma5 = sorted.suffix(5).map(\.close).reduce(0, +) / 5
        let ma10 = sorted.suffix(min(10, sorted.count)).map(\.close).reduce(0, +) / Double(min(10, sorted.count))
        let ma20 = sorted.suffix(min(20, sorted.count)).map(\.close).reduce(0, +) / Double(min(20, sorted.count))
        let maxClose = sorted.map(\.close).max() ?? last.close
        let minClose = sorted.map(\.close).min() ?? last.close
        return """
        区间涨跌幅：\(String(format: "%.2f%%", totalChange))
        最新收盘价：\(String(format: "%.2f", last.close))
        MA5：\(String(format: "%.2f", ma5))
        MA10：\(String(format: "%.2f", ma10))
        MA20：\(String(format: "%.2f", ma20))
        区间最高价：\(String(format: "%.2f", maxClose))
        区间最低价：\(String(format: "%.2f", minClose))
        """
    }

    private func formatChangePercent(_ value: Double) -> String {
        if value > 0 {
            return String(format: "+%.2f%%", value)
        } else if value < 0 {
            return String(format: "%.2f%%", value)
        } else {
            return "0.00%"
        }
    }

    private func formatVolume(_ value: Double) -> String {
        if value >= 1_0000_0000 { return String(format: "%.2f 亿手", value / 1_0000_0000) }
        if value >= 10000 { return String(format: "%.2f 万手", value / 10000) }
        return String(format: "%.0f 手", value)
    }

    private func formatAmount(_ value: Double) -> String {
        if value >= 1_0000_0000 { return String(format: "%.2f 亿", value / 1_0000_0000) }
        if value >= 10000 { return String(format: "%.2f 万", value / 10000) }
        return String(format: "%.0f", value)
    }

    private func formatMarketCap(_ value: Double) -> String {
        if value >= 1_000_000_000_000 { return String(format: "%.2f 万亿", value / 1_000_000_000_000) }
        if value >= 100_000_000 { return String(format: "%.2f 亿", value / 100_000_000) }
        return String(format: "%.0f", value)
    }

    // MARK: - OpenAI Compatible

    private func callOpenAICompatible(provider: LLMProvider, config: LLMConfig, prompt: String) async throws -> String {
        guard let url = URL(string: provider.defaultBaseURL) else { throw NetworkError.invalidResponse }

        let temperature: Double = provider == .kimiCode ? 1.0 : 0.7
        let body: [String: Any] = [
            "model": provider.defaultModel,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": temperature,
            "max_tokens": 2000
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.apiError(statusCode: httpResponse.statusCode, message: errorMessage(from: data))
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NetworkError.decodingFailure
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Custom OpenAI Compatible

    private func callCustom(config: LLMConfig, prompt: String) async throws -> String {
        let baseURL = config.customBaseURL?.trimmingCharacters(in: .whitespaces) ?? ""
        let model = config.customModel?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !baseURL.isEmpty, let url = URL(string: baseURL) else { throw NetworkError.invalidResponse }
        guard !model.isEmpty else { throw NetworkError.invalidResponse }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 2000
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.apiError(statusCode: httpResponse.statusCode, message: errorMessage(from: data))
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NetworkError.decodingFailure
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Qianwen

    private func callQianwen(apiKey: String, prompt: String) async throws -> String {
        guard let url = URL(string: LLMProvider.qianwen.defaultBaseURL) else { throw NetworkError.invalidResponse }

        let body: [String: Any] = [
            "model": LLMProvider.qianwen.defaultModel,
            "input": [
                "messages": [
                    ["role": "user", "content": prompt]
                ]
            ],
            "parameters": [
                "temperature": 0.7,
                "max_tokens": 2000
            ]
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.apiError(statusCode: httpResponse.statusCode, message: errorMessage(from: data))
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any],
              let text = output["text"] as? String else {
            throw NetworkError.decodingFailure
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Connectivity Test

    func testConnection(config: LLMConfig) async -> (success: Bool, message: String) {
        guard !config.apiKey.isEmpty else {
            return (false, "请先输入 API Key")
        }
        guard let provider = LLMProvider(rawValue: config.provider) else {
            return (false, "未知的服务商")
        }

        let prompt = "你好，请回复：连接成功"
        do {
            switch provider {
            case .deepSeek, .kimi, .kimiCode, .zhipu:
                _ = try await callOpenAICompatible(provider: provider, config: config, prompt: prompt)
            case .custom:
                _ = try await callCustom(config: config, prompt: prompt)
            case .qianwen:
                _ = try await callQianwen(apiKey: config.apiKey, prompt: prompt)
            }
            return (true, "连接成功")
        } catch let error as NetworkError {
            return (false, "连接失败：\(error.localizedDescription)")
        } catch {
            return (false, "连接失败：\(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func errorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? [String: Any], let msg = error["message"] as? String {
                return msg
            }
            if let msg = json["message"] as? String {
                return msg
            }
        }
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return String(text.prefix(200))
        }
        return "未知错误"
    }
}
