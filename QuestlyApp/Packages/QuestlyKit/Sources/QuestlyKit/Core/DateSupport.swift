import Foundation

/// Abstraction de l'horloge pour rendre toute la logique testable.
public protocol DateProviding: Sendable {
    var now: Date { get }
}

public struct SystemDateProvider: DateProviding {
    public init() {}
    public var now: Date { Date() }
}

/// Horloge figée, utilisée par les tests et les aperçus SwiftUI.
public struct FixedDateProvider: DateProviding {
    public let now: Date
    public init(_ now: Date) { self.now = now }
}

// MARK: - Calendar helpers

public extension Calendar {
    /// Calendrier grégorien stable (UTC-agnostique) pour les calculs déterministes.
    static func questly(timeZone: TimeZone = .current, firstWeekday: Int = 2) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        cal.firstWeekday = firstWeekday
        cal.minimumDaysInFirstWeek = 4
        return cal
    }

    func startOfDay(_ date: Date) -> Date { startOfDay(for: date) }

    func endOfDay(_ date: Date) -> Date {
        self.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay(for: date)) ?? date
    }

    func startOfWeek(_ date: Date) -> Date {
        let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: comps) ?? startOfDay(for: date)
    }

    func endOfWeek(_ date: Date) -> Date {
        let start = startOfWeek(date)
        return self.date(byAdding: DateComponents(day: 7, second: -1), to: start) ?? date
    }

    func startOfMonth(_ date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? startOfDay(for: date)
    }

    func endOfMonth(_ date: Date) -> Date {
        let start = startOfMonth(date)
        return self.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? date
    }

    func startOfYear(_ date: Date) -> Date {
        let comps = dateComponents([.year], from: date)
        return self.date(from: comps) ?? startOfDay(for: date)
    }

    func daysBetween(_ from: Date, _ to: Date) -> Int {
        let a = startOfDay(for: from)
        let b = startOfDay(for: to)
        return dateComponents([.day], from: a, to: b).day ?? 0
    }

    func isSameDay(_ a: Date, _ b: Date) -> Bool {
        isDate(a, inSameDayAs: b)
    }

    func numberOfDaysInMonth(_ date: Date) -> Int {
        range(of: .day, in: .month, for: date)?.count ?? 30
    }

    func isWeekend(_ date: Date) -> Bool {
        let weekday = component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    /// Applique une heure/minute à une date en conservant son jour.
    func setting(hour: Int, minute: Int, of date: Date) -> Date {
        self.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    /// Grille de 42 jours (6 semaines) affichée par la vue Mois.
    func monthGrid(for date: Date) -> [Date] {
        let first = startOfMonth(date)
        let gridStart = startOfWeek(first)
        return (0..<42).compactMap { self.date(byAdding: .day, value: $0, to: gridStart) }
    }

    /// Les 7 jours de la semaine contenant `date`.
    func weekDays(for date: Date) -> [Date] {
        let start = startOfWeek(date)
        return (0..<7).compactMap { self.date(byAdding: .day, value: $0, to: start) }
    }
}

// MARK: - Date helpers

public extension Date {
    func adding(days: Int, calendar: Calendar = .questly()) -> Date {
        calendar.date(byAdding: .day, value: days, to: self) ?? self
    }

    func adding(minutes: Int) -> Date {
        addingTimeInterval(TimeInterval(minutes) * 60)
    }

    /// Minutes écoulées depuis minuit — sert à positionner les blocs sur la timeline.
    func minutesSinceMidnight(calendar: Calendar = .questly()) -> Int {
        let comps = calendar.dateComponents([.hour, .minute], from: self)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}

// MARK: - Time interval formatting

public enum DurationFormatter {
    /// « 1 h 30 », « 45 min », « 2 h ».
    public static func short(minutes: Int) -> String {
        guard minutes > 0 else { return "—" }
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h) h" }
        return "\(h) h \(m)"
    }

    /// « 01:23:45 » pour le chronomètre de concentration.
    public static func clock(seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%02d:%02d", m, sec)
    }
}
