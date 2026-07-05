import SwiftUI

struct DisclaimerView: View {
    var body: some View {
        Text("本应用所有推荐和分析仅供参考，不构成投资建议。股市有风险，投资需谨慎。")
            .font(.caption)
            .foregroundStyle(Color.appTextSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.vertical, 8)
    }
}
