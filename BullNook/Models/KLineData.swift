import Foundation
import SwiftData

@Model
class KLineData {
    var symbol: String
    var date: String
    var open: Double
    var high: Double
    var low: Double
    var close: Double
    var volume: Double
    var amount: Double
    var amplitude: Double
    var changePercent: Double
    var changeAmount: Double
    var turnover: Double

    init(symbol: String, date: String, open: Double, high: Double, low: Double, close: Double, volume: Double, amount: Double = 0, amplitude: Double = 0, changePercent: Double = 0, changeAmount: Double = 0, turnover: Double = 0) {
        self.symbol = symbol
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.amount = amount
        self.amplitude = amplitude
        self.changePercent = changePercent
        self.changeAmount = changeAmount
        self.turnover = turnover
    }
}

extension KLineData {
    /// 将 `date` 字段解析为 `Date`，兼容 "yyyy-MM-dd" 与 "yyyyMMdd" 两种格式。
    var plottedDate: Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        for format in ["yyyy-MM-dd", "yyyyMMdd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: date) {
                return date
            }
        }
        return nil
    }
}
