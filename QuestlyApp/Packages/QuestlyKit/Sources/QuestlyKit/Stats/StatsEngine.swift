import Foundation

// MARK: - Records

/// Une ligne du journal d'accomplissement. L'app en fournit la liste, le
/// moteur en tire toutes les statistiques.
public struct CompletionRecord: Identifiable, Equatable, Sendable {
    public let id: String
    public let date: Date
    public let xp: Int
    public let focusMinutes: Int
    public let priority: Priority
    public let difficulty: Difficulty
    public let lifeArea: LifeArea?
    public let wasOnTime: Bool
    public let isHabit: Bool
    public let isBoss: Bool

    public init(
        id: String = UUID().uuidString,
        date: Date,
        xp: Int,
        focusMinutes: Int = 0,
        priority: Priority = .p4,
        difficulty: Difficulty = .medium,
        lifeArea: LifeArea? = nil,
        wasOnTime: Bool = true,
        isHabit: Bool = false,
        isBoss: Bool = false
    ) {
        self.id = id
        self.date = date
        self.xp = xp
        self.focusMinutes = focusMinutes
        self.priority = priority
        self.difficulty = difficulty
        self.lifeArea = lifeArea
        self.wasOnTime = wasOnTime
        self.isHabit = isHabit
        self.isBoss = isBoss
    }
}

public struct DailyPoint: Identifiable, Equatable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let completed: Int
    public let xp: Int
    public let focusMinutes: Int

    public init(date: Date, completed: Int, xp: Int, focusMinutes: Int) {
        self.date = date
        self.completed = completed
        self.xp = xp
        self.focusMinutes = focusMinutes
    }
}

public struct BucketPoint: Identifiable, Equatable, Sendable {
    public var id: Int { index }
    public let index: Int
    public let label: String
    public let value: Int

    public init(index: Int, label: String, value: Int) {
        self.index = index
        self.label = label
        self.value = value
    }
}

// MARK: - Stats

public struct ProductivityStats: Equatable, Sendable {
    public var totalCompleted: Int
    public var totalXP: Int
    public var totalFocusMinutes: Int
    public var averagePerActiveDay: Double
    public var averageXPPerDay: Double
    public var onTimeRate: Double
    public var bossesDefeated: Int
    public var habitsCompleted: Int
    public var daily: [DailyPoint]
    public var byWeekday: [BucketPoint]
    public var byHour: [BucketPoint]
    public var byArea: [LifeArea: Int]
    public var byDifficulty: [Difficulty: Int]
    public var byPriority: [Priority: Int]
    public var bestWeekday: Int?
    public var bestHour: Int?
    public var activeDays: Int

    public init(
        totalCompleted: Int = 0,
        totalXP: Int = 0,
        totalFocusMinutes: Int = 0,
        averagePerActiveDay: Double = 0,
        averageXPPerDay: Double = 0,
        onTimeRate: Double = 0,
        bossesDefeated: Int = 0,
        habitsCompleted: Int = 0,
        daily: [DailyPoint] = [],
        byWeekday: [BucketPoint] = [],
        byHour: [BucketPoint] = [],
        byArea: [LifeArea: Int] = [:],
        byDifficulty: [Difficulty: Int] = [:],
        byPriority: [Priority: Int] = [:],
        bestWeekday: Int? = nil,
        bestHour: Int? = nil,
        activeDays: Int = 0
    ) {
        self.totalCompleted = totalCompleted
        self.totalXP = totalXP
        self.totalFocusMinutes = totalFocusMinutes
        self.averagePerActiveDay = averagePerActiveDay
        self.averageXPPerDay = averageXPPerDay
        self.onTimeRate = onTimeRate
        self.bossesDefeated = bossesDefeated
        self.habitsCompleted = habitsCompleted
        self.daily = daily
        self.byWeekday = byWeekday
        self.byHour = byHour
        self.byArea = byArea
        self.byDifficulty = byDifficulty
        self.byPriority = byPriority
        self.bestWeekday = bestWeekday
        self.bestHour = bestHour
        self.activeDays = activeDays
    }

    public static let empty = ProductivityStats()
}

// MARK: - Engine

public enum StatsEngine {

    public static let weekdayNames = ["Dim", "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam"]
    public static let weekdayFullNames = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]

    public static func compute(
        records: [CompletionRecord],
        from start: Date,
        to end: Date,
        calendar: Calendar = .questly()
    ) -> ProductivityStats {
        let windowStart = calendar.startOfDay(for: start)
        let windowEnd = calendar.endOfDay(end)
        let scoped = records.filter { $0.date >= windowStart && $0.date <= windowEnd }

        guard !scoped.isEmpty else {
            return ProductivityStats(daily: emptyDaily(from: windowStart, to: windowEnd, calendar: calendar),
                                     byWeekday: emptyWeekdayBuckets(),
                                     byHour: emptyHourBuckets())
        }

        var perDay: [Date: (count: Int, xp: Int, focus: Int)] = [:]
        var weekdayCounts = [Int](repeating: 0, count: 7)
        var hourCounts = [Int](repeating: 0, count: 24)
        var areaCounts: [LifeArea: Int] = [:]
        var difficultyCounts: [Difficulty: Int] = [:]
        var priorityCounts: [Priority: Int] = [:]
        var onTime = 0
        var bosses = 0
        var habits = 0
        var totalXP = 0
        var totalFocus = 0

        for record in scoped {
            let day = calendar.startOfDay(for: record.date)
            var entry = perDay[day] ?? (0, 0, 0)
            entry.count += 1
            entry.xp += record.xp
            entry.focus += record.focusMinutes
            perDay[day] = entry

            let weekday = calendar.component(.weekday, from: record.date) - 1
            if weekday >= 0 && weekday < 7 { weekdayCounts[weekday] += 1 }
            let hour = calendar.component(.hour, from: record.date)
            if hour >= 0 && hour < 24 { hourCounts[hour] += 1 }

            if let area = record.lifeArea { areaCounts[area, default: 0] += 1 }
            difficultyCounts[record.difficulty, default: 0] += 1
            priorityCounts[record.priority, default: 0] += 1

            if record.wasOnTime { onTime += 1 }
            if record.isBoss { bosses += 1 }
            if record.isHabit { habits += 1 }
            totalXP += record.xp
            totalFocus += record.focusMinutes
        }

        let daily = daySequence(from: windowStart, to: windowEnd, calendar: calendar).map { day -> DailyPoint in
            let entry = perDay[day] ?? (0, 0, 0)
            return DailyPoint(date: day, completed: entry.count, xp: entry.xp, focusMinutes: entry.focus)
        }

        let spanDays = max(1, calendar.daysBetween(windowStart, windowEnd) + 1)
        let activeDays = perDay.keys.count

        return ProductivityStats(
            totalCompleted: scoped.count,
            totalXP: totalXP,
            totalFocusMinutes: totalFocus,
            averagePerActiveDay: activeDays > 0 ? Double(scoped.count) / Double(activeDays) : 0,
            averageXPPerDay: Double(totalXP) / Double(spanDays),
            onTimeRate: Double(onTime) / Double(scoped.count),
            bossesDefeated: bosses,
            habitsCompleted: habits,
            daily: daily,
            byWeekday: weekdayCounts.enumerated().map {
                BucketPoint(index: $0.offset, label: weekdayNames[$0.offset], value: $0.element)
            },
            byHour: hourCounts.enumerated().map {
                BucketPoint(index: $0.offset, label: String(format: "%02dh", $0.offset), value: $0.element)
            },
            byArea: areaCounts,
            byDifficulty: difficultyCounts,
            byPriority: priorityCounts,
            bestWeekday: weekdayCounts.enumerated().max(by: { $0.element < $1.element }).flatMap { $0.element > 0 ? $0.offset : nil },
            bestHour: hourCounts.enumerated().max(by: { $0.element < $1.element }).flatMap { $0.element > 0 ? $0.offset : nil },
            activeDays: activeDays
        )
    }

    /// Moyenne mobile, pour lisser la courbe d'XP.
    public static func rollingAverage(_ points: [DailyPoint], window: Int = 7) -> [Double] {
        guard window > 1, !points.isEmpty else { return points.map { Double($0.xp) } }
        var output: [Double] = []
        output.reserveCapacity(points.count)
        for index in points.indices {
            let lower = max(0, index - window + 1)
            let slice = points[lower...index]
            let sum = slice.reduce(0) { $0 + $1.xp }
            output.append(Double(sum) / Double(slice.count))
        }
        return output
    }

    /// Jours estimés avant le prochain niveau au rythme actuel.
    public static func daysToNextLevel(totalXP: Int, averageXPPerDay: Double) -> Int? {
        guard averageXPPerDay > 0.5 else { return nil }
        let progress = LevelCurve.progress(forTotalXP: totalXP)
        guard progress.xpRemaining > 0 else { return 0 }
        return Int(ceil(Double(progress.xpRemaining) / averageXPPerDay))
    }

    /// Comparaison semaine en cours / semaine précédente, en pourcentage.
    public static func weekOverWeekChange(
        records: [CompletionRecord],
        reference: Date,
        calendar: Calendar = .questly()
    ) -> Double? {
        let thisWeekStart = calendar.startOfWeek(reference)
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? thisWeekStart
        let thisWeek = records.filter { $0.date >= thisWeekStart && $0.date <= reference }.count
        let lastWeekEnd = calendar.date(byAdding: .day, value: calendar.daysBetween(thisWeekStart, reference), to: lastWeekStart) ?? thisWeekStart
        let lastWeek = records.filter { $0.date >= lastWeekStart && $0.date <= lastWeekEnd }.count
        guard lastWeek > 0 else { return thisWeek > 0 ? 1.0 : nil }
        return (Double(thisWeek) - Double(lastWeek)) / Double(lastWeek)
    }

    // MARK: Helpers

    static func daySequence(from start: Date, to end: Date, calendar: Calendar) -> [Date] {
        var days: [Date] = []
        var cursor = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        var guardCounter = 0
        while cursor <= last && guardCounter < 800 {
            guardCounter += 1
            days.append(cursor)
            cursor = cursor.adding(days: 1, calendar: calendar)
        }
        return days
    }

    static func emptyDaily(from start: Date, to end: Date, calendar: Calendar) -> [DailyPoint] {
        daySequence(from: start, to: end, calendar: calendar).map {
            DailyPoint(date: $0, completed: 0, xp: 0, focusMinutes: 0)
        }
    }

    static func emptyWeekdayBuckets() -> [BucketPoint] {
        (0..<7).map { BucketPoint(index: $0, label: weekdayNames[$0], value: 0) }
    }

    static func emptyHourBuckets() -> [BucketPoint] {
        (0..<24).map { BucketPoint(index: $0, label: String(format: "%02dh", $0), value: 0) }
    }
}

// MARK: - Insights

/// Petites phrases générées à partir des statistiques, affichées dans
/// l'onglet Chroniques. Elles rendent les chiffres actionnables.
public struct Insight: Identifiable, Equatable, Sendable {
    public enum Tone: String, Sendable {
        case positive
        case neutral
        case warning
    }

    public let id: String
    public let title: String
    public let detail: String
    public let symbolName: String
    public let tone: Tone

    public init(id: String, title: String, detail: String, symbolName: String, tone: Tone) {
        self.id = id
        self.title = title
        self.detail = detail
        self.symbolName = symbolName
        self.tone = tone
    }
}

public enum InsightEngine {

    public static func insights(
        stats: ProductivityStats,
        streak: StreakState,
        totalXP: Int,
        overdueCount: Int,
        calendar: Calendar = .questly()
    ) -> [Insight] {
        var output: [Insight] = []

        if let bestWeekday = stats.bestWeekday, stats.totalCompleted >= 10 {
            let name = StatsEngine.weekdayFullNames[bestWeekday]
            let value = stats.byWeekday.first { $0.index == bestWeekday }?.value ?? 0
            let average = Double(stats.totalCompleted) / 7.0
            let delta = average > 0 ? (Double(value) - average) / average : 0
            if delta > 0.2 {
                output.append(Insight(
                    id: "bestWeekday",
                    title: "Le \(name) est ton jour fort",
                    detail: "\(Int(delta * 100)) % de quêtes en plus que la moyenne. Réserve-y ce qui compte.",
                    symbolName: "calendar.badge.checkmark",
                    tone: .positive
                ))
            }
        }

        if let bestHour = stats.bestHour, stats.totalCompleted >= 10 {
            output.append(Insight(
                id: "bestHour",
                title: "Ton pic est vers \(bestHour) h",
                detail: "C'est là que tu clôtures le plus de quêtes. Protège ce créneau.",
                symbolName: "sun.max.fill",
                tone: .positive
            ))
        }

        if streak.current >= 3 {
            output.append(Insight(
                id: "streak",
                title: "Série de \(streak.current) jours",
                detail: "Multiplicateur d'XP actuel : ×\(String(format: "%.2f", XPEngine.streakMultiplier(days: streak.current))).",
                symbolName: "flame.fill",
                tone: .positive
            ))
        } else if streak.isAtRisk {
            output.append(Insight(
                id: "streakRisk",
                title: "Ta série est en jeu",
                detail: "Une seule quête aujourd'hui suffit à la garder en vie.",
                symbolName: "exclamationmark.triangle.fill",
                tone: .warning
            ))
        }

        if overdueCount > 0 {
            output.append(Insight(
                id: "overdue",
                title: "\(overdueCount) quête\(overdueCount > 1 ? "s" : "") en retard",
                detail: overdueCount > 5
                    ? "Reporte en masse ou allège : une liste crédible vaut mieux qu'une liste complète."
                    : "Un petit nettoyage et tu repars propre.",
                symbolName: "clock.badge.exclamationmark.fill",
                tone: .warning
            ))
        }

        if stats.onTimeRate >= 0.8 && stats.totalCompleted >= 10 {
            output.append(Insight(
                id: "onTime",
                title: "\(Int(stats.onTimeRate * 100)) % dans les temps",
                detail: "Tes estimations sont fiables. Tu peux viser plus grand.",
                symbolName: "checkmark.seal.fill",
                tone: .positive
            ))
        } else if stats.onTimeRate < 0.5 && stats.totalCompleted >= 10 {
            output.append(Insight(
                id: "lateOften",
                title: "Souvent en retard",
                detail: "Essaie d'ajouter 30 % à tes estimations, ou de découper en sous-quêtes.",
                symbolName: "tortoise.fill",
                tone: .warning
            ))
        }

        if let days = StatsEngine.daysToNextLevel(totalXP: totalXP, averageXPPerDay: stats.averageXPPerDay), days > 0 {
            output.append(Insight(
                id: "nextLevel",
                title: "Niveau suivant dans ~\(days) jour\(days > 1 ? "s" : "")",
                detail: "Au rythme de \(Int(stats.averageXPPerDay)) XP par jour.",
                symbolName: "arrow.up.forward.circle.fill",
                tone: .neutral
            ))
        }

        // Domaine délaissé
        let neglected = LifeArea.allCases.filter { (stats.byArea[$0] ?? 0) == 0 }
        if stats.totalCompleted >= 15, let area = neglected.first {
            output.append(Insight(
                id: "neglected.\(area.rawValue)",
                title: "Le domaine \(area.label) dort",
                detail: "Aucune quête accomplie sur la période. \(area.subtitle).",
                symbolName: area.symbolName,
                tone: .neutral
            ))
        }

        if stats.totalFocusMinutes >= 60 {
            let hours = stats.totalFocusMinutes / 60
            output.append(Insight(
                id: "focus",
                title: "\(hours) h de concentration",
                detail: "Soit \(stats.totalFocusMinutes) minutes arrachées aux distractions.",
                symbolName: "timer",
                tone: .positive
            ))
        }

        return output
    }

    /// Le domaine le plus délaissé, utilisé pour orienter les quêtes du jour.
    public static func neglectedAreas(stats: ProductivityStats, limit: Int = 2) -> [LifeArea] {
        LifeArea.allCases
            .map { ($0, stats.byArea[$0] ?? 0) }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }
}
