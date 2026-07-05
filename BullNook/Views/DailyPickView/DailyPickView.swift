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
            }
        }
    }

    @ViewBuilder
    private func content(viewModel: DailyPickViewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection(viewModel: viewModel)

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
            Text("今日 5 只精选")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(Color.appTextPrimary)
            Text("基于板块、龙虎榜、走势、消息链综合分析")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            Text("今日推荐正在生成中")
                .font(.headline)
                .foregroundStyle(Color.appTextPrimary)
            Text("首次使用或数据过期时会重新抓取公开数据并计算评分。")
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
            Button("立即生成") {
                Task {
                    await viewModel.refreshPicks()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appAccentGold)
        }
        .padding(.top, 60)
    }
}
