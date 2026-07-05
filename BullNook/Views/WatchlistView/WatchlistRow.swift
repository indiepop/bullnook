import SwiftUI

struct WatchlistRow: View {
    let item: WatchlistItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.stockName)
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)
                Text("\(item.stockCode) · \(item.industry)")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f", item.currentPrice))
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)
                Text(String(format: "%.2f%%", item.changePercent))
                    .font(.caption)
                    .foregroundStyle(item.changePercent >= 0 ? Color.appUp : Color.appDown)
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
