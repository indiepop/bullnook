import SwiftUI

struct F10View: View {
    let f10: F10Metric?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let f10 = f10 {
                if !f10.industry.isEmpty || !f10.concepts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        if !f10.industry.isEmpty {
                            infoRow(title: "所属行业", value: f10.industry)
                        }

                        if !f10.concepts.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("所属概念")
                                    .foregroundStyle(Color.appTextSecondary)
                                FlowLayout(spacing: 8) {
                                    ForEach(f10.conceptList, id: \.self) { concept in
                                        Text(concept)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.appAccentGold.opacity(0.15))
                                            .foregroundStyle(Color.appAccentGold)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.appTertiary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("财务指标")
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)

                    metricRow(title: "市盈率 (PE)", value: formatValue(f10.pe, suffix: ""))
                    metricRow(title: "市净率 (PB)", value: formatValue(f10.pb, suffix: ""))
                    metricRow(title: "ROE", value: formatValue(f10.roe, suffix: "%"))
                    metricRow(title: "营收增速", value: formatValue(f10.revenueGrowth, suffix: "%"))
                    metricRow(title: "净利润增速", value: formatValue(f10.profitGrowth, suffix: "%"))
                    metricRow(title: "总市值", value: formatMarketCap(f10.totalMarketCap))
                    metricRow(title: "流通市值", value: formatMarketCap(f10.circulatingMarketCap))
                }

                if !f10.source.isEmpty {
                    HStack {
                        Spacer()
                        Text("数据来源: \(f10.source == "search" ? "搜索引擎" : "东方财富")")
                            .font(.caption2)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.appTextSecondary)
                    Text("F10 数据暂不可用")
                        .foregroundStyle(Color.appTextSecondary)
                    Text("数据来自公开接口或搜索引擎，可能存在延迟。")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(Color.appTextSecondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .foregroundStyle(Color.appTextPrimary)
                .fontWeight(.medium)
                .lineLimit(nil)
            Spacer()
        }
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color.appTextSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(Color.appTextPrimary)
                .fontWeight(.medium)
        }
    }

    private func formatValue(_ value: Double, suffix: String) -> String {
        guard value != 0 else { return "--" }
        return String(format: "%.2f%@", value, suffix)
    }

    private func formatMarketCap(_ value: Double) -> String {
        guard value != 0 else { return "--" }
        if value >= 1_000_000_000_000 { return String(format: "%.2f 万亿", value / 1_000_000_000_000) }
        if value >= 100_000_000 { return String(format: "%.2f 亿", value / 100_000_000) }
        return String(format: "%.0f", value)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    private struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}
