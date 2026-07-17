import Foundation
import SwiftData

@Model
class DailyPick {
    @Attribute(.unique) var id: String
    var date: String
    var rank: Int
    var stockCode: String
    var stockName: String
    var industry: String
    var score: Double
    var reasonSummary: String
    var sectorScore: Double
    var lhbScore: Double
    var trendScore: Double
    var newsScore: Double
    var analysis: String
    var generatedAt: Date
    var currentPrice: Double = 0
    var changePercent: Double = 0

    init(id: String, date: String, rank: Int, stockCode: String, stockName: String, industry: String, score: Double, reasonSummary: String, sectorScore: Double, lhbScore: Double, trendScore: Double, newsScore: Double, analysis: String, generatedAt: Date = Date(), currentPrice: Double = 0, changePercent: Double = 0) {
        self.id = id
        self.date = date
        self.rank = rank
        self.stockCode = stockCode
        self.stockName = stockName
        self.industry = industry
        self.score = score
        self.reasonSummary = reasonSummary
        self.sectorScore = sectorScore
        self.lhbScore = lhbScore
        self.trendScore = trendScore
        self.newsScore = newsScore
        self.analysis = analysis
        self.generatedAt = generatedAt
        self.currentPrice = currentPrice
        self.changePercent = changePercent
    }
}
