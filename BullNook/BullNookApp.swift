//
//  BullnookApp.swift
//  BullNook
//

import SwiftUI
import SwiftData

@main
struct BullNookApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Stock.self,
            DailyPick.self,
            HistoricalPick.self,
            KLineData.self,
            F10Metric.self,
            WatchlistItem.self,
            SectorData.self,
            DragonTigerData.self
        ])
    }
}
