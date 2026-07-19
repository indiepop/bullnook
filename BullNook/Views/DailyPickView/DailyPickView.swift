import SwiftUI
import SwiftData

struct DailyPickView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel: DailyPickViewModel?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    content(viewModel: viewModel)
                } else {
                    LoadingView(message: "加载中...")
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("今日精选")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color.appAccentGold)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = DailyPickViewModel(context: context)
                }
                Task {
                    await viewModel?.loadRealTimeQuotes()
                }
                if KeychainManager.load() == nil {
                    showSettings = true
                }
            }
        }
    }

    @ViewBuilder
    private func content(viewModel: DailyPickViewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection(viewModel: viewModel)

                if viewModel.hasRefreshedToday {
                    refreshedBanner()
                }

                sectorSummarySection(viewModel: viewModel)

                if viewModel.isLoading && viewModel.picks.isEmpty {
                    LoadingView(message: "正在生成今日推荐...")
                        .padding(.top, 40)
                } else if viewModel.picks.isEmpty {
                    emptyState(viewModel: viewModel)
                } else {
                    picksList(viewModel: viewModel)
                }

                DisclaimerView()
                    .padding(.top, 8)
            }
            .padding()
        }
        .refreshable {
            await viewModel.refreshPicks()
        }
    }

    private func headerSection(viewModel: DailyPickViewModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(formattedPickDate(viewModel.currentPickDate))精选")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color.appTextPrimary)
            Text("基于板块、龙虎榜、走势、消息链综合分析")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectorSummarySection(viewModel: DailyPickViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.pie")
                    .foregroundStyle(Color.appAccentGold)
                Text("昨日板块总体")
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
            }

            Text(viewModel.sectorSummary)
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            if !viewModel.hasSectorData {
                Button {
                    Task {
                        await viewModel.refreshSectorSummary()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(viewModel.isRefreshingSectorSummary ? 360 : 0))
                            .animation(
                                viewModel.isRefreshingSectorSummary
                                    ? .linear(duration: 1).repeatForever(autoreverses: false)
                                    : .default,
                                value: viewModel.isRefreshingSectorSummary
                            )
                        Text(viewModel.isRefreshingSectorSummary ? "更新中..." : "更新板块数据")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccentGold)
                .padding(.top, 4)
                .disabled(viewModel.isRefreshingSectorSummary)
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func refreshedBanner() -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.appUp)
            Text("今日推荐已刷新")
                .font(.subheadline)
                .foregroundStyle(Color.appTextPrimary)
            Spacer()
        }
        .padding()
        .background(Color.appUp.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func picksList(viewModel: DailyPickViewModel) -> some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.picks) { pick in
                NavigationLink(value: pick) {
                    PickCard(pick: pick)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationDestination(for: DailyPick.self) { pick in
            StockDetailView(pick: pick)
        }
    }

    private func emptyState(viewModel: DailyPickViewModel) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundStyle(Color.appTextSecondary)

            if let error = viewModel.errorMessage {
                Text("今日推荐生成失败")
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)

                Button("重试") {
                    Task {
                        await viewModel.refreshPicks()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appAccentGold)
            } else {
                Text("今日推荐正在生成中")
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)
                Text("首次使用或数据过期时会自动抓取公开数据并计算评分，请稍候。")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 60)
    }

    private func formattedPickDate(_ dateString: String) -> String {
        guard let date = DateFormatter.yyyyMMdd.date(from: dateString) else {
            return dateString
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}
