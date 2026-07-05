import Foundation
import SwiftData

@Model
class Stock {
    @Attribute(.unique) var id: String
    var symbol: String
    var name: String
    var industry: String
    var marketCap: Double
    var listDate: String?
    var exchange: String

    init(id: String, symbol: String, name: String, industry: String = "", marketCap: Double = 0, listDate: String? = nil, exchange: String = "") {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.industry = industry
        self.marketCap = marketCap
        self.listDate = listDate
        self.exchange = exchange
    }
}
