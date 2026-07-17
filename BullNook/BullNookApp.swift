//
//  BullnookApp.swift
//  BullNook
//

import SwiftUI
import SwiftData

@main
struct BullNookApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            Stock.self,
            DailyPick.self,
            HistoricalPick.self,
            KLineData.self,
            F10Metric.self,
            WatchlistItem.self,
            SectorData.self,
            DragonTigerData.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
            print("[SwiftData] ModelContainer loaded successfully")
        } catch {
            // 如果迁移失败（例如新增必填字段无默认值），删除旧 store 后重新创建，避免整个持久化层不可用
            print("[SwiftData] ModelContainer load failed: \(error). Attempting to reset store.")
            let url = configuration.url
            do {
                try FileManager.default.removeItem(at: url)
                print("[SwiftData] Removed corrupted store at \(url)")
            } catch {
                print("[SwiftData] Failed to remove store: \(error)")
            }
            container = try! ModelContainer(for: schema, configurations: [configuration])
            print("[SwiftData] ModelContainer recreated after reset")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
