import Foundation
import XCTest
@testable import QuestlyKit

/// Calendrier figé sur Paris : les tests ne dépendent pas du fuseau de la machine.
let testCalendar: Calendar = .questly(timeZone: TimeZone(identifier: "Europe/Paris") ?? .current)

func makeDate(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int = 0,
    _ minute: Int = 0,
    calendar: Calendar = testCalendar
) -> Date {
    var comps = DateComponents()
    comps.year = year
    comps.month = month
    comps.day = day
    comps.hour = hour
    comps.minute = minute
    comps.second = 0
    guard let date = calendar.date(from: comps) else {
        fatalError("Date de test invalide : \(year)-\(month)-\(day)")
    }
    return date
}

func formatted(_ date: Date, calendar: Calendar = testCalendar) -> String {
    let f = DateFormatter()
    f.calendar = calendar
    f.timeZone = calendar.timeZone
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.string(from: date)
}

func formattedDay(_ date: Date, calendar: Calendar = testCalendar) -> String {
    let f = DateFormatter()
    f.calendar = calendar
    f.timeZone = calendar.timeZone
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
}
