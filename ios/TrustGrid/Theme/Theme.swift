import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - TrustGrid Theme Colors
struct ThemeColors {
    static let primary = Color(hex: "#000000")
    static let onPrimary = Color(hex: "#ffffff")
    static let secondary = Color(hex: "#5f5e5e")
    
    static let background = Color(hex: "#f7f9fb")
    static let onBackground = Color(hex: "#191c1e")
    
    static let surfaceDim = Color(hex: "#d8dadc")
    static let surfaceContainerLowest = Color(hex: "#ffffff")
    static let surfaceContainerLow = Color(hex: "#f2f4f6")
    static let surfaceContainerHigh = Color(hex: "#e6e8ea")
    
    static let onSurface = Color(hex: "#191c1e")
    static let onSurfaceVariant = Color(hex: "#44474d")
}

// MARK: - TrustGrid Typography
extension Font {
    /// Note: To use the custom font, add SpaceGrotesk.ttf to your project,
    /// include it in your Info.plist under "Fonts provided by application",
    /// and change these to use `.custom("SpaceGrotesk-Bold", size: size)`
    
    static var headlineXL: Font {
        // Space Grotesk Bold 24
        .system(size: 24, weight: .bold, design: .default)
    }
    
    static var labelLG: Font {
        // Space Grotesk Regular 18
        .system(size: 18, weight: .regular, design: .default)
    }
    
    static var bodyLG: Font {
        // Space Grotesk Medium 18
        .system(size: 18, weight: .medium, design: .default)
    }
    
    static var bodyMD: Font {
        // Space Grotesk Regular 16
        .system(size: 16, weight: .regular, design: .default)
    }
    
    static var buttonText: Font {
        // Space Grotesk Bold 24
        .system(size: 24, weight: .bold, design: .default)
    }
}
