import SwiftUI
import QuestlyKit

// MARK: - Thème

/// Une ambiance visuelle complète. Les surfaces restent des matériaux système
/// (donc lisibles en clair comme en sombre) ; le thème pilote les accents, les
/// dégradés et l'atmosphère de fond.
struct QuestlyTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let symbolName: String
    let accentHex: String
    let secondaryHex: String
    let tertiaryHex: String
    let auraTopHex: String
    let auraBottomHex: String
    /// Prix indicatif affiché dans la boutique (0 = offert).
    let unlockItemID: String?

    var accent: Color { Color(hex: accentHex) }
    var secondary: Color { Color(hex: secondaryHex) }
    var tertiary: Color { Color(hex: tertiaryHex) }
    var auraTop: Color { Color(hex: auraTopHex) }
    var auraBottom: Color { Color(hex: auraBottomHex) }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [accent, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var softGradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.22), secondary.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var ringGradient: AngularGradient {
        AngularGradient(
            colors: [accent, secondary, tertiary, accent],
            center: .center
        )
    }
}

enum ThemeCatalog {

    static let all: [QuestlyTheme] = [
        QuestlyTheme(
            id: "nebula", name: "Nébuleuse", symbolName: "sparkles",
            accentHex: "7C5CFF", secondaryHex: "C77DFF", tertiaryHex: "4CC9F0",
            auraTopHex: "7C5CFF", auraBottomHex: "2D1B69", unlockItemID: nil
        ),
        QuestlyTheme(
            id: "aurora", name: "Aurore", symbolName: "sunrise.fill",
            accentHex: "FF6B9D", secondaryHex: "FFA45B", tertiaryHex: "FFD93D",
            auraTopHex: "FF6B9D", auraBottomHex: "6B2D5C", unlockItemID: "theme.aurora"
        ),
        QuestlyTheme(
            id: "forest", name: "Sylve", symbolName: "leaf.fill",
            accentHex: "2DD4A7", secondaryHex: "60D394", tertiaryHex: "AAF683",
            auraTopHex: "2DD4A7", auraBottomHex: "134E4A", unlockItemID: "theme.forest"
        ),
        QuestlyTheme(
            id: "ocean", name: "Abysse", symbolName: "water.waves",
            accentHex: "3B82F6", secondaryHex: "22D3EE", tertiaryHex: "818CF8",
            auraTopHex: "3B82F6", auraBottomHex: "0C2D5A", unlockItemID: "theme.ocean"
        ),
        QuestlyTheme(
            id: "ember", name: "Braise", symbolName: "flame.fill",
            accentHex: "FB7185", secondaryHex: "F59E0B", tertiaryHex: "FCD34D",
            auraTopHex: "FB7185", auraBottomHex: "4C1D1D", unlockItemID: "theme.ember"
        ),
        QuestlyTheme(
            id: "candy", name: "Guimauve", symbolName: "birthday.cake.fill",
            accentHex: "F472B6", secondaryHex: "A78BFA", tertiaryHex: "7DD3FC",
            auraTopHex: "F472B6", auraBottomHex: "4A2545", unlockItemID: "theme.candy"
        ),
        QuestlyTheme(
            id: "ink", name: "Encre", symbolName: "circle.lefthalf.filled",
            accentHex: "9CA3AF", secondaryHex: "6B7280", tertiaryHex: "D1D5DB",
            auraTopHex: "6B7280", auraBottomHex: "1F2937", unlockItemID: "theme.ink"
        ),
        QuestlyTheme(
            id: "gold", name: "Âge d'or", symbolName: "crown.fill",
            accentHex: "F0B429", secondaryHex: "FCD34D", tertiaryHex: "FDE68A",
            auraTopHex: "F0B429", auraBottomHex: "3A2A08", unlockItemID: "theme.gold"
        )
    ]

    static let `default` = all[0]

    static func theme(id: String) -> QuestlyTheme {
        all.first { $0.id == id } ?? `default`
    }
}

// MARK: - Gestionnaire

/// Détient le thème courant et le partage à toute l'app.
@Observable
final class ThemeManager {
    var current: QuestlyTheme

    init(id: String = ThemeCatalog.default.id) {
        self.current = ThemeCatalog.theme(id: id)
    }

    func select(id: String) {
        withAnimation(Motion.gentle) {
            current = ThemeCatalog.theme(id: id)
        }
    }

    /// Un thème est disponible s'il est offert ou déjà acheté.
    func isUnlocked(_ theme: QuestlyTheme, ownedItems: [String]) -> Bool {
        guard let requirement = theme.unlockItemID else { return true }
        return ownedItems.contains(requirement)
    }
}

// MARK: - Fond animé

/// Fond « aurore » : deux halos qui respirent lentement derrière l'interface.
/// C'est ce qui donne la sensation de profondeur sans coûter cher à dessiner.
struct AuroraBackground: View {
    let theme: QuestlyTheme
    var animated: Bool = true

    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemBackground)

                Circle()
                    .fill(theme.auraTop.opacity(0.30))
                    .frame(width: geo.size.width * 1.1)
                    .blur(radius: 90)
                    .offset(
                        x: -geo.size.width * 0.28 + phase * 22,
                        y: -geo.size.height * 0.30 + phase * 14
                    )

                Circle()
                    .fill(theme.auraBottom.opacity(0.34))
                    .frame(width: geo.size.width * 1.0)
                    .blur(radius: 100)
                    .offset(
                        x: geo.size.width * 0.32 - phase * 18,
                        y: geo.size.height * 0.34 - phase * 20
                    )

                Circle()
                    .fill(theme.tertiary.opacity(0.16))
                    .frame(width: geo.size.width * 0.7)
                    .blur(radius: 80)
                    .offset(x: phase * 30, y: geo.size.height * 0.05 + phase * 12)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }
}

// MARK: - Clés d'environnement

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = ThemeCatalog.default
}

extension EnvironmentValues {
    var questlyTheme: QuestlyTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
