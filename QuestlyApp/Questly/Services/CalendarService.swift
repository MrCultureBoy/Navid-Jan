import Foundation
import EventKit
import SwiftUI
import QuestlyKit

/// Pont avec le calendrier système.
///
/// Les évènements iOS sont affichés en lecture seule dans la timeline, ce qui
/// rend la planification honnête : on ne peut pas bloquer un créneau déjà pris.
/// L'écriture est possible à la demande, pour pousser un bloc vers Apple
/// Calendar.
@MainActor
@Observable
final class CalendarService {

    struct ExternalEvent: Identifiable, Equatable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let isAllDay: Bool
        let colorHex: String
        let calendarName: String

        var durationMinutes: Int { max(0, Int(end.timeIntervalSince(start) / 60)) }

        var busyInterval: BusyInterval {
            BusyInterval(id: id, start: start, end: end, title: title)
        }
    }

    enum Access {
        case unknown
        case granted
        case denied
    }

    private(set) var access: Access = .unknown
    private(set) var events: [ExternalEvent] = []
    private(set) var lastError: String?

    private let store = EKEventStore()

    // MARK: Autorisation

    func refreshAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess:
            access = .granted
        case .writeOnly:
            access = .granted
        case .denied, .restricted:
            access = .denied
        default:
            access = .unknown
        }
    }

    @discardableResult
    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            access = granted ? .granted : .denied
            return granted
        } catch {
            lastError = error.localizedDescription
            access = .denied
            return false
        }
    }

    // MARK: Lecture

    /// Charge les évènements d'une plage. Appelé quand le calendrier change de
    /// période affichée.
    func load(from start: Date, to end: Date) {
        guard access == .granted else {
            events = []
            return
        }
        let calendars = store.calendars(for: .event)
        guard !calendars.isEmpty else {
            events = []
            return
        }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let found = store.events(matching: predicate)

        events = found.compactMap { event in
            guard let identifier = event.eventIdentifier,
                  let startDate = event.startDate,
                  let endDate = event.endDate else { return nil }
            return ExternalEvent(
                id: identifier + "-" + String(startDate.timeIntervalSince1970),
                title: event.title ?? "Évènement",
                start: startDate,
                end: endDate,
                isAllDay: event.isAllDay,
                colorHex: Self.hex(from: event.calendar),
                calendarName: event.calendar?.title ?? ""
            )
        }
        .sorted { $0.start < $1.start }
    }

    func events(on day: Date, calendar: Calendar = .questly()) -> [ExternalEvent] {
        events.filter { calendar.isSameDay($0.start, day) }
    }

    func busyIntervals(on day: Date, calendar: Calendar = .questly()) -> [BusyInterval] {
        events(on: day, calendar: calendar)
            .filter { !$0.isAllDay }
            .map(\.busyInterval)
    }

    // MARK: Écriture

    /// Pousse un bloc Questly vers le calendrier système.
    @discardableResult
    func export(block: TimeBlock, calendarTitle: String = "Questly") -> String? {
        guard access == .granted else { return nil }
        let event = EKEvent(eventStore: store)
        event.title = block.title
        event.startDate = block.start
        event.endDate = block.end
        event.notes = block.notes.isEmpty ? nil : block.notes
        event.calendar = store.defaultCalendarForNewEvents ?? store.calendars(for: .event).first

        do {
            try store.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func removeExportedEvent(identifier: String) {
        guard access == .granted, let event = store.event(withIdentifier: identifier) else { return }
        try? store.remove(event, span: .thisEvent)
    }

    // MARK: Outils

    static func hex(from calendar: EKCalendar?) -> String {
        guard let cgColor = calendar?.cgColor else { return "5E5CE6" }
        #if canImport(UIKit)
        let color = UIColor(cgColor: cgColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "%02X%02X%02X",
            Int(red * 255), Int(green * 255), Int(blue * 255)
        )
        #else
        return "5E5CE6"
        #endif
    }
}
