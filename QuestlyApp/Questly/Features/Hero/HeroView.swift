import SwiftUI
import SwiftData
import QuestlyKit

/// Le Héros : identité, attributs, hauts faits, échoppe et réglages.
/// C'est la vitrine de la progression — l'écran que l'on ouvre pour se
/// rappeler d'où l'on vient.
struct HeroView: View {

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(\.questlyTheme) private var theme

    @Query private var profiles: [PlayerProfile]
    @Query private var events: [CompletionEvent]

    @State private var showsAvatarBuilder = false

    private var player: PlayerProfile? { profiles.first }
    private var calendar: Calendar { settings.calendar }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.spacingL) {
                    heroCard
                    attributeSection
                    statsGrid
                    achievementsPreview
                    navigationCards
                    Color.clear.frame(height: 110)
                }
                .padding(.horizontal, Metrics.spacingM)
                .padding(.top, Metrics.spacingS)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Héros")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showsAvatarBuilder) {
                AvatarBuilderView()
            }
        }
    }

    // MARK: Carte du héros

    private var heroCard: some View {
        VStack(spacing: Metrics.spacingM) {
            ZStack {
                if let aura = player?.avatarPart(for: .aura), aura.id != "aura.none" {
                    Image(systemName: aura.symbolName)
                        .font(.system(size: 130))
                        .foregroundStyle(theme.accent.opacity(0.12))
                        .blur(radius: 2)
                }

                Button {
                    showsAvatarBuilder = true
                    Haptics.light()
                } label: {
                    LevelRing(
                        progress: player?.levelProgress ?? .zero,
                        size: 118,
                        lineWidth: 9,
                        emoji: player?.avatarPart(for: .face)?.emoji ?? "🧭"
                    )
                }
                .buttonStyle(PressableStyle())

                if let hat = player?.avatarPart(for: .headgear), hat.id != "hat.none" {
                    Image(systemName: hat.symbolName)
                        .font(.system(size: 26))
                        .foregroundStyle(Color(hex: hat.rarity.hex))
                        .offset(y: -68)
                }

                if let pet = player?.avatarPart(for: .companion), pet.id != "pet.none",
                   let emoji = pet.emoji {
                    Text(emoji)
                        .font(.system(size: 28))
                        .offset(x: 58, y: 40)
                }
            }
            .frame(height: 140)

            VStack(spacing: 3) {
                Text(player?.displayName ?? "Aventurier·ère")
                    .font(.questTitle)
                HStack(spacing: 6) {
                    Image(systemName: player?.rank.symbolName ?? "leaf")
                        .font(.system(size: 12))
                    Text(player?.rank.title ?? "Novice")
                        .font(.questCallout)
                }
                .foregroundStyle(Color(hex: player?.rank.hex ?? "9CA3AF"))
            }

            XPBar(progress: player?.levelProgress ?? .zero)

            HStack(spacing: Metrics.spacingS) {
                CurrencyPill(kind: .coins, amount: player?.coins ?? 0)
                CurrencyPill(kind: .gems, amount: player?.gems ?? 0)
                Spacer()
                StreakFlame(days: store.streak.current, isAtRisk: store.streak.isAtRisk, size: 18)
            }
        }
        .padding(Metrics.spacingM)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerRadiusLarge, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.cornerRadiusLarge, style: .continuous)
                        .fill(theme.softGradient)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cornerRadiusLarge, style: .continuous)
                .strokeBorder(theme.accent.opacity(0.25), lineWidth: 1)
        }
    }

    // MARK: Attributs

    private var attributeSection: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            sectionHeader("Attributs", symbol: "circle.hexagongrid.fill")

            GlassCard {
                VStack(spacing: Metrics.spacingS) {
                    ForEach(LifeArea.allCases) { area in
                        AttributeBar(
                            area: area,
                            xp: player?.attributeXP(for: area) ?? 0,
                            completions: completions(in: area)
                        )
                    }
                }
            }
        }
    }

    private func completions(in area: LifeArea) -> Int {
        events.filter { $0.lifeArea == area }.count
    }

    // MARK: Statistiques rapides

    private var statsGrid: some View {
        let stats = store.currentStats(days: 3650)

        return VStack(alignment: .leading, spacing: Metrics.spacingS) {
            sectionHeader("En chiffres", symbol: "chart.bar.fill")

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Metrics.spacingS), count: 2),
                spacing: Metrics.spacingS
            ) {
                statTile("Quêtes accomplies", value: "\(player?.tasksCompleted ?? 0)", symbol: "checkmark.seal.fill", hex: "30D158")
                statTile("XP total", value: QuestlyFormat.compactNumber(player?.totalXP ?? 0), symbol: "bolt.fill", hex: "FFD60A")
                statTile("Meilleure série", value: "\(player?.longestStreak ?? 0) j", symbol: "flame.fill", hex: "FF7A00")
                statTile("Concentration", value: DurationFormatter.short(minutes: player?.focusMinutes ?? 0), symbol: "timer", hex: "5E9BFF")
                statTile("Boss vaincus", value: "\(player?.bossesDefeated ?? 0)", symbol: "crown.fill", hex: "BF5AF2")
                statTile("Ponctualité", value: QuestlyFormat.percent(stats.onTimeRate), symbol: "clock.badge.checkmark.fill", hex: "34D399")
            }
        }
    }

    private func statTile(_ label: String, value: String, symbol: String, hex: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: hex))
            Text(value)
                .font(.questNumber(20))
                .monospacedDigit()
            Text(label)
                .font(.questMicro)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Metrics.spacingS + 2)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerRadiusSmall, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: Hauts faits

    private var achievementsPreview: some View {
        let progress = store.achievementProgress()
        let unlocked = progress.filter(\.isUnlocked)
        let almost = AchievementEngine.almostThere(
            snapshot: store.playerSnapshot(),
            unlockDates: player?.unlockedAchievements ?? [:],
            limit: 3
        )

        return VStack(alignment: .leading, spacing: Metrics.spacingS) {
            HStack {
                sectionHeader("Hauts faits", symbol: "trophy.fill")
                Spacer()
                NavigationLink("Tout voir") {
                    AchievementsView()
                }
                .font(.questMicro)
                .foregroundStyle(theme.accent)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: Metrics.spacingS) {
                    HStack {
                        Text("\(unlocked.count) / \(progress.count)")
                            .font(.questNumber(22))
                            .monospacedDigit()
                        Text("débloqués")
                            .font(.questCaption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        ProgressRing(
                            fraction: progress.isEmpty ? 0 : Double(unlocked.count) / Double(progress.count),
                            size: 38,
                            lineWidth: 5,
                            color: theme.accent
                        )
                    }

                    if !almost.isEmpty {
                        Divider().opacity(0.4)
                        Text("Bientôt")
                            .font(.questMicro)
                            .foregroundStyle(.secondary)
                        ForEach(almost) { item in
                            HStack(spacing: Metrics.spacingS) {
                                Image(systemName: item.definition.symbolName)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(hex: item.definition.rarity.hex))
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.definition.title).font(.questCaption)
                                    ProgressView(value: item.fraction)
                                        .progressViewStyle(.linear)
                                        .tint(Color(hex: item.definition.rarity.hex))
                                }
                                Text("\(item.value)/\(item.definition.goal)")
                                    .font(.questMicro)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Accès

    private var navigationCards: some View {
        VStack(spacing: Metrics.spacingS) {
            NavigationLink {
                ShopView()
            } label: {
                navigationRow(
                    title: "Échoppe",
                    subtitle: "Potions, ambiances, apparence",
                    symbol: "bag.fill",
                    hex: "FF9F0A"
                )
            }

            NavigationLink {
                StatsView()
            } label: {
                navigationRow(
                    title: "Chroniques",
                    subtitle: "Statistiques et tendances",
                    symbol: "chart.xyaxis.line",
                    hex: "5E9BFF"
                )
            }

            NavigationLink {
                SettingsView()
            } label: {
                navigationRow(
                    title: "Réglages",
                    subtitle: "Thèmes, notifications, données",
                    symbol: "gearshape.fill",
                    hex: "8E8E93"
                )
            }
        }
    }

    private func navigationRow(title: String, subtitle: String, symbol: String, hex: String) -> some View {
        HStack(spacing: Metrics.spacingM) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: hex))
                .frame(width: 38, height: 38)
                .background { Circle().fill(Color(hex: hex).opacity(0.14)) }

            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.questBody).foregroundStyle(.primary)
                Text(subtitle).font(.questMicro).foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Metrics.spacingS + 2)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    private func sectionHeader(_ title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.accent)
            Text(title)
                .font(.questCallout)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Barre d'attribut

struct AttributeBar: View {
    let area: LifeArea
    let xp: Int
    let completions: Int

    private var progress: (level: Int, into: Int, required: Int, fraction: Double) {
        AttributeCurve.progress(forTotalXP: xp)
    }

    var body: some View {
        let color = Color(hex: area.hex)

        HStack(spacing: Metrics.spacingS) {
            Image(systemName: area.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background { Circle().fill(color.opacity(0.14)) }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(area.label).font(.questCaption)
                    Spacer()
                    Text("Niv. \(progress.level)")
                        .font(.questMicro)
                        .foregroundStyle(color)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(color.opacity(0.12))
                        Capsule()
                            .fill(color)
                            .frame(width: max(4, geo.size.width * progress.fraction))
                    }
                }
                .frame(height: 6)
            }

            Text("\(completions)")
                .font(.questMicro)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .trailing)
        }
    }
}
