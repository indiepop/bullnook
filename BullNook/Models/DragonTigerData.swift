import Foundation
import SwiftData

@Model
class DragonTigerData {
    @Attribute(.unique) var id: String
    var symbol: String
    var name: String
    var date: String
    var netBuyAmount: Double
    var buySeats: String
    var sellSeats: String

    init(id: String, symbol: String, name: String, date: String, netBuyAmount: Double = 0, buySeats: String = "", sellSeats: String = "") {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.date = date
        self.netBuyAmount = netBuyAmount
        self.buySeats = buySeats
        self.sellSeats = sellSeats
    }
}
