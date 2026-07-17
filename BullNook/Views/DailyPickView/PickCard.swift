import SwiftUI

struct PickCard: View {
    let pick: DailyPick

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.appAccentGold.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Text("\(pick.rank)")
                        .font(.headline)
                        .foregroundStyle(Color.appAccentGold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(pick.stockName)
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)
                    Text(pick.stockCode)
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2f", pick.currentPrice))
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)
                    Text(Color.formatChangePercent(pick.changePercent))
                        .font(.caption)
                        .foregroundStyle(pick.changePercent >= 0 ? Color.appUp : Color.appDown)
                }
            }

            HStack {
                Text(pick.industry)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appTertiary)
                    .foregroundStyle(Color.appTextSecondary)
                    .clipShape(Capsule())

                Spacer()

                Text("综合得分 \(String(format: "%.1f", pick.score))")
                    .font(.caption)
                    .foregroundStyle(Color.appAccentGold)
            }

            Text(pick.reasonSummary)
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .lineLimit(2)
        }
        .padding()
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
