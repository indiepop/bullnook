import SwiftUI
import Charts

struct KLineChartView: View {
    let data: [KLineData]

    var body: some View {
        Chart(data) { item in
            RuleMark(
                x: .value("Date", item.date),
                yStart: .value("Low", item.low),
                yEnd: .value("High", item.high)
            )
            .foregroundStyle(color(for: item))
            .lineStyle(StrokeStyle(lineWidth: 1))

            RectangleMark(
                x: .value("Date", item.date),
                yStart: .value("Open", item.open),
                yEnd: .value("Close", item.close),
                width: .fixed(4)
            )
            .foregroundStyle(color(for: item))
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: 260)
    }

    private func color(for item: KLineData) -> Color {
        if item.close > item.open { return Color.appUp }
        if item.close < item.open { return Color.appDown }
        return Color.appNeutral
    }
}
