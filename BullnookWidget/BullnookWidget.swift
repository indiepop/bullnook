import WidgetKit
import SwiftUI

struct BullnookEntry: TimelineEntry {
    let date: Date
    let pick: DailyPick?
}

struct BullnookProvider: TimelineProvider {
    func placeholder(in context: Context) -> BullnookEntry {
        BullnookEntry(date: Date(), pick: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (BullnookEntry) -> Void) {
        let entry = BullnookEntry(date: Date(), pick: samplePick())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BullnookEntry>) -> Void) {
        let entry = BullnookEntry(date: Date(), pick: samplePick())
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
        completion(timeline)
    }

    private func samplePick() -> DailyPick {
        DailyPick(
            id: "sample",
            date: "20260705",
            rank: 1,
            stockCode: "600519",
            stockName: "贵州茅台",
            industry: "白酒",
            score: 88.5,
            reasonSummary: "板块热度与走势共振",
            sectorScore: 90,
            lhbScore: 70,
            trendScore: 95,
            newsScore: 80,
            analysis: ""
        )
    }
}

struct BullnookWidgetEntryView: View {
    var entry: BullnookProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let pick = entry.pick {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("今日 Top 1")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("#\(pick.rank)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Text(pick.stockName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(pick.stockCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if family != .systemSmall {
                    Text(pick.reasonSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding()
            .widgetURL(URL(string: "bullnook://stock/\(pick.stockCode)"))
        } else {
            Text("今日推荐尚未生成")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct BullnookWidget: Widget {
    let kind: String = "BullnookWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BullnookProvider()) { entry in
            BullnookWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("牛角尖推荐")
        .description("展示今日 Top 1 精选股票")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
