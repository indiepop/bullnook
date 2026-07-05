import Foundation
import SwiftData

@Model
class SectorData {
    @Attribute(.unique) var id: String
    var name: String
    var date: String
    var changePercent: Double
    var netInflow: Double
    var limitUpCount: Int

    init(id: String, name: String, date: String, changePercent: Double = 0, netInflow: Double = 0, limitUpCount: Int = 0) {
        self.id = id
        self.name = name
        self.date = date
        self.changePercent = changePercent
        self.netInflow = netInflow
        self.limitUpCount = limitUpCount
    }
}
