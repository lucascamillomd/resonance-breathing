import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.03, green: 0.05, blue: 0.09)
    static let backgroundBase = Color(red: 0.03, green: 0.05, blue: 0.09)
    static let backgroundTop = Color(red: 0.11, green: 0.17, blue: 0.26)
    static let backgroundBottom = Color(red: 0.02, green: 0.05, blue: 0.11)
    static let cardFill = Color.white.opacity(0.09)
    static let cardStroke = Color.white.opacity(0.12)
    static let tint = Color(red: 0.45, green: 0.76, blue: 0.98)
    static let accent = Color(red: 0.33, green: 0.88, blue: 0.75)
    static let warmAccent = Color(red: 0.97, green: 0.84, blue: 0.62)
    static let danger = Color(red: 0.98, green: 0.41, blue: 0.44)
    static let success = Color(red: 0.45, green: 0.88, blue: 0.63)

    static let petalBlue = Color(red: 0.39, green: 0.66, blue: 0.96)
    static let petalTeal = Color(red: 0.29, green: 0.9, blue: 0.8)
    static let coherenceGlow = Color(red: 1.0, green: 0.95, blue: 0.8)
    static let primaryText = Color.white.opacity(0.96)
    static let secondaryText = Color.white.opacity(0.7)
    static let tertiaryText = Color.white.opacity(0.45)
    static let chartLine = Color(red: 0.45, green: 0.88, blue: 0.8)
    static let coherenceActive = Color(red: 0.38, green: 0.9, blue: 0.77)
    static let coherenceInactive = Color.white.opacity(0.2)

    static let backgroundGradient = LinearGradient(
        colors: [backgroundTop, backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let petalGradient = LinearGradient(
        colors: [petalBlue, petalTeal],
        startPoint: .top,
        endPoint: .bottom
    )

    static let buttonGradient = LinearGradient(
        colors: [tint, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct MindfulCardModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(AppTheme.cardStroke, lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.22), radius: 14, y: 8)
    }
}

extension View {
    func mindfulCard(cornerRadius: CGFloat = 22) -> some View {
        modifier(MindfulCardModifier(cornerRadius: cornerRadius))
    }
}
