import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var context
    @State private var items: [WatchlistItem] = []
    @State private var lastUpdated: Date?
    @State private var timer: Timer?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    listView
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("自选股")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                print("[Watchlist] WatchlistView onAppear, context=\(ObjectIdentifier(context))")
                loadItems()
                startAutoRefresh()
            }
            .onDisappear {
                stopAutoRefresh()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star")
                .font(.system(size: 48))
                .foregroundStyle(Color.appTextSecondary)
            Text("暂无自选股")
                .font(.headline)
                .foregroundStyle(Color.appTextPrimary)
            Text("从每日推荐中添加股票，追踪自选行情")
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding(.top, 80)
    }

    private var listView: some View {
        List {
            Section {
                if let lastUpdated = lastUpdated {
                    Text("最后更新：\(lastUpdated.formatted(date: .numeric, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }

            ForEach(items) { item in
                WatchlistRow(item: item)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    context.delete(items[index])
                }
                do {
                    try context.save()
                    print("[Watchlist] delete saved")
                } catch {
                    print("[Watchlist] delete save failed: \(error)")
                }
                loadItems()
            }
        }
        .listStyle(.plain)
        .refreshable {
            loadItems()
            await refreshQuotes()
        }
    }

    private func loadItems() {
        let descriptor = FetchDescriptor<WatchlistItem>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        let fetched = (try? context.fetch(descriptor)) ?? []
        items = fetched
        print("[Watchlist] WatchlistView loadItems: \(fetched.count) items, context=\(ObjectIdentifier(context)), items=\(fetched.map { "\($0.stockCode)(\($0.id))" })")
    }

    private func startAutoRefresh() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in
                await refreshQuotes()
            }
        }
        Task {
            await refreshQuotes()
        }
    }

    private func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    private func refreshQuotes() async {
        guard !items.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        let symbols = items.map { codeToSymbol($0.stockCode) }
        let quotes = await SinaAPI.realTimeQuotes(symbols: symbols)
        let quoteMap = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })

        for item in items {
            if let quote = quoteMap[codeToSymbol(item.stockCode)] {
                item.currentPrice = quote.currentPrice
                item.changePercent = quote.changePercent
                item.lastUpdated = Date()
            }
        }

        do {
            try context.save()
        } catch {
            print("[Watchlist] refresh quotes save failed: \(error)")
        }
        lastUpdated = Date()
    }
}

private func codeToSymbol(_ code: String) -> String {
    if code.hasPrefix("6") { return "sh\(code)" }
    if code.hasPrefix("0") || code.hasPrefix("3") { return "sz\(code)" }
    return code
}
