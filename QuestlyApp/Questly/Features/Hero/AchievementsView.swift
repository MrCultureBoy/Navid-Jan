import SwiftUI
import SwiftData
import QuestlyKit

/// Galerie des hauts faits, groupée par catégorie. Les secrets restent
/// masqués tant qu'ils ne sont pas obtenus — c'est ce qui donne envie de
/// fouiller.
struct AchievementsView: View {

    @Environment(QuestlyStore.self) private var store
    @Environment(\.questlyTheme) private var theme

    @Query private var profiles: [PlayerProfile]

    @State private var selectedCategory: AchievementCategory?
    @State private var selected: AchievementProgress?
    @State private var showsUnlockedOnly = false

    private var progressList: [AchievementProgress] {
        store.achievementProgress()
    }

    private var filtered: [AchievementProgress] {
        progressList.filter { item in
            let categoryMatches = selectedCategory == nil || item.definition.category == selectedCategory
            let unlockMatches = !showsUnlockedOnly || item.isUnlocked
            return categoryMatches && unlockMatches
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacingM) {
                summary
                categoryFilter
                grid
                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, Metrics.spacingM)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Hauts faits")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(Motion.snappy) { showsUnlockedOnly.toggle() }
                } label: {
                    Image(systemName: showsUnlockedOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(item: $selected) { item in
            AchievementDetailSheet(progress: item)
                .presentationDetents([.height(380)])
        }
    }

    private var summary: some View {
        let unlocked = progressList.filter(\.isUnlocked)
        let points = unlocked.reduce(0) { $0 + $1.definition.xpReward }

        return GlassCard {
            HStack(spacing: Metrics.spacingM) {
                ProgressRing(
                    fraction: progressList.isEmpty ? 0 : Double(unlocked.count) / Double(progressList.count),
                    size: 58,
                    lineWidth: 7,
                    color: theme.accent,
                    content: AnyView(
                        Text("\(unlocked.count)")
                            .font(.questNumber(18))
                            .monospacedDigit()
                    )
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(unlocked.count) sur \(progressList.count)")
                        .font(.questHeadline)
                    Text("\(QuestlyFormat.compactNumber(points)) XP gagnés en trophées")
                        .font(.questMicro)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip(title: "Tout", symbol: "square.grid.2x2", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(AchievementCategory.allCases) { category in
                    filterChip(
                        title: category.label,
                        symbol: category.symbolName,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterChip(title: String, symbol: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Motion.snappy) { action() }
            Haptics.selection()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 10))
                Text(title).font(.questMicro)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background {
                Capsule().fill(isSelected
                               ? AnyShapeStyle(theme.gradient)
                               : AnyShapeStyle(Color.primary.opacity(0.06)))
            }
        }
        .buttonStyle(.plain)
    }

    private var grid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Metrics.spacingS), count: 3),
            spacing: Metrics.spacingS
        ) {
            ForEach(filtered) { item in
                AchievementBadge(progress: item)
                    .onTapGesture {
                        selected = item
                        Haptics.light()
                    }
            }
        }
    }
}

// MARK: - Badge

struct AchievementBadge: View {
    let progress: AchievementProgress

    private var definition: AchievementDefinition { progress.definition }
    private var color: Color { Color(hex: definition.rarity.hex) }
    private var isHidden: Bool { definition.isSecret && !progress.isUnlocked }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(progress.isUnlocked ? color.opacity(0.18) : Color.primary.opacity(0.05))
                    .frame(width: 56, height: 56)

                if progress.isUnlocked {
                    Circle()
                        .strokeBorder(color.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 56, height: 56)
                }

                Image(systemName: isHidden ? "questionmark" : definition.symbolName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(progress.isUnlocked ? color : Color.secondary.opacity(0.5))
            }
            .overlay(alignment: .bottomTrailing) {
                if !progress.isUnlocked && progress.fraction > 0 {
                    Text("\(Int(progress.fraction * 100))%")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background { Capsule().fill(color.opacity(0.8)) }
                }
            }

            Text(isHidden ? "Secret" : definition.title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(progress.isUnlocked ? .primary : .secondary)
                .frame(height: 26)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Metrics.spacingS)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerRadiusSmall, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(progress.isUnlocked ? 1 : 0.6)
        }
        .applyIf(progress.isUnlocked && definition.rarity >= .legendary) { view in
            view.shimmer()
        }
    }
}

// MARK: - Détail

struct AchievementDetailSheet: View {
    let progress: AchievementProgress

    @Environment(\.dismiss) private var dismiss

    private var definition: AchievementDefinition { progress.definition }
    private var color: Color { Color(hex: definition.rarity.hex) }

    var body: some View {
        VStack(spacing: Metrics.spacingM) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [color.opacity(0.4), color.opacity(0.05)],
                            center: .center, startRadius: 4, endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                Image(systemName: definition.symbolName)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(progress.isUnlocked ? color : Color.secondary)
            }
            .padding(.top, Metrics.spacingL)

            RarityChip(rarity: definition.rarity)

            Text(definition.title)
                .font(.questTitle)
                .multilineTextAlignment(.center)

            Text(definition.detail)
                .font(.questCallout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Metrics.spacingL)

            if progress.isUnlocked {
                if let date = progress.unlockedAt {
                    Label("Obtenu le \(QuestlyFormat.longDate(date))", systemImage: "checkmark.seal.fill")
                        .font(.questCaption)
                        .foregroundStyle(Color(hex: "30D158"))
                } else {
                    Label("Obtenu", systemImage: "checkmark.seal.fill")
                        .font(.questCaption)
                        .foregroundStyle(Color(hex: "30D158"))
                }
            } else {
                VStack(spacing: 4) {
                    ProgressView(value: progress.fraction)
                        .progressViewStyle(.linear)
                        .tint(color)
                        .frame(maxWidth: 220)
                    Text("\(progress.value) / \(definition.goal) — encore \(progress.remaining)")
                        .font(.questMicro)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: Metrics.spacingM) {
                Label("\(definition.xpReward) XP", systemImage: "bolt.fill")
                Label("\(definition.coinReward)", systemImage: "dollarsign.circle.fill")
                if definition.gemReward > 0 {
                    Label("\(definition.gemReward)", systemImage: "diamond.fill")
                }
            }
            .font(.questCaption)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(Metrics.spacingM)
    }
}
