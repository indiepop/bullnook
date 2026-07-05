import SwiftUI

struct F10View: View {
    let f10: F10Metric?
    let marketCap: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let f10 = f10 {
                metricRow(title: "市盈率 (PE)", value: String(format: "%.2f", f10.pe))
                metricRow(title: "市净率 (PB)", value: String(format: "%.2f", f10.pb))
                metricRow(title: "ROE", value: String(format: "%.2f%%", f10.roe))
                metricRow(title: "营收增速", value: String(format: "%.2f%%", f10.revenueGrowth))
                metricRow(title: "净利润增速", value: String(format: "%.2f%%", f10.profitGrowth))
                metricRow(title: "总市值", value: formatMarketCap(f10.totalMarketCap))
                metricRow(title: "流通市值", value: formatMarketCap(f10.circulatingMarketCap))
            } else {
                Text("F10 数据暂不可用")
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.appTextSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(Color.appTextPrimary)
                .fontWeight(.medium)
        }
    }

    private func formatMarketCap(_ value: Double) -> String {
        if value >= 1_000_000_000_000 { return String(format: "%.2f 万亿", value / 1_000_000_000_000) }
        if value >= 100_000_000 { return String(format: "%.2f 亿", value / 100_000_000) }
        return String(format: "%.0f", value)
    }
}
