import SwiftUI

// MARK: - Onglets

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case today
    case quests
    case calendar
    case focus
    case hero

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Repaire"
        case .quests: return "Quêtes"
        case .calendar: return "Calendrier"
        case .focus: return "Donjon"
        case .hero: return "Héros"
        }
    }

    var symbolName: String {
        switch self {
        case .today: return "house.fill"
        case .quests: return "checklist"
        case .calendar: return "calendar"
        case .focus: return "timer"
        case .hero: return "person.crop.circle.fill"
        }
    }
}

// MARK: - Barre d'onglets

/// Barre maison : la pilule active glisse d'un onglet à l'autre et l'icône
/// rebondit. Un `TabView` standard n'offre ni l'un ni l'autre.
struct QuestlyTabBar: View {
    @Binding var selection: AppTab
    var badges: [AppTab: Int] = [:]

    @Environment(\.questlyTheme) private var theme
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        }
        .overlay {
            Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .padding(.horizontal, Metrics.spacingM)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab

        return Button {
            guard selection != tab else { return }
            withAnimation(Motion.snappy) { selection = tab }
            Haptics.selection()
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(theme.gradient)
                            .frame(width: 38, height: 38)
                            .matchedGeometryEffect(id: "tab.pill", in: namespace)
                            .glow(theme.accent, radius: 10, opacity: 0.5)
                    }

                    Image(systemName: tab.symbolName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                        .symbolEffect(.bounce, value: isSelected)
                }
                .frame(height: 38)
                .overlay(alignment: .topTrailing) {
                    if let count = badges[tab], count > 0, !isSelected {
                        Text(count > 99 ? "99+" : "\(count)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background { Capsule().fill(Color(hex: "FF453A")) }
                            .offset(x: 8, y: -2)
                    }
                }

                Text(tab.title)
                    .font(.system(size: 9, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? theme.accent : .secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }
}

// MARK: - Bouton d'ajout

/// Bouton flottant de saisie rapide. Toujours au même endroit, toujours à un
/// pouce de distance.
struct QuickAddButton: View {
    let action: () -> Void

    @Environment(\.questlyTheme) private var theme
    @State private var isPressed = false

    var body: some View {
        Button {
            Haptics.play(.medium)
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background {
                    Circle()
                        .fill(theme.gradient)
                        .shadow(color: theme.accent.opacity(0.5), radius: 16, y: 8)
                }
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1)
                }
        }
        .buttonStyle(PressableStyle(scale: 0.9))
        .accessibilityLabel("Nouvelle quête")
    }
}
