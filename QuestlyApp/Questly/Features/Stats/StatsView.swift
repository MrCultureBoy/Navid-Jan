import SwiftUI
import SwiftData
import Charts
import QuestlyKit

/// Les Chroniques : ce que racontent les données. L'objectif n'est pas
/// d'impressionner avec des courbes, mais de rendre visible ce qui se répète.
struct StatsView: View {

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(\.questlyTheme) private var theme

    @Query private var profiles: [PlayerProfile]
    @Query private var events: [CompletionEvent]

    @State private var period: Period = .month

    enum Period: String, CaseIterable, Identifiable, Hashable {
        case week, month, quarter, year

        var id: String { rawValue }

        var label: String {
            switch self {
            case .week: return "7 j"
            case .month: return "30 j"
            case .quarter: return "90 j"
            case .year: return "1 an"
            }
        }

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            }
        }
    }

    private var calendar: Calendar { settings.calendar }
    private var player: PlayerProfile? { profiles.first }

    private var stats: ProductivityStats {
        StatsEngine.compute(
            records: events.map(\.record),
            from: Date().adding(days: -period.days, calendar: calendar),
            to: Date(),
            calendar: calendar
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacingL) {
                periodPicker
                summaryTiles
                xpChart
                completionChart
                weekdayChart
                hourChart
                areaChart
                heatmapSection
                insightsSection
                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, Metrics.spacingM)
            .padding(.top, Metrics.spacingS)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Chroniques")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Période

    private var periodPicker: some View {
        QuestlySegmentedPicker(
            items: Period.allCases,
            label: { $0.label },
            selection: $period
        )
    }

    // MARK: Résumé

    private var summaryTiles: some View {
        let current = stats
        let change = StatsEngine.weekOverWeekChange(
            records: events.map(\.record),
            reference: Date(),
            calendar: calendar
        )

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Metrics.spacingS), count: 2),
            spacing: Metrics.spacingS
        ) {
            tile("Quêtes accomplies", "\(current.totalCompleted)", "checkmark.seal.fill", "30D158",
                 footnote: change.map { "\($0 >= 0 ? "+" : "")\(Int($0 * 100)) % vs semaine dernière" })
            tile("XP gagné", QuestlyFormat.compactNumber(current.totalXP), "bolt.fill", "FFD60A",
                 footnote: "\(Int(current.averageXPPerDay)) XP / jour")
            tile("Concentration", DurationFormatter.short(minutes: current.totalFocusMinutes), "timer", "5E9BFF",
                 footnote: "\(current.activeDays) jours actifs")
            tile("Ponctualité", QuestlyFormat.percent(current.onTimeRate), "clock.badge.checkmark.fill", "34D399",
                 footnote: current.bossesDefeated > 0 ? "\(current.bossesDefeated) boss vaincus" : nil)
        }
    }

    private func tile(_ label: String, _ value: String, _ symbol: String, _ hex: String, footnote: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: hex))
                Spacer()
            }
            Text(value)
                .font(.questNumber(22))
                .monospacedDigit()
            Text(label)
                .font(.questMicro)
                .foregroundStyle(.secondary)
            if let footnote {
                Text(footnote)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: hex))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Metrics.spacingS + 2)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerRadiusSmall, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    // MARK: Courbe d'XP

    private var xpChart: some View {
        chartCard(title: "Expérience gagnée", symbol: "bolt.fill") {
            let points = stats.daily
            let average = StatsEngine.rollingAverage(points, window: 7)

            Chart {
                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    AreaMark(
                        x: .value("Jour", point.date),
                        y: .value("XP", point.xp)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.accent.opacity(0.35), theme.accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    if index < average.count {
                        LineMark(
                            x: .value("Jour", point.date),
                            y: .value("Moyenne", average[index]),
                            series: .value("Série", "moyenne")
                        )
                        .foregroundStyle(theme.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .frame(height: 170)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
    }

    // MARK: Quêtes par jour

    private var completionChart: some View {
        chartCard(title: "Quêtes par jour", symbol: "checklist") {
            Chart(stats.daily) { point in
                BarMark(
                    x: .value("Jour", point.date, unit: .day),
                    y: .value("Quêtes", point.completed)
                )
                .foregroundStyle(theme.gradient)
                .cornerRadius(3)
            }
            .frame(height: 150)
            .chartYAxis { AxisMarks(position: .leading) }
        }
    }

    // MARK: Par jour de semaine

    private var weekdayChart: some View {
        chartCard(title: "Ton rythme hebdomadaire", symbol: "calendar") {
            Chart(stats.byWeekday) { bucket in
                BarMark(
                    x: .value("Jour", bucket.label),
                    y: .value("Quêtes", bucket.value)
                )
                .foregroundStyle(
                    bucket.index == stats.bestWeekday
                        ? AnyShapeStyle(theme.gradient)
                        : AnyShapeStyle(theme.accent.opacity(0.35))
                )
                .cornerRadius(4)
            }
            .frame(height: 140)
            .chartYAxis { AxisMarks(position: .leading) }
        }
    }

    // MARK: Par heure

    private var hourChart: some View {
        chartCard(
            title: "Tes heures fortes",
            symbol: "clock.fill",
            subtitle: stats.bestHour.map { "Pic vers \($0) h" }
        ) {
            Chart(stats.byHour) { bucket in
                BarMark(
                    x: .value("Heure", bucket.index),
                    y: .value("Quêtes", bucket.value)
                )
                .foregroundStyle(
                    bucket.index == stats.bestHour
                        ? AnyShapeStyle(Color(hex: "FF9F0A"))
                        : AnyShapeStyle(theme.accent.opacity(0.45))
                )
                .cornerRadius(2)
            }
            .frame(height: 130)
            .chartXScale(domain: 0...23)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text("\(hour) h").font(.questMicro)
                        }
                    }
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
        }
    }

    // MARK: Par domaine

    /// Compteur par domaine — un type nommé plutôt qu'un tuple : `ForEach`
    /// ne sait pas indexer les tuples par key-path.
    private struct AreaCount: Identifiable {
        let area: LifeArea
        let count: Int
        var id: String { area.rawValue }
    }

    private var areaChart: some View {
        let entries = LifeArea.allCases.map { area in
            AreaCount(area: area, count: stats.byArea[area] ?? 0)
        }
        let total = max(1, entries.reduce(0) { $0 + $1.count })

        return chartCard(title: "Équilibre de vie", symbol: "circle.hexagongrid.fill") {
            VStack(spacing: Metrics.spacingS) {
                // Barre empilée : l'équilibre se lit d'un coup d'œil.
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(entries.filter { $0.count > 0 }) { entry in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: entry.area.hex))
                                .frame(width: max(3, geo.size.width * Double(entry.count) / Double(total)))
                        }
                    }
                }
                .frame(height: 14)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3),
                    spacing: 6
                ) {
                    ForEach(entries) { entry in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: entry.area.hex))
                                .frame(width: 7, height: 7)
                            Text(entry.area.label)
                                .font(.questMicro)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text("\(entry.count)")
                                .font(.questMicro)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: Carte de chaleur

    private var heatmapSection: some View {
        chartCard(title: "Une année en un regard", symbol: "square.grid.3x3.fill") {
            let cells = store.heatmapCells(months: 12)
            // Sept lignes = les sept jours de la semaine, empilés par colonne.
            let rows = Array(repeating: GridItem(.fixed(11), spacing: 3), count: 7)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: rows, spacing: 3) {
                    ForEach(cells) { cell in
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(heatColor(level: cell.level))
                            .frame(width: 11, height: 11)
                    }
                }
                .frame(height: 100)
            }
        }
    }

    private func heatColor(level: Int) -> Color {
        switch level {
        case 0: return Color.primary.opacity(0.07)
        case 1: return theme.accent.opacity(0.28)
        case 2: return theme.accent.opacity(0.5)
        case 3: return theme.accent.opacity(0.75)
        default: return theme.accent
        }
    }

    // MARK: Observations

    private var insightsSection: some View {
        let insights = InsightEngine.insights(
            stats: stats,
            streak: store.streak,
            totalXP: player?.totalXP ?? 0,
            overdueCount: 0,
            calendar: calendar
        )

        return Group {
            if !insights.isEmpty {
                VStack(alignment: .leading, spacing: Metrics.spacingS) {
                    Text("Ce que ça raconte")
                        .font(.questCallout)
                        .foregroundStyle(.secondary)

                    ForEach(insights) { insight in
                        GlassCard {
                            HStack(alignment: .top, spacing: Metrics.spacingS) {
                                Image(systemName: insight.symbolName)
                                    .font(.system(size: 15))
                                    .foregroundStyle(tone(insight.tone))
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(insight.title).font(.questCallout)
                                    Text(insight.detail)
                                        .font(.questMicro)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func tone(_ tone: Insight.Tone) -> Color {
        switch tone {
        case .positive: return Color(hex: "30D158")
        case .warning: return Color(hex: "FF9F0A")
        case .neutral: return Color(hex: "5E9BFF")
        }
    }

    // MARK: Habillage des graphiques

    private func chartCard<Content: View>(
        title: String,
        symbol: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Text(title)
                    .font(.questCallout)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(.questMicro)
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding(Metrics.spacingM)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}
