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
