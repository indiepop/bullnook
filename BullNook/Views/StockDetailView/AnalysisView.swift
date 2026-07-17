import SwiftUI

struct AnalysisView: View {
    let pick: DailyPick

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("四维度得分")
                .font(.headline)
                .foregroundStyle(Color.appTextPrimary)

            scoreRow(title: "板块热度", score: pick.sectorScore)
            scoreRow(title: "龙虎榜资金", score: pick.lhbScore)
            scoreRow(title: "个股走势", score: pick.trendScore)
            scoreRow(title: "消息链", score: pick.newsScore)

            Divider()
                .background(Color.appTertiary)

            Text("智能投研分析")
                .font(.headline)
                .foregroundStyle(Color.appTextPrimary)

            if pick.analysis.isEmpty || pick.analysis.contains("规则摘要") || pick.analysis.contains("请在设置中配置") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(pick.analysis.isEmpty ? pick.reasonSummary : pick.analysis)
                        .font(.body)
                        .foregroundStyle(Color.appTextSecondary)
                    Text("在设置中配置 LLM API Key 后可获取更详尽透彻的智能分析。")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
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
