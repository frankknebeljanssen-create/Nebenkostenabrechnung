import SwiftUI

struct AppTheme {
    static let accent = Color(hex: "185FA5")
    static let success = Color(hex: "0F6E56")
    static let warning = Color(hex: "854F0B")
    static let error = Color(hex: "A32D2D")

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(hex: "8E8E93")
    static let border = Color(hex: "E5E7EB")
    static let cardBg = Color(.systemBackground)
    static let screenBg = Color(.secondarySystemBackground)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        r = Double((int >> 16) & 0xFF) / 255.0
        g = Double((int >> 8) & 0xFF) / 255.0
        b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
