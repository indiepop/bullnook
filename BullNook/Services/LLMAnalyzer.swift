import Foundation

enum LLMProvider: String, CaseIterable, Identifiable {
    case deepSeek = "DeepSeek"
    case kimi = "Kimi"
    case qianwen = "通义千问"

    var id: String { rawValue }

    var baseURL: String {
        switch self {
        case .deepSeek: return "https://api.deepseek.com/chat/completions"
        case .kimi: return "https://api.moonshot.cn/v1/chat/completions"
        case .qianwen: return "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation"
        }
    }
}

struct LLMConfig: Codable {
    var provider: String
    var apiKey: String
}

actor LLMAnalyzer {

    func analyze(pick: DailyPick, allPicks: [DailyPick], config: LLMConfig?) async -> String {
        guard let config = config, !config.apiKey.isEmpty else {
            return fallbackAnalysis(pick: pick)
        }

        guard let provider = LLMProvider(rawValue: config.provider) else {
            return fallbackAnalysis(pick: pick)
        }

        let prompt = buildPrompt(pick: pick, allPicks: allPicks)

        do {
            switch provider {
            case .deepSeek, .kimi:
                return try await callOpenAICompatible(provider: provider, apiKey: config.apiKey, prompt: prompt)
            case .qianwen:
                return try await callQianwen(apiKey: config.apiKey, prompt: prompt)
            }
        } catch {
            print("LLM analysis failed: \(error)")
            return fallbackAnalysis(pick: pick)
        }
    }

    private func fallbackAnalysis(pick: DailyPick) -> String {
        return "【规则摘要】\(pick.stockName)(\(pick.stockCode)) 今日入选原因：\(pick.reasonSummary)。四维度得分：板块热度 \(String(format: "%.1f", pick.sectorScore))，龙虎榜 \(String(format: "%.1f", pick.lhbScore))，走势 \(String(format: "%.1f", pick.trendScore))，消息 \(String(format: "%.1f", pick.newsScore))。请在设置中配置 LLM API Key 以获取智能分析。"
    }

    private func buildPrompt(pick: DailyPick, allPicks: [DailyPick]) -> String {
        let peers = allPicks.filter { $0.id != pick.id }.map { "\($0.stockName)(\($0.stockCode)) 得分 \($0.score)" }.joined(separator: "；")
        return """
        你是一位专业的 A 股分析师。请用 100-150 字分析股票 \(pick.stockName)(代码 \(pick.stockCode)) 今日入选“每日精选”的原因。
        行业：\(pick.industry)。
        四维度得分（0-100）：板块热度 \(String(format: "%.1f", pick.sectorScore))，龙虎榜资金 \(String(format: "%.1f", pick.lhbScore))，个股走势 \(String(format: "%.1f", pick.trendScore))，消息链 \(String(format: "%.1f", pick.newsScore))。综合得分 \(String(format: "%.1f", pick.score))。
        其他入选股票：\(peers)。
        要求：专业、客观、风险提示，不要给出具体买卖建议。
        """
    }

    private func callOpenAICompatible(provider: LLMProvider, apiKey: String, prompt: String) async throws -> String {
        guard let url = URL(string: provider.baseURL) else { throw NetworkError.invalidResponse }

        let body: [String: Any] = [
            "model": provider == .kimi ? "moonshot-v1-8k" : "deepseek-chat",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 300
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
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

    private func callQianwen(apiKey: String, prompt: String) async throws -> String {
        guard let url = URL(string: LLMProvider.qianwen.baseURL) else { throw NetworkError.invalidResponse }

        let body: [String: Any] = [
            "model": "qwen-turbo",
            "input": [
                "messages": [
                    ["role": "user", "content": prompt]
                ]
            ],
            "parameters": [
                "temperature": 0.7,
                "max_tokens": 300
            ]
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any],
              let text = output["text"] as? String else {
            throw NetworkError.decodingFailure
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
