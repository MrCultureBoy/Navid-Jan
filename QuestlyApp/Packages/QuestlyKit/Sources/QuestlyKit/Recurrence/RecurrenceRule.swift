import Foundation

/// Règle de répétition d'une quête.
///
/// Volontairement plus simple qu'une RRULE iCalendar complète, mais elle couvre
/// tout ce qu'une todo-list demande : intervalles, jours de semaine, jour du
/// mois (avec « dernier jour »), fins de série, et le mode « X jours après
/// l'accomplissement » qui manque à la plupart des apps.
public struct RecurrenceRule: Codable, Hashable, Sendable {

    public enum Frequency: String, Codable, CaseIterable, Sendable, Identifiable {
        case daily
        case weekly
        case monthly
        case yearly

        public var id: String { rawValue }

        public var label: String {
            switch self {
            case .daily: return "Jour"
            case .weekly: return "Semaine"
            case .monthly: return "Mois"
            case .yearly: return "Année"
            }
        }

        public var pluralLabel: String {
            switch self {
            case .daily: return "jours"
            case .weekly: return "semaines"
            case .monthly: return "mois"
            case .yearly: return "ans"
            }
        }
    }

    public enum Ending: Codable, Hashable, Sendable {
        case never
        case afterOccurrences(Int)
        case onDate(Date)
    }

    public enum Mode: String, Codable, CaseIterable, Sendable {
        /// Le calendrier fixe commande : rater une occurrence ne décale rien.
        case fixed
        /// La prochaine échéance part de la date d'accomplissement.
        case afterCompletion

        public var label: String {
            switch self {
            case .fixed: return "Date fixe"
            case .afterCompletion: return "Après accomplissement"
            }
        }
    }

    public var frequency: Frequency
    /// Toutes les N unités. Toujours ≥ 1.
    public var interval: Int
    /// 1 = dimanche … 7 = samedi. Vide : on reprend le jour de l'ancre.
    public var weekdays: Set<Int>
    /// 1…31, ou -1 pour « dernier jour du mois ». Vide : jour de l'ancre.
    public var daysOfMonth: Set<Int>
    /// 1…12. Vide : mois de l'ancre (utile en fréquence annuelle).
    public var monthsOfYear: Set<Int>
    public var ending: Ending
    public var mode: Mode
    /// Ignore samedi et dimanche (« en semaine »).
    public var skipWeekends: Bool

    public init(
        frequency: Frequency = .daily,
        interval: Int = 1,
        weekdays: Set<Int> = [],
        daysOfMonth: Set<Int> = [],
        monthsOfYear: Set<Int> = [],
        ending: Ending = .never,
        mode: Mode = .fixed,
        skipWeekends: Bool = false
    ) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.weekdays = weekdays
        self.daysOfMonth = daysOfMonth
        self.monthsOfYear = monthsOfYear
        self.ending = ending
        self.mode = mode
        self.skipWeekends = skipWeekends
    }

    // MARK: Presets

    public static let daily = RecurrenceRule(frequency: .daily)
    public static let weekly = RecurrenceRule(frequency: .weekly)
    public static let monthly = RecurrenceRule(frequency: .monthly)
    public static let yearly = RecurrenceRule(frequency: .yearly)
    public static let weekdaysOnly = RecurrenceRule(frequency: .daily, skipWeekends: true)
    public static let weekendsOnly = RecurrenceRule(frequency: .weekly, weekdays: [1, 7])

    // MARK: Description

    /// Formulation naturelle en français, affichée sur la fiche de quête.
    public func humanDescription(calendar: Calendar = .questly()) -> String {
        var parts: [String] = []

        switch frequency {
        case .daily:
            if skipWeekends {
                parts.append(interval == 1 ? "Chaque jour ouvré" : "Tous les \(interval) jours ouvrés")
            } else {
                parts.append(interval == 1 ? "Chaque jour" : "Tous les \(interval) jours")
            }
        case .weekly:
            let base = interval == 1 ? "Chaque semaine" : "Toutes les \(interval) semaines"
            if weekdays.isEmpty {
                parts.append(base)
            } else {
                parts.append("\(base), le \(Self.weekdayList(weekdays, calendar: calendar))")
            }
        case .monthly:
            let base = interval == 1 ? "Chaque mois" : "Tous les \(interval) mois"
            if daysOfMonth.isEmpty {
                parts.append(base)
            } else if daysOfMonth == [-1] {
                parts.append("\(base), le dernier jour")
            } else {
                let days = daysOfMonth.sorted().map { $0 == -1 ? "dernier" : ($0 == 1 ? "1er" : "\($0)") }
                parts.append("\(base), le \(days.joined(separator: ", "))")
            }
        case .yearly:
            let base = interval == 1 ? "Chaque année" : "Tous les \(interval) ans"
            if monthsOfYear.isEmpty {
                parts.append(base)
            } else {
                let months = monthsOfYear.sorted().map { Self.monthName($0, calendar: calendar) }
                parts.append("\(base), en \(months.joined(separator: ", "))")
            }
        }

        if mode == .afterCompletion {
            parts.append("à partir de l'accomplissement")
        }

        switch ending {
        case .never:
            break
        case .afterOccurrences(let n):
            parts.append("· \(n) fois")
        case .onDate(let date):
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateFormat = "d MMM yyyy"
            parts.append("· jusqu'au \(formatter.string(from: date))")
        }

        return parts.joined(separator: " ")
    }

    static func weekdayList(_ days: Set<Int>, calendar: Calendar) -> String {
        let names = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        let sorted = days.sorted { orderIndex($0, firstWeekday: calendar.firstWeekday) < orderIndex($1, firstWeekday: calendar.firstWeekday) }
        let labels = sorted.compactMap { day -> String? in
            guard day >= 1, day <= 7 else { return nil }
            return names[day - 1]
        }
        if labels.count <= 1 { return labels.first ?? "" }
        return labels.dropLast().joined(separator: ", ") + " et " + (labels.last ?? "")
    }

    static func orderIndex(_ weekday: Int, firstWeekday: Int) -> Int {
        ((weekday - firstWeekday) + 7) % 7
    }

    static func monthName(_ month: Int, calendar: Calendar) -> String {
        let names = ["janvier", "février", "mars", "avril", "mai", "juin",
                     "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
        guard month >= 1, month <= 12 else { return "" }
        return names[month - 1]
    }
}

// MARK: - Engine

public enum RecurrenceEngine {

    /// Nombre maximum de jours balayés pour trouver une occurrence.
    /// 10 ans couvre largement les règles réalistes tout en bornant le coût.
    public static let scanLimitDays = 3_700

    /// Le jour `date` fait-il partie de la série ?
    public static func matches(
        rule: RecurrenceRule,
        date: Date,
        anchor: Date,
        calendar: Calendar = .questly()
    ) -> Bool {
        let day = calendar.startOfDay(for: date)
        let anchorDay = calendar.startOfDay(for: anchor)
        guard day >= anchorDay else { return false }

        if rule.skipWeekends && calendar.isWeekend(day) { return false }

        switch rule.frequency {
        case .daily:
            if rule.skipWeekends {
                // « Tous les N jours ouvrés » : on compte en jours ouvrés.
                guard rule.interval > 1 else { return true }
                let businessDays = businessDayCount(from: anchorDay, to: day, calendar: calendar)
                return businessDays % rule.interval == 0
            }
            let delta = calendar.daysBetween(anchorDay, day)
            return delta % rule.interval == 0

        case .weekly:
            let weekday = calendar.component(.weekday, from: day)
            let targetDays = rule.weekdays.isEmpty
                ? [calendar.component(.weekday, from: anchorDay)]
                : Array(rule.weekdays)
            guard targetDays.contains(weekday) else { return false }
            guard rule.interval > 1 else { return true }
            let anchorWeek = calendar.startOfWeek(anchorDay)
            let currentWeek = calendar.startOfWeek(day)
            let weeks = calendar.daysBetween(anchorWeek, currentWeek) / 7
            return weeks % rule.interval == 0

        case .monthly:
            guard matchesDayOfMonth(rule: rule, day: day, anchorDay: anchorDay, calendar: calendar) else { return false }
            guard rule.interval > 1 else { return true }
            let months = monthCount(from: anchorDay, to: day, calendar: calendar)
            return months % rule.interval == 0

        case .yearly:
            let month = calendar.component(.month, from: day)
            let targetMonths = rule.monthsOfYear.isEmpty
                ? [calendar.component(.month, from: anchorDay)]
                : Array(rule.monthsOfYear)
            guard targetMonths.contains(month) else { return false }
            guard matchesDayOfMonth(rule: rule, day: day, anchorDay: anchorDay, calendar: calendar) else { return false }
            guard rule.interval > 1 else { return true }
            let years = calendar.component(.year, from: day) - calendar.component(.year, from: anchorDay)
            return years % rule.interval == 0
        }
    }

    /// Prochaine occurrence strictement postérieure à `date`.
    public static func nextDate(
        rule: RecurrenceRule,
        after date: Date,
        anchor: Date,
        calendar: Calendar = .questly()
    ) -> Date? {
        if rule.mode == .afterCompletion {
            return nextAfterCompletion(rule: rule, completedAt: date, anchor: anchor, calendar: calendar)
        }

        let anchorTime = calendar.dateComponents([.hour, .minute, .second], from: anchor)
        var cursor = calendar.startOfDay(for: max(date, anchor))
        let occurrencesSeen = countOccurrences(rule: rule, from: anchor, upTo: date, calendar: calendar)

        for _ in 0..<scanLimitDays {
            if matches(rule: rule, date: cursor, anchor: anchor, calendar: calendar) {
                let candidate = calendar.date(
                    bySettingHour: anchorTime.hour ?? 0,
                    minute: anchorTime.minute ?? 0,
                    second: anchorTime.second ?? 0,
                    of: cursor
                ) ?? cursor

                if candidate > date {
                    switch rule.ending {
                    case .never:
                        return candidate
                    case .onDate(let end):
                        return candidate <= calendar.endOfDay(end) ? candidate : nil
                    case .afterOccurrences(let limit):
                        return occurrencesSeen < limit ? candidate : nil
                    }
                }
            }
            cursor = cursor.adding(days: 1, calendar: calendar)

            if case .onDate(let end) = rule.ending, cursor > calendar.endOfDay(end) {
                return nil
            }
        }
        return nil
    }

    /// Toutes les occurrences dans un intervalle — utilisé par le calendrier
    /// pour afficher les répétitions sans les matérialiser en base.
    ///
    /// - Important: `start` et `end` sont des instants précis, pas des jours.
    ///   Une occurrence à 9 h le 20 mars n'est pas incluse si `end` vaut
    ///   « 20 mars 00:00 » ; passer `calendar.endOfDay(...)` pour raisonner
    ///   en journées entières.
    public static func occurrences(
        rule: RecurrenceRule,
        anchor: Date,
        from start: Date,
        to end: Date,
        calendar: Calendar = .questly(),
        limit: Int = 500
    ) -> [Date] {
        guard end >= start else { return [] }
        let anchorTime = calendar.dateComponents([.hour, .minute, .second], from: anchor)
        var results: [Date] = []
        var cursor = calendar.startOfDay(for: max(start, anchor))
        let lastDay = calendar.startOfDay(for: end)
        var index = countOccurrences(rule: rule, from: anchor, upTo: cursor.addingTimeInterval(-1), calendar: calendar)
        var guardCounter = 0

        while cursor <= lastDay && results.count < limit && guardCounter < scanLimitDays {
            guardCounter += 1
            if matches(rule: rule, date: cursor, anchor: anchor, calendar: calendar) {
                if case .afterOccurrences(let maxCount) = rule.ending, index >= maxCount { break }
                if case .onDate(let endDate) = rule.ending, cursor > calendar.endOfDay(endDate) { break }
                let occurrence = calendar.date(
                    bySettingHour: anchorTime.hour ?? 0,
                    minute: anchorTime.minute ?? 0,
                    second: anchorTime.second ?? 0,
                    of: cursor
                ) ?? cursor
                if occurrence >= start && occurrence <= end {
                    results.append(occurrence)
                }
                index += 1
            }
            cursor = cursor.adding(days: 1, calendar: calendar)
        }
        return results
    }

    /// Mode « après accomplissement » : on repart de la date de validation.
    static func nextAfterCompletion(
        rule: RecurrenceRule,
        completedAt: Date,
        anchor: Date,
        calendar: Calendar = .questly()
    ) -> Date? {
        let component: Calendar.Component
        switch rule.frequency {
        case .daily: component = .day
        case .weekly: component = .weekOfYear
        case .monthly: component = .month
        case .yearly: component = .year
        }
        guard var next = calendar.date(byAdding: component, value: rule.interval, to: completedAt) else { return nil }

        if rule.skipWeekends {
            var guardCounter = 0
            while calendar.isWeekend(next) && guardCounter < 7 {
                guardCounter += 1
                next = next.adding(days: 1, calendar: calendar)
            }
        }

        // On conserve l'heure de l'ancre pour ne pas faire dériver le rappel.
        let anchorTime = calendar.dateComponents([.hour, .minute, .second], from: anchor)
        next = calendar.date(
            bySettingHour: anchorTime.hour ?? 0,
            minute: anchorTime.minute ?? 0,
            second: anchorTime.second ?? 0,
            of: next
        ) ?? next

        if case .onDate(let end) = rule.ending, next > calendar.endOfDay(end) { return nil }
        return next
    }

    /// Nombre d'occurrences déjà survenues entre l'ancre et `date` incluse.
    public static func countOccurrences(
        rule: RecurrenceRule,
        from anchor: Date,
        upTo date: Date,
        calendar: Calendar = .questly()
    ) -> Int {
        guard date >= anchor else { return 0 }
        let anchorTime = calendar.dateComponents([.hour, .minute, .second], from: anchor)
        var count = 0
        var cursor = calendar.startOfDay(for: anchor)
        let lastDay = calendar.startOfDay(for: date)
        var guardCounter = 0
        while cursor <= lastDay && guardCounter < scanLimitDays {
            guardCounter += 1
            if matches(rule: rule, date: cursor, anchor: anchor, calendar: calendar) {
                let occurrence = calendar.date(
                    bySettingHour: anchorTime.hour ?? 0,
                    minute: anchorTime.minute ?? 0,
                    second: anchorTime.second ?? 0,
                    of: cursor
                ) ?? cursor
                if occurrence <= date { count += 1 }
            }
            cursor = cursor.adding(days: 1, calendar: calendar)
        }
        return count
    }

    // MARK: Helpers

    static func matchesDayOfMonth(
        rule: RecurrenceRule,
        day: Date,
        anchorDay: Date,
        calendar: Calendar
    ) -> Bool {
        let dayNumber = calendar.component(.day, from: day)
        let daysInMonth = calendar.numberOfDaysInMonth(day)

        let targets: [Int]
        if rule.daysOfMonth.isEmpty {
            targets = [calendar.component(.day, from: anchorDay)]
        } else {
            targets = Array(rule.daysOfMonth)
        }

        for target in targets {
            if target == -1 {
                if dayNumber == daysInMonth { return true }
                continue
            }
            if target == dayNumber { return true }
            // Report sur le dernier jour quand le mois est trop court
            // (le 31 devient le 28/29 février).
            if target > daysInMonth && dayNumber == daysInMonth { return true }
        }
        return false
    }

    static func monthCount(from start: Date, to end: Date, calendar: Calendar) -> Int {
        let comps = calendar.dateComponents([.month], from: calendar.startOfMonth(start), to: calendar.startOfMonth(end))
        return abs(comps.month ?? 0)
    }

    static func businessDayCount(from start: Date, to end: Date, calendar: Calendar) -> Int {
        guard end > start else { return 0 }
        var count = 0
        var cursor = start
        var guardCounter = 0
        while cursor < end && guardCounter < scanLimitDays {
            guardCounter += 1
            cursor = cursor.adding(days: 1, calendar: calendar)
            if !calendar.isWeekend(cursor) { count += 1 }
        }
        return count
    }
}
