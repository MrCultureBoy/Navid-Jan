import SwiftUI

// MARK: - Carte de verre

/// La surface de base de l'app : un matériau translucide, un liseré lumineux
/// et une ombre douce. Utilisée partout pour l'unité visuelle.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = Metrics.cornerRadius
    var padding: CGFloat = Metrics.spacingM
    var tint: Color = .clear
    var strokeOpacity: Double = 0.18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(0.14))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(strokeOpacity),
                                Color.white.opacity(strokeOpacity * 0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.16), radius: 14, x: 0, y: 8)
    }
}

// MARK: - Styles de bouton

/// Un bouton qui s'enfonce : le retour tactile visuel le plus important de l'app.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}

/// Bouton principal, plein, en dégradé de thème.
struct PrimaryButtonStyle: ButtonStyle {
    var theme: QuestlyTheme
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.questHeadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background {
                RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                    .fill(theme.gradient)
                    .opacity(isEnabled ? 1 : 0.4)
            }
            .shadow(color: theme.accent.opacity(isEnabled ? 0.4 : 0), radius: 16, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}

/// Bouton secondaire, discret.
struct SoftButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.questCallout)
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                Capsule().fill(tint.opacity(0.14))
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}

// MARK: - Effets

/// Reflet qui balaie une surface — réservé aux moments forts (montée de niveau,
/// objet légendaire) pour qu'il garde sa valeur.
struct ShimmerModifier: ViewModifier {
    var active: Bool = true
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.55), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: phase * geo.size.width * 1.6)
                        .blendMode(.plusLighter)
                    }
                    .allowsHitTesting(false)
                    .mask(content)
                }
            }
            .onAppear {
                guard active else { return }
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer(active: Bool = true) -> some View {
        modifier(ShimmerModifier(active: active))
    }

    /// Halo coloré derrière un élément.
    func glow(_ color: Color, radius: CGFloat = 12, opacity: Double = 0.6) -> some View {
        shadow(color: color.opacity(opacity), radius: radius, x: 0, y: 0)
    }

    /// Applique une transformation seulement si la condition est vraie.
    @ViewBuilder
    func applyIf<Transformed: View>(_ condition: Bool, transform: (Self) -> Transformed) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: - État vide

struct EmptyStateView: View {
    let symbolName: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    @Environment(\.questlyTheme) private var theme

    var body: some View {
        VStack(spacing: Metrics.spacingM) {
            ZStack {
                Circle()
                    .fill(theme.softGradient)
                    .frame(width: 96, height: 96)
                Image(systemName: symbolName)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(theme.gradient)
            }

            Text(title)
                .font(.questHeadline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.questCallout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Metrics.spacingXL)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(SoftButtonStyle(tint: theme.accent))
                    .padding(.top, Metrics.spacingXS)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Metrics.spacingXL)
    }
}

// MARK: - Sélecteur segmenté

/// Segmenté maison : la pilule glisse au lieu de sauter, ce qui rend la
/// navigation entre vues du calendrier beaucoup plus fluide.
struct QuestlySegmentedPicker<Item: Hashable>: View {
    let items: [Item]
    let label: (Item) -> String
    @Binding var selection: Item

    @Environment(\.questlyTheme) private var theme
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                Button {
                    withAnimation(Motion.snappy) { selection = item }
                    Haptics.selection()
                } label: {
                    Text(label(item))
                        .font(.questCaption)
                        .foregroundStyle(selection == item ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if selection == item {
                                Capsule()
                                    .fill(theme.gradient)
                                    .matchedGeometryEffect(id: "segment", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background {
            Capsule().fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Compteur animé

/// Nombre qui s'incrémente visuellement : indispensable pour que gagner de l'XP
/// se ressente.
struct CountingNumber: View, Animatable {
    var value: Double
    var format: String = "%.0f"
    var font: Font = .questNumber(20)

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(String(format: format, value))
            .font(font)
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}
