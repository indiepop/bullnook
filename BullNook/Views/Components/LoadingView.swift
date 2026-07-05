import SwiftUI

struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Color.appAccentGold)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding()
    }
}
