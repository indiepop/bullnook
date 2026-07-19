import SwiftUI
import SwiftData

struct StockDetailView: View {
    let pick: DailyPick
    @Environment(\.modelContext) private var context
    @State private var viewModel: StockDetailViewModel?
    @State private var selectedTab = 0
    @State private var isInWatchlist = false

    var body: some View {
        Group {
            if let viewModel = viewModel {
                content(viewModel: viewModel)
            } else {
                LoadingView(message: "加载中...")
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(pick.stockName)
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    print("[Watchlist] star tapped for \(pick.stockCode), current=\(isInWatchlist)")
                    toggleWatchlist()
                    print("[Watchlist] after toggle=\(isInWatchlist)")
                } label: {
                    Image(systemName: isInWatchlist ? "star.fill" : "star")
                        .foregroundStyle(Color.appAccentGold)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = StockDetailViewModel(pick: pick, context: context)
            }
            Task {
                await viewModel?.loadData()
            }
            refreshWatchlistStatus()
        }
    }

    private func refreshWatchlistStatus() {
        let code = pick.stockCode
        let descriptor = FetchDescriptor<WatchlistItem>(predicate: #Predicate { $0.stockCode == code })
        let count = (try? context.fetchCount(descriptor)) ?? 0
        isInWatchlist = count > 0
        print("[Watchlist] StockDetail refresh status \(pick.stockCode): count=\(count), isInWatchlist=\(isInWatchlist), context=\(ObjectIdentifier(context))")
    }

    private func toggleWatchlist() {
        // 不管当前状态如何，先删除该股票所有历史自选记录，避免唯一约束冲突
        let code = pick.stockCode
        let descriptor = FetchDescriptor<WatchlistItem>(predicate: #Predicate { $0.stockCode == code })
        let existing = (try? context.fetch(descriptor)) ?? []
        print("[Watchlist] StockDetail toggle found \(existing.count) existing items for \(pick.stockCode)")
        for item in existing {
            context.delete(item)
        }

        if !isInWatchlist {
            let item = WatchlistItem(
                id: UUID().uuidString,
                stockCode: pick.stockCode,
                stockName: pick.stockName,
                industry: pick.industry
            )
            context.insert(item)
            print("[Watchlist] StockDetail inserted new item \(item.id) for \(pick.stockCode)")
        }

        do {
            try context.save()
            print("[Watchlist] StockDetail context.save() succeeded for \(pick.stockCode)")
        } catch {
            print("[Watchlist] StockDetail context.save() failed: \(error)")
        }

        // 保存后立即重新查询，确保 UI 状态以数据库为准
        refreshWatchlistStatus()

        // 再次查询全部验证
        let allDescriptor = FetchDescriptor<WatchlistItem>()
        let all = (try? context.fetch(allDescriptor)) ?? []
        print("[Watchlist] StockDetail all watchlist items after toggle: \(all.map { "\($0.stockCode)(\($0.id))" })")
    }

    private func content(viewModel: StockDetailViewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                periodSelector

                tabContent(viewModel: viewModel)
            }
            .padding()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pick.stockName)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.appTextPrimary)
                    Text("\(pick.stockCode) · \(pick.industry)")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.2f", pick.currentPrice))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.appTextPrimary)
                    Text(Color.formatChangePercent(pick.changePercent))
                        .font(.subheadline)
                        .foregroundStyle(pick.changePercent >= 0 ? Color.appUp : Color.appDown)
                }
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var periodSelector: some View {
        Picker("周期", selection: $selectedTab) {
            Text("走势").tag(0)
            Text("F10").tag(1)
            Text("分析").tag(2)
        }
        .pickerStyle(.segmented)
        .colorMultiply(Color.appAccentGold)
    }

    @ViewBuilder
    private func tabContent(viewModel: StockDetailViewModel) -> some View {
        if selectedTab == 0 {
            VStack(spacing: 12) {
                Picker("K线周期", selection: Binding(
                    get: { viewModel.selectedPeriod },
                    set: { newPeriod in
                        Task {
                            await viewModel.switchPeriod(newPeriod)
                        }
                    }
                )) {
                    ForEach(KLinePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)

                if viewModel.kline.isEmpty {
                    Text("K线数据暂不可用")
                        .foregroundStyle(Color.appTextSecondary)
                        .padding()
                } else {
                    KLineChartView(data: viewModel.kline, period: viewModel.selectedPeriod)
                        .id("kline-\(viewModel.selectedPeriod.rawValue)-\(viewModel.kline.count)")
                }
            }
            .padding()
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if selectedTab == 1 {
            F10View(f10: viewModel.f10)
        } else {
            AnalysisView(pick: pick, isLLMConfigured: viewModel.isLLMConfigured, isAnalysisLoading: viewModel.isAnalysisLoading)
        }
    }
}
