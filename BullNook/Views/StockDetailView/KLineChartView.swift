import SwiftUI
import Charts

struct KLineChartView: View {
    let data: [KLineData]
    let period: KLinePeriod

    private var sortedData: [KLineData] {
        data.sorted { $0.date < $1.date }
    }

    private var barWidth: CGFloat {
        let width = 260.0 / CGFloat(max(sortedData.count, 1))
        return max(2, min(12, width))
    }

    private var dateFormat: Date.FormatStyle {
        switch period {
        case .daily:
            return .dateTime.month(.defaultDigits).day()
        case .weekly:
            return .dateTime.year(.twoDigits).month(.defaultDigits).day()
        case .monthly:
            return .dateTime.year(.twoDigits).month(.defaultDigits)
        }
    }

    var body: some View {
        Chart(sortedData, id: \.date) { item in
            if let date = item.plottedDate {
                RuleMark(
                    x: .value("Date", date),
                    yStart: .value("Low", item.low),
                    yEnd: .value("High", item.high)
                )
                .foregroundStyle(color(for: item))
                .lineStyle(StrokeStyle(lineWidth: 1))

                RectangleMark(
                    x: .value("Date", date),
                    yStart: .value("Open", item.open),
                    yEnd: .value("Close", item.close),
                    width: .fixed(barWidth)
                )
                .foregroundStyle(color(for: item))
            }
        }
        .id(chartIdentity)
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(preset: .aligned, position: .bottom, values: .automatic(desiredCount: axisLabelCount)) { value in
                AxisGridLine()
                AxisTick()
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date, format: dateFormat)
                            .font(.caption2)
                    }
                }
            }
        }
        .frame(height: 260)
    }

    private var chartIdentity: String {
        "\(period.rawValue)-\(sortedData.count)-\(sortedData.last?.date ?? "")"
    }

    private var axisLabelCount: Int {
        switch period {
        case .daily: return 5
        case .weekly: return 4
        case .monthly: return 4
        }
    }

    private func color(for item: KLineData) -> Color {
        if item.close > item.open { return Color.appUp }
        if item.close < item.open { return Color.appDown }
        return Color.appNeutral
    }
}
