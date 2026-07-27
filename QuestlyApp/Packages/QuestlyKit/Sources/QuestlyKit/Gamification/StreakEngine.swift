import Foundation

/// État complet de la série de jours actifs.
public struct StreakState: Equatable, Sendable {
    public var current: Int
    public var longest: Int
    public var lastActiveDay: Date?
    /// Jours sauvés par un jeton de protection lors de ce calcul.
    public var freezesConsumed: Int
    /// `true` si la série tient encore mais qu'aucune tâche n'a été validée aujourd'hui.
    public var isAtRisk: Bool
    /// Nombre total de jours actifs enregistrés.
    public var totalActiveDays: Int

    public init(
        current: Int = 0,
        longest: Int = 0,
        lastActiveDay: Date? = nil,
        freezesConsumed: Int = 0,
        isAtRisk: Bool = false,
        totalActiveDays: Int = 0
    ) {
        self.current = current
        self.longest = longest
        self.lastActiveDay = lastActiveDay
        self.freezesConsumed = freezesConsumed
        self.isAtRisk = isAtRisk
        self.totalActiveDays = totalActiveDays
    }

    public static let empty = StreakState()

    /// Paliers de série qui déclenchent une célébration.
    public var milestoneReached: Int? {
        let milestones = [3, 7, 14, 21, 30, 50, 75, 100, 150, 200, 365, 500, 1000]
        return milestones.contains(current) ? current : nil
    }
}

/// Calcule les séries à partir de l'historique d'activité.
///
/// Trois soupapes évitent la spirale de culpabilité qui tue les apps de
/// productivité : le jour en cours ne casse jamais la série (grâce jusqu'à
/// minuit), les jours de repos choisis sont neutres, et les jetons de
/// protection comblent automatiquement un trou isolé.
public enum StreakEngine {

    public struct Configuration: Sendable, Equatable {
        /// Jours de la semaine neutres (1 = dimanche … 7 = samedi).
        public var restWeekdays: Set<Int>
        /// Jetons de protection disponibles.
        public var availableFreezes: Int
        /// Un jeton ne peut combler qu'un trou d'au plus N jours.
        public var maxGapPerFreeze: Int

        public init(
            restWeekdays: Set<Int> = [],
            availableFreezes: Int = 0,
            maxGapPerFreeze: Int = 1
        ) {
            self.restWeekdays = restWeekdays
            self.availableFreezes = availableFreezes
            self.maxGapPerFreeze = maxGapPerFreeze
        }

        public static let `default` = Configuration()
    }

    /// - Parameter activeDays: dates (normalisées au début de journée) où au
    ///   moins une quête a été accomplie.
    public static func evaluate(
        activeDays: Set<Date>,
        today: Date,
        configuration: Configuration = .default,
        calendar: Calendar = .questly()
    ) -> StreakState {
        let normalized = Set(activeDays.map { calendar.startOfDay(for: $0) })
        guard !normalized.isEmpty else {
            return StreakState(current: 0, longest: 0, lastActiveDay: nil, freezesConsumed: 0, isAtRisk: false, totalActiveDays: 0)
        }

        let todayStart = calendar.startOfDay(for: today)
        let lastActive = normalized.max()

        // --- Série courante -------------------------------------------------
        var current = 0
        var freezesLeft = configuration.availableFreezes
        var freezesConsumed = 0
        var cursor = todayStart
        var isAtRisk = false

        if !normalized.contains(todayStart) {
            // Le jour en cours n'est pas encore validé : on ne le compte pas,
            // mais il ne casse pas la série tant qu'il n'est pas terminé.
            if !isRestDay(todayStart, configuration: configuration, calendar: calendar) {
                isAtRisk = true
            }
            cursor = todayStart.adding(days: -1, calendar: calendar)
        }

        var guardCounter = 0
        let hardLimit = 4000
        while guardCounter < hardLimit {
            guardCounter += 1
            if normalized.contains(cursor) {
                current += 1
                cursor = cursor.adding(days: -1, calendar: calendar)
                continue
            }
            if isRestDay(cursor, configuration: configuration, calendar: calendar) {
                // Jour de repos : neutre, on saute sans casser ni compter.
                cursor = cursor.adding(days: -1, calendar: calendar)
                continue
            }
            // Un trou : on tente un jeton de protection, à condition qu'il
            // reste de l'activité avant le trou.
            if freezesLeft > 0, hasActivity(before: cursor, in: normalized) {
                freezesLeft -= 1
                freezesConsumed += 1
                cursor = cursor.adding(days: -1, calendar: calendar)
                continue
            }
            break
        }

        // --- Meilleure série -------------------------------------------------
        let longest = longestRun(
            days: normalized,
            configuration: configuration,
            calendar: calendar
        )

        return StreakState(
            current: current,
            longest: max(longest, current),
            lastActiveDay: lastActive,
            freezesConsumed: freezesConsumed,
            isAtRisk: isAtRisk && current > 0,
            totalActiveDays: normalized.count
        )
    }

    /// Meilleure série historique (sans jetons : l'histoire ne se réécrit pas).
    static func longestRun(
        days: Set<Date>,
        configuration: Configuration,
        calendar: Calendar
    ) -> Int {
        let sorted = days.sorted()
        guard let first = sorted.first else { return 0 }

        var best = 0
        var run = 0
        var cursor = first

        guard let last = sorted.last else { return 0 }
        var guardCounter = 0
        while cursor <= last && guardCounter < 20000 {
            guardCounter += 1
            if days.contains(cursor) {
                run += 1
                best = max(best, run)
            } else if isRestDay(cursor, configuration: configuration, calendar: calendar) {
                // neutre
            } else {
                run = 0
            }
            cursor = cursor.adding(days: 1, calendar: calendar)
        }
        return best
    }

    static func isRestDay(_ date: Date, configuration: Configuration, calendar: Calendar) -> Bool {
        guard !configuration.restWeekdays.isEmpty else { return false }
        return configuration.restWeekdays.contains(calendar.component(.weekday, from: date))
    }

    static func hasActivity(before date: Date, in days: Set<Date>) -> Bool {
        days.contains { $0 < date }
    }

    /// Carte de chaleur annuelle : intensité 0…1 par jour.
    public static func heatmap(
        completionsByDay: [Date: Int],
        from start: Date,
        to end: Date,
        calendar: Calendar = .questly()
    ) -> [HeatmapCell] {
        let normalized = Dictionary(
            completionsByDay.map { (calendar.startOfDay(for: $0.key), $0.value) },
            uniquingKeysWith: { $0 + $1 }
        )
        let maxValue = max(normalized.values.max() ?? 0, 1)
        var cells: [HeatmapCell] = []
        var cursor = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        var guardCounter = 0
        while cursor <= last && guardCounter < 1200 {
            guardCounter += 1
            let count = normalized[cursor] ?? 0
            cells.append(HeatmapCell(
                date: cursor,
                count: count,
                intensity: count == 0 ? 0 : min(1, Double(count) / Double(maxValue))
            ))
            cursor = cursor.adding(days: 1, calendar: calendar)
        }
        return cells
    }
}

public struct HeatmapCell: Identifiable, Equatable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let count: Int
    public let intensity: Double

    public init(date: Date, count: Int, intensity: Double) {
        self.date = date
        self.count = count
        self.intensity = intensity
    }

    /// Niveau discret 0…4, comme la grille de contributions GitHub.
    public var level: Int {
        if count == 0 { return 0 }
        if intensity <= 0.25 { return 1 }
        if intensity <= 0.5 { return 2 }
        if intensity <= 0.75 { return 3 }
        return 4
    }
}
