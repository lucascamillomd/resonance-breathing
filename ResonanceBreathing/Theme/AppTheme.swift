import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.04, green: 0.055, blue: 0.1)
    static let petalBlue = Color(red: 0.29, green: 0.565, blue: 0.85)
    static let petalTeal = Color(red: 0.176, green: 0.832, blue: 0.749)
    static let coherenceGlow = Color(red: 1.0, green: 0.95, blue: 0.8)
    static let primaryText = Color(red: 0.878, green: 0.906, blue: 1.0)
    static let secondaryText = Color(red: 0.6, green: 0.65, blue: 0.75)
    static let chartLine = Color(red: 0.176, green: 0.832, blue: 0.749)
    static let coherenceActive = Color(red: 0.176, green: 0.832, blue: 0.749)
    static let coherenceInactive = Color(red: 0.3, green: 0.35, blue: 0.4)

    static let petalGradient = LinearGradient(
        colors: [petalBlue, petalTeal],
        startPoint: .top,
        endPoint: .bottom
    )
}
