import SwiftUI
import QuestlyKit

// MARK: - Priorité

struct PriorityBadge: View {
    let priority: Priority
    var compact: Bool = false

    var body: some View {
        let color = Color(hex: priority.hex)
        HStack(spacing: 3) {
            Image(systemName: priority.symbolName)
                .font(.system(size: compact ? 9 : 11, weight: .bold))
            if !compact {
                Text(priority.shortLabel)
                    .font(.questMicro)
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, compact ? 3 : 4)
        .background {
            Capsule().fill(color.opacity(0.16))
        }
    }
}

// MARK: - Difficulté

struct DifficultyBadge: View {
    let difficulty: Difficulty
    var showsLabel: Bool = true

    var body: some View {
        let color = Color(hex: difficulty.hex)
        HStack(spacing: 4) {
            Image(systemName: difficulty.symbolName)
                .font(.system(size: 10, weight: .semibold))
            if showsLabel {
                Text(difficulty.label)
                    .font(.questMicro)
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background { Capsule().fill(color.opacity(0.16)) }
    }
}

// MARK: - Domaine de vie

struct LifeAreaBadge: View {
    let area: LifeArea
    var compact: Bool = false

    var body: some View {
        let color = Color(hex: area.hex)
        HStack(spacing: 4) {
            Image(systemName: area.symbolName)
                .font(.system(size: compact ? 9 : 11, weight: .semibold))
            if !compact {
                Text(area.label).font(.questMicro)
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, compact ? 3 : 4)
        .background { Capsule().fill(color.opacity(0.16)) }
    }
}

// MARK: - Étiquette

struct TagChip: View {
    let name: String
    let colorHex: String
    var isSelected: Bool = false

    var body: some View {
        let color = Color(hex: colorHex)
        Text("#\(name)")
            .font(.questMicro)
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule().fill(isSelected ? color : color.opacity(0.16))
            }
    }
}

// MARK: - Rareté

struct RarityChip: View {
    let rarity: Rarity

    var body: some View {
        let color = Color(hex: rarity.hex)
        Text(rarity.label.uppercased())
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .kerning(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(color.opacity(0.18))
                    .overlay { Capsule().strokeBorder(color.opacity(0.5), lineWidth: 0.8) }
            }
    }
}

// MARK: - Monnaies

struct CurrencyPill: View {
    enum Kind {
        case coins
        case gems

        var symbolName: String {
            switch self {
            case .coins: return "dollarsign.circle.fill"
            case .gems: return "diamond.fill"
            }
        }

        var color: Color {
            switch self {
            case .coins: return Color(hex: "FFD60A")
            case .gems: return Color(hex: "64D2FF")
            }
        }
    }

    let kind: Kind
    let amount: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: kind.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(kind.color)
            Text("\(amount)")
                .font(.questCaption)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background { Capsule().fill(.ultraThinMaterial) }
        .overlay { Capsule().strokeBorder(kind.color.opacity(0.25), lineWidth: 1) }
    }
}

// MARK: - Pastille d'XP

struct XPPill: View {
    let amount: Int
    var isPreview: Bool = false

    @Environment(\.questlyTheme) private var theme

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 9, weight: .bold))
            Text(isPreview ? "+\(amount)" : "\(amount)")
                .font(.questMicro)
                .monospacedDigit()
        }
        .foregroundStyle(isPreview ? theme.accent : .white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background {
            Capsule()
                .fill(isPreview
                      ? AnyShapeStyle(theme.accent.opacity(0.16))
                      : AnyShapeStyle(theme.gradient))
        }
    }
}

// MARK: - Indicateur de combo

/// Apparaît en haut de l'écran quand plusieurs quêtes s'enchaînent.
struct ComboIndicator: View {
    let count: Int
    let remainingSeconds: Int

    @Environment(\.questlyTheme) private var theme
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Color(hex: "FFD60A"))
                .symbolEffect(.bounce, value: count)

            Text("COMBO ×\(count)")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .kerning(0.8)
                .foregroundStyle(.white)

            Text("+\(Int((XPEngine.comboMultiplier(count: count) - 1) * 100)) %")
                .font(.questMicro)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FF9F0A"), Color(hex: "FF375F")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .overlay(alignment: .bottom) {
            // Sablier du combo.
            GeometryReader { geo in
                Capsule()
                    .fill(.white.opacity(0.9))
                    .frame(
                        width: geo.size.width * min(1, Double(remainingSeconds) / XPEngine.comboWindow),
                        height: 2
                    )
            }
            .frame(height: 2)
            .padding(.horizontal, 10)
            .padding(.bottom, 3)
        }
        .glow(Color(hex: "FF9F0A"), radius: 14, opacity: 0.6)
        .scaleEffect(appeared ? 1 : 0.7)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(Motion.bouncy) { appeared = true }
        }
    }
}

// MARK: - Case à cocher de quête

/// La case à cocher est le geste le plus répété de l'app : elle mérite sa
/// propre animation (remplissage + pointe qui se dessine).
struct QuestCheckbox: View {
    let isCompleted: Bool
    let tint: Color
    var size: CGFloat = 26
    var isBoss: Bool = false
    let action: () -> Void

    @State private var isAnimating = false

    var body: some View {
        Button(action: {
            isAnimating = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { isAnimating = false }
        }) {
            ZStack {
                if isBoss {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(tint.opacity(isCompleted ? 0 : 0.7), lineWidth: 2)
                        .frame(width: size, height: size)
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(tint)
                        .frame(width: size, height: size)
                        .scaleEffect(isCompleted ? 1 : 0)
                } else {
                    Circle()
                        .strokeBorder(tint.opacity(isCompleted ? 0 : 0.55), lineWidth: 2)
                        .frame(width: size, height: size)
                    Circle()
                        .fill(tint)
                        .frame(width: size, height: size)
                        .scaleEffect(isCompleted ? 1 : 0)
                }

                Image(systemName: isBoss ? "crown.fill" : "checkmark")
                    .font(.system(size: size * 0.5, weight: .heavy))
                    .foregroundStyle(.white)
                    .scaleEffect(isCompleted ? 1 : 0.2)
                    .opacity(isCompleted ? 1 : 0)
            }
            .scaleEffect(isAnimating ? 1.25 : 1)
            .animation(Motion.bouncy, value: isCompleted)
            .animation(Motion.snappy, value: isAnimating)
            .contentShape(Rectangle())
            .frame(width: size + 12, height: size + 12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCompleted ? "Marquer comme non accomplie" : "Accomplir la quête")
    }
}
