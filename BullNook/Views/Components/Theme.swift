import SwiftUI

extension Color {
    static let appBackground = Color(hex: "#0F172A")
    static let appCardBackground = Color(hex: "#1E293B")
    static let appTertiary = Color(hex: "#334155")
    static let appTextPrimary = Color(hex: "#F8FAFC")
    static let appTextSecondary = Color(hex: "#CBD5E1")
    static let appAccentGold = Color(hex: "#F59E0B")
    static let appUp = Color(hex: "#EF4444")
    static let appDown = Color(hex: "#10B981")
    static let appNeutral = Color(hex: "#64748B")

    /// 按 A 股习惯格式化涨跌幅：涨用 "+x.xx%"，跌用 "-x.xx%"
    static func formatChangePercent(_ value: Double) -> String {
        if value > 0 {
            return String(format: "+%.2f%%", value)
        } else if value < 0 {
            return String(format: "%.2f%%", value)
        } else {
            return "0.00%"
        }
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
