import SwiftUI

// MARK: - Couleurs hexadécimales

extension Color {
    /// Construit une couleur à partir d'un hexadécimal « RRGGBB » ou « RRGGBBAA ».
    init(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double
        var alpha: Double = 1

        switch cleaned.count {
        case 8:
            red = Double((value & 0xFF00_0000) >> 24) / 255
            green = Double((value & 0x00FF_0000) >> 16) / 255
            blue = Double((value & 0x0000_FF00) >> 8) / 255
            alpha = Double(value & 0x0000_00FF) / 255
        case 6:
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
        default:
            red = 0.5
            green = 0.5
            blue = 0.5
        }
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

// MARK: - Palette

/// Couleurs partagées et petits utilitaires de teinte.
enum Palette {

    static let projectHexes = [
        "5E5CE6", "FF375F", "FF9F0A", "30D158", "64D2FF",
        "BF5AF2", "FF6B6B", "34D399", "F59E0B", "38BDF8"
    ]

    static let tagHexes = [
        "BF5AF2", "5E9BFF", "FF7AC6", "FFB020", "34D399",
        "A78BFA", "F472B6", "22D3EE", "FB923C", "4ADE80"
    ]

    /// Couleur stable dérivée du nom : deux projets identiques gardent la même
    /// teinte d'une installation à l'autre.
    static func randomProjectHex(seed: String) -> String {
        projectHexes[stableIndex(for: seed, count: projectHexes.count)]
    }

    static func randomTagHex(seed: String) -> String {
        tagHexes[stableIndex(for: seed, count: tagHexes.count)]
    }

    static func stableIndex(for seed: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 5381
        for byte in seed.lowercased().utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        return Int(hash % UInt64(count))
    }

    static func color(forHex hex: String) -> Color { Color(hex: hex) }
}

// MARK: - Métriques

/// Rythme visuel de l'app : une seule source pour les espacements et les rayons.
enum Metrics {
    static let cornerRadiusSmall: CGFloat = 12
    static let cornerRadius: CGFloat = 20
    static let cornerRadiusLarge: CGFloat = 28

    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 14
    static let spacingL: CGFloat = 20
    static let spacingXL: CGFloat = 32

    static let rowHeight: CGFloat = 60
    static let tabBarHeight: CGFloat = 64
    /// Hauteur d'une heure sur la timeline du calendrier.
    static let hourHeight: CGFloat = 64
}

// MARK: - Typographie

extension Font {
    static let questTitle = Font.system(size: 30, weight: .bold, design: .rounded)
    static let questHeadline = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let questBody = Font.system(size: 16, weight: .regular, design: .rounded)
    static let questCallout = Font.system(size: 14, weight: .medium, design: .rounded)
    static let questCaption = Font.system(size: 12, weight: .medium, design: .rounded)
    static let questMicro = Font.system(size: 10, weight: .semibold, design: .rounded)

    static func questNumber(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}

// MARK: - Animations

enum Motion {
    static let snappy = Animation.spring(response: 0.34, dampingFraction: 0.72)
    static let bouncy = Animation.spring(response: 0.42, dampingFraction: 0.6)
    static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.85)
    static let quick = Animation.easeOut(duration: 0.18)
    static let celebration = Animation.spring(response: 0.6, dampingFraction: 0.55)
}
