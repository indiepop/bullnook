import Foundation
import SwiftData

@Model
class F10Metric {
    @Attribute(.unique) var symbol: String
    var pe: Double
    var pb: Double
    var roe: Double
    var revenueGrowth: Double
    var profitGrowth: Double
    var totalMarketCap: Double
    var circulatingMarketCap: Double
    var industry: String
    var concepts: String
    var source: String
    var updatedAt: Date

    init(symbol: String, pe: Double = 0, pb: Double = 0, roe: Double = 0, revenueGrowth: Double = 0, profitGrowth: Double = 0, totalMarketCap: Double = 0, circulatingMarketCap: Double = 0, industry: String = "", concepts: String = "", source: String = "", updatedAt: Date = Date()) {
        self.symbol = symbol
        self.pe = pe
        self.pb = pb
        self.roe = roe
        self.revenueGrowth = revenueGrowth
        self.profitGrowth = profitGrowth
        self.totalMarketCap = totalMarketCap
        self.circulatingMarketCap = circulatingMarketCap
        self.industry = industry
        self.concepts = concepts
        self.source = source
        self.updatedAt = updatedAt
    }

    var conceptList: [String] {
        concepts.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
