import Foundation
import SwiftData

@Model
class HistoricalPick {
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
    var performanceSincePick: Double = 0
    var pickPrice: Double = 0
    var currentPrice: Double = 0

    init(id: String, date: String, rank: Int, stockCode: String, stockName: String, industry: String, score: Double, reasonSummary: String, sectorScore: Double, lhbScore: Double, trendScore: Double, newsScore: Double, analysis: String, generatedAt: Date = Date(), performanceSincePick: Double = 0, pickPrice: Double = 0, currentPrice: Double = 0) {
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
        self.performanceSincePick = performanceSincePick
        self.pickPrice = pickPrice
        self.currentPrice = currentPrice
    }

    convenience init(from dailyPick: DailyPick, performanceSincePick: Double = 0, pickPrice: Double = 0, currentPrice: Double = 0) {
        self.init(
            id: dailyPick.id,
            date: dailyPick.date,
            rank: dailyPick.rank,
            stockCode: dailyPick.stockCode,
            stockName: dailyPick.stockName,
            industry: dailyPick.industry,
            score: dailyPick.score,
            reasonSummary: dailyPick.reasonSummary,
            sectorScore: dailyPick.sectorScore,
            lhbScore: dailyPick.lhbScore,
            trendScore: dailyPick.trendScore,
            newsScore: dailyPick.newsScore,
            analysis: dailyPick.analysis,
            generatedAt: dailyPick.generatedAt,
            performanceSincePick: performanceSincePick,
            pickPrice: pickPrice,
            currentPrice: currentPrice
        )
    }
}
