import Foundation
import SwiftData

@Model
class WatchlistItem {
    @Attribute(.unique) var id: String
    var stockCode: String
    var stockName: String
    var industry: String
    var addedAt: Date
    var currentPrice: Double
    var changePercent: Double
    var lastUpdated: Date

    init(id: String, stockCode: String, stockName: String, industry: String = "", addedAt: Date = Date(), currentPrice: Double = 0, changePercent: Double = 0, lastUpdated: Date = Date()) {
        self.id = id
        self.stockCode = stockCode
        self.stockName = stockName
        self.industry = industry
        self.addedAt = addedAt
        self.currentPrice = currentPrice
        self.changePercent = changePercent
        self.lastUpdated = lastUpdated
    }
}
