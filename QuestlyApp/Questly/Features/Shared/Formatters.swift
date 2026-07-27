import Foundation
import QuestlyKit

/// Mise en forme des dates dans le vocabulaire de l'app : relatif quand c'est
/// utile, absolu quand c'est nécessaire, jamais les deux à la fois.
enum QuestlyFormat {

    static let locale = Locale(identifier: "fr_FR")

    private static func formatter(_ format: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateFormat = format
        return formatter
    }

    /// « 14:30 »
    static func time(_ date: Date, calendar: Calendar = .questly()) -> String {
        formatter("HH:mm", calendar: calendar).string(from: date)
    }

    /// « lun. 9 mars »
    static func mediumDate(_ date: Date, calendar: Calendar = .questly()) -> String {
        formatter("EEE d MMM", calendar: calendar).string(from: date)
    }

    /// « 9 mars 2026 »
    static func longDate(_ date: Date, calendar: Calendar = .questly()) -> String {
        formatter("d MMMM yyyy", calendar: calendar).string(from: date)
    }

    /// « mars 2026 »
    static func monthYear(_ date: Date, calendar: Calendar = .questly()) -> String {
        formatter("MMMM yyyy", calendar: calendar).string(from: date).capitalizedFirstLetter
    }

    /// « mars »
    static func month(_ date: Date, calendar: Calendar = .questly()) -> String {
        formatter("MMMM", calendar: calendar).string(from: date).capitalizedFirstLetter
    }

    /// « lun. »
    static func weekdayShort(_ date: Date, calendar: Calendar = .questly()) -> String {
        formatter("EEE", calendar: calendar).string(from: date)
    }

    /// « L » — initiale du jour, pour les en-têtes compacts du calendrier.
    static func weekdayInitial(_ date: Date, calendar: Calendar = .questly()) -> String {
        let text = formatter("EEEEE", calendar: calendar).string(from: date)
        return text.uppercased()
    }

    /// « lundi 9 mars »
    static func fullDay(_ date: Date, calendar: Calendar = .questly()) -> String {
        formatter("EEEE d MMMM", calendar: calendar).string(from: date).capitalizedFirstLetter
    }

    static func dayNumber(_ date: Date, calendar: Calendar = .questly()) -> String {
        String(calendar.component(.day, from: date))
    }

    /// Étiquette d'échéance affichée sur une ligne de quête.
    static func dueLabel(
        for date: Date,
        hasTime: Bool,
        now: Date = Date(),
        calendar: Calendar = .questly()
    ) -> String {
        let delta = calendar.daysBetween(now, date)
        let dayPart: String

        switch delta {
        case 0: dayPart = "Aujourd'hui"
        case 1: dayPart = "Demain"
        case -1: dayPart = "Hier"
        case 2...6: dayPart = weekdayShort(date, calendar: calendar).capitalizedFirstLetter
        case -6...(-2): dayPart = "Il y a \(-delta) j"
        default: dayPart = mediumDate(date, calendar: calendar)
        }

        guard hasTime else { return dayPart }
        return "\(dayPart) · \(time(date, calendar: calendar))"
    }

    /// « En retard de 3 jours »
    static func overdueLabel(
        for date: Date,
        now: Date = Date(),
        calendar: Calendar = .questly()
    ) -> String {
        let days = calendar.daysBetween(date, now)
        if days <= 0 { return "En retard" }
        if days == 1 { return "En retard d'un jour" }
        return "En retard de \(days) jours"
    }

    /// Salutation adaptée à l'heure.
    static func greeting(for date: Date = Date(), calendar: Calendar = .questly()) -> String {
        switch calendar.component(.hour, from: date) {
        case 0..<5: return "Bonne nuit"
        case 5..<12: return "Bonjour"
        case 12..<18: return "Bon après-midi"
        case 18..<23: return "Bonsoir"
        default: return "Bonne nuit"
        }
    }

    /// Nombre compact : 1 240 → « 1,2 k »
    static func compactNumber(_ value: Int) -> String {
        if value < 1000 { return "\(value)" }
        if value < 1_000_000 {
            let thousands = Double(value) / 1000
            return String(format: "%.1f k", thousands).replacingOccurrences(of: ".", with: ",")
        }
        let millions = Double(value) / 1_000_000
        return String(format: "%.1f M", millions).replacingOccurrences(of: ".", with: ",")
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded())) %"
    }
}
