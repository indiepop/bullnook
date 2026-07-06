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
        .chartXAxis {
            AxisMarks(preset: .aligned, position: .bottom) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let dateString = value.as(String.self),
                       let label = formattedDate(dateString) {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
            }
        }
        .frame(height: 260)
    }

    private func color(for item: KLineData) -> Color {
        if item.close > item.open { return Color.appUp }
        if item.close < item.open { return Color.appDown }
        return Color.appNeutral
    }

    private func formattedDate(_ dateString: String) -> String? {
        let inputFormats = ["yyyy-MM-dd", "yyyyMMdd"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")

        for format in inputFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                formatter.dateFormat = "MM/dd"
                return formatter.string(from: date)
            }
        }
        return String(dateString.prefix(5))
    }
}
