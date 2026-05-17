import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }

    static let appBackground         = Color(hex: "f7f9fb")
    static let appCard               = Color.white
    static let appSecondary          = Color(hex: "505f76")
    static let appSecondaryContainer = Color(hex: "d0e1fb")
    static let appOnSecContainer     = Color(hex: "54647a")
    static let appSurfaceHigh        = Color(hex: "e6e8ea")
    static let appSurfaceLow         = Color(hex: "f2f4f6")
    static let appSurfaceContainer   = Color(hex: "eceef0")
    static let appSurfaceDim         = Color(hex: "d8dadc")
    static let appOutlineVariant     = Color(hex: "c5c6cd")
    static let appOutline            = Color(hex: "75777e")
    static let appOnSurfaceVariant   = Color(hex: "44474d")
    static let appOnSurface          = Color(hex: "191c1e")
    static let appError              = Color(hex: "ba1a1a")
    static let appVerifiedBg         = Color(hex: "a2eeff").opacity(0.45)
    static let appVerifiedFg         = Color(hex: "004e5a")
}

struct InitialsAvatar: View {
    let name: String
    var size: CGFloat = 80

    private var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return (String(words[0].prefix(1)) + String(words[1].prefix(1))).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            Circle().fill(Color.appSurfaceHigh)
            Text(initials)
                .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appOnSurface)
        }
        .frame(width: size, height: size)
    }
}
