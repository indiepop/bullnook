import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel: WatchlistViewModel?

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
            .navigationTitle("自选股")
            .onAppear {
                if viewModel == nil {
                    viewModel = WatchlistViewModel(context: context)
                }
                viewModel?.loadItems()
                viewModel?.startAutoRefresh()
            }
            .onDisappear {
                viewModel?.stopAutoRefresh()
            }
        }
    }

    @ViewBuilder
    private func content(viewModel: WatchlistViewModel) -> some View {
        if viewModel.items.isEmpty {
            emptyState
        } else {
            listView(viewModel: viewModel)
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

    private func listView(viewModel: WatchlistViewModel) -> some View {
        List {
            Section {
                if let lastUpdated = viewModel.lastUpdated {
                    Text("最后更新：\(lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }

            ForEach(viewModel.items) { item in
                WatchlistRow(item: item)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.remove(item: viewModel.items[index])
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refreshQuotes()
        }
    }
}
