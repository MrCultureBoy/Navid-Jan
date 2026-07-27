import SwiftUI
import QuestlyKit

// MARK: - Contenu célébré

/// Un évènement à célébrer. Les célébrations sont mises en file : on ne
/// superpose jamais deux fanfares.
enum Celebration: Identifiable, Equatable {
    case levelUp(level: Int, rank: Rank?)
    case achievement(AchievementDefinition)
    case streakMilestone(days: Int)
    case questCompleted(title: String)
    case attributeLevelUp(area: LifeArea, level: Int)
    case loot([LootDrop])

    var id: String {
        switch self {
        case .levelUp(let level, _): return "level.\(level)"
        case .achievement(let definition): return "achievement.\(definition.id)"
        case .streakMilestone(let days): return "streak.\(days)"
        case .questCompleted(let title): return "quest.\(title)"
        case .attributeLevelUp(let area, let level): return "attr.\(area.rawValue).\(level)"
        case .loot(let drops): return "loot." + drops.map(\.id).joined(separator: "-")
        }
    }

    var title: String {
        switch self {
        case .levelUp(let level, _): return "Niveau \(level) !"
        case .achievement(let definition): return definition.title
        case .streakMilestone(let days): return "\(days) jours d'affilée"
        case .questCompleted: return "Quête du jour bouclée"
        case .attributeLevelUp(let area, let level): return "\(area.label) niveau \(level)"
        case .loot: return "Butin !"
        }
    }

    var message: String {
        switch self {
        case .levelUp(_, let rank):
            if let rank { return "Nouveau rang : \(rank.title)" }
            return "Ta légende s'écrit."
        case .achievement(let definition):
            return definition.detail
        case .streakMilestone(let days):
            return "Multiplicateur ×\(String(format: "%.2f", XPEngine.streakMultiplier(days: days))) sur chaque quête."
        case .questCompleted(let title):
            return title
        case .attributeLevelUp(let area, _):
            return area.subtitle
        case .loot(let drops):
            return drops.map(\.name).joined(separator: " · ")
        }
    }

    var symbolName: String {
        switch self {
        case .levelUp(_, let rank): return rank?.symbolName ?? "arrow.up.circle.fill"
        case .achievement(let definition): return definition.symbolName
        case .streakMilestone: return "flame.fill"
        case .questCompleted: return "scroll.fill"
        case .attributeLevelUp(let area, _): return area.symbolName
        case .loot: return "shippingbox.fill"
        }
    }

    var accentHex: String {
        switch self {
        case .levelUp(_, let rank): return rank?.hex ?? "FFD60A"
        case .achievement(let definition): return definition.rarity.hex
        case .streakMilestone: return "FF7A00"
        case .questCompleted: return "5E5CE6"
        case .attributeLevelUp(let area, _): return area.hex
        case .loot(let drops): return (drops.map(\.rarity).max() ?? .common).hex
        }
    }

    var rarity: Rarity? {
        switch self {
        case .achievement(let definition): return definition.rarity
        case .loot(let drops): return drops.map(\.rarity).max()
        default: return nil
        }
    }

    /// Les grands moments méritent des confettis ; les petits, une simple carte.
    var deservesConfetti: Bool {
        switch self {
        case .levelUp, .streakMilestone: return true
        case .achievement(let definition): return definition.rarity >= .rare
        case .loot(let drops): return (drops.map(\.rarity).max() ?? .common) >= .epic
        default: return false
        }
    }
}

// MARK: - Superposition

/// La fanfare : carte centrale, rayons, confettis, disparition automatique.
struct CelebrationOverlay: View {
    let celebration: Celebration
    var confettiEnabled: Bool = true
    let onDismiss: () -> Void

    @Environment(\.questlyTheme) private var theme
    @State private var appeared = false

    private var accent: Color { Color(hex: celebration.accentHex) }

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.45 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            if celebration.deservesConfetti {
                RadiantBurst(color: accent)
                    .frame(width: 400, height: 400)
                    .opacity(appeared ? 1 : 0)
            }

            card
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)

            if confettiEnabled && celebration.deservesConfetti {
                ConfettiView(pieceCount: 110, duration: 2.8)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            withAnimation(Motion.celebration) { appeared = true }
            Haptics.play(hapticEvent)
            // Disparition automatique : on ne bloque jamais l'utilisateur.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) { dismiss() }
        }
    }

    private var hapticEvent: Haptics.Event {
        switch celebration {
        case .levelUp: return .levelUp
        case .achievement: return .success
        case .streakMilestone: return .heavy
        default: return .questComplete
        }
    }

    private var card: some View {
        VStack(spacing: Metrics.spacingM) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(0.55), accent.opacity(0.05)],
                            center: .center,
                            startRadius: 4,
                            endRadius: 70
                        )
                    )
                    .frame(width: 130, height: 130)

                Image(systemName: celebration.symbolName)
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .glow(accent, radius: 18, opacity: 0.8)
                    .symbolEffect(.bounce, value: appeared)
            }

            if let rarity = celebration.rarity {
                RarityChip(rarity: rarity)
            }

            Text(celebration.title)
                .font(.questTitle)
                .multilineTextAlignment(.center)
                .shimmer(active: celebration.deservesConfetti)

            Text(celebration.message)
                .font(.questCallout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Metrics.spacingM)

            Button("Continuer") { dismiss() }
                .buttonStyle(PrimaryButtonStyle(theme: theme))
                .padding(.top, Metrics.spacingXS)
        }
        .padding(Metrics.spacingL)
        .frame(maxWidth: 320)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerRadiusLarge, style: .continuous)
                .fill(.regularMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cornerRadiusLarge, style: .continuous)
                .strokeBorder(accent.opacity(0.4), lineWidth: 1.5)
        }
        .shadow(color: accent.opacity(0.35), radius: 30, x: 0, y: 12)
        .padding(Metrics.spacingL)
    }

    private func dismiss() {
        guard appeared else { return }
        withAnimation(Motion.snappy) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: onDismiss)
    }
}

// MARK: - Bandeau discret

/// Pour les petites nouvelles (XP gagné, quête avancée) : un bandeau qui
/// glisse depuis le haut sans interrompre.
struct RewardToast: View {
    let symbolName: String
    let title: String
    let detail: String
    let accentHex: String

    @State private var appeared = false

    var body: some View {
        HStack(spacing: Metrics.spacingS) {
            Image(systemName: symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: accentHex))
                .frame(width: 34, height: 34)
                .background {
                    Circle().fill(Color(hex: accentHex).opacity(0.16))
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.questCallout)
                Text(detail)
                    .font(.questMicro)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.spacingM)
        .padding(.vertical, Metrics.spacingS)
        .background {
            Capsule().fill(.regularMaterial)
        }
        .overlay {
            Capsule().strokeBorder(Color(hex: accentHex).opacity(0.25), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        .padding(.horizontal, Metrics.spacingL)
        .offset(y: appeared ? 0 : -100)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(Motion.bouncy) { appeared = true }
        }
    }
}
