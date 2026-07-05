import SwiftUI
import SwiftData

struct StockDetailView: View {
    @Environment(\.modelContext) private var context
    let pick: DailyPick
    @State private var viewModel: StockDetailViewModel?
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                periodSelector

                if let viewModel = viewModel {
                    tabContent(viewModel: viewModel)
                } else {
                    LoadingView(message: "加载详情中...")
                }
            }
            .padding()
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(pick.stockName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let viewModel = viewModel {
                    Button {
                        viewModel.toggleWatchlist()
                    } label: {
                        Image(systemName: viewModel.isInWatchlist ? "star.fill" : "star")
                            .foregroundStyle(Color.appAccentGold)
                    }
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
                    Text(String(format: "%.2f%%", pick.changePercent))
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
                    set: { viewModel.selectedPeriod = $0 }
                )) {
                    ForEach(KLinePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.selectedPeriod) { _, newValue in
                    Task {
                        await viewModel.switchPeriod(newValue)
                    }
                }

                if viewModel.kline.isEmpty {
                    Text("K线数据暂不可用")
                        .foregroundStyle(Color.appTextSecondary)
                        .padding()
                } else {
                    KLineChartView(data: viewModel.kline)
                }
            }
            .padding()
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if selectedTab == 1 {
            F10View(f10: viewModel.f10, marketCap: 0)
        } else {
            AnalysisView(pick: pick)
        }
    }
}
