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

            Text("入选分析")
                .font(.headline)
                .foregroundStyle(Color.appTextPrimary)

            Text(pick.analysis.isEmpty ? pick.reasonSummary : pick.analysis)
                .font(.body)
                .foregroundStyle(Color.appTextSecondary)

            DisclaimerView()
        }
        .padding()
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
