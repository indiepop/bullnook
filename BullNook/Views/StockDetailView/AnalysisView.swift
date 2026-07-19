import SwiftUI

struct AnalysisView: View {
    let pick: DailyPick
    let isLLMConfigured: Bool
    let isAnalysisLoading: Bool

    private var topDimensions: [(String, Double)] {
        let all = [
            ("板块热度", pick.sectorScore),
            ("龙虎榜资金", pick.lhbScore),
            ("个股走势", pick.trendScore),
            ("消息链", pick.newsScore)
        ]
        let sorted = all.sorted { $0.1 > $1.1 }
        // 只展示得分最高的 1–2 个维度，让每个股票的亮点不同；如果最高分和次高分差距很小，展示前 2
        let top = Array(sorted.prefix(2))
        // 过滤掉全是 0 的 watchlist 占位数据
        return top.filter { $0.1 > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !topDimensions.isEmpty {
                Text("亮点维度")
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)

                ForEach(topDimensions, id: \.0) { title, score in
                    scoreRow(title: title, score: score)
                }

                Divider()
                    .background(Color.appTertiary)
            }

            Text("智能投研分析")
                .font(.headline)
                .foregroundStyle(Color.appTextPrimary)

            if isAnalysisLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在生成智能分析...")
                        .font(.body)
                        .foregroundStyle(Color.appTextSecondary)
                }
                .padding(.vertical, 8)
            } else if pick.analysis.isEmpty || pick.analysis.contains("规则摘要") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(pick.analysis.isEmpty ? pick.reasonSummary : pick.analysis)
                        .font(.body)
                        .foregroundStyle(Color.appTextSecondary)
                    if isLLMConfigured {
                        Text("已触发智能分析，请稍后回来查看结果。")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    } else {
                        Text("在设置中配置 LLM API Key 后可获取更详尽透彻的智能分析。")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
            } else {
                analysisContent(text: pick.analysis)
                    .font(.body)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineSpacing(6)
            }

            DisclaimerView()
        }
        .padding()
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func analysisContent(text: String) -> some View {
        if let attributed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            Text(attributed)
        } else {
            Text(text)
        }
    }

    private func scoreRow(title: String, score: Double) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.appTextSecondary)
            Spacer()
            Text(String(format: "%.1f", score))
                .foregroundStyle(Color.appAccentGold)
                .fontWeight(.bold)
        }
    }
}
