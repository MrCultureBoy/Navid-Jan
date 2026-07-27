import SwiftUI
import QuestlyKit

// MARK: - Entrée de calendrier

/// Élément affichable sur une timeline, quelle que soit son origine :
/// bloc Questly, quête horodatée, ou évènement du calendrier système.
struct TimedEntry: Identifiable, Equatable {

    enum Source: Equatable {
        case block
        case task
        case external
    }

    let id: String
    let title: String
    let start: Date
    let end: Date
    let colorHex: String
    let source: Source
    let symbolName: String
    /// Identifiant de la quête liée, s'il y en a une.
    let taskIdentifier: UUID?
    let blockIdentifier: UUID?
    let isCompleted: Bool

    var durationMinutes: Int { max(5, Int(end.timeIntervalSince(start) / 60)) }
    var color: Color { Color(hex: colorHex) }

    var isEditable: Bool { source != .external }

    static func from(block: TimeBlock) -> TimedEntry {
        TimedEntry(
            id: "block-\(block.identifier.uuidString)",
            title: block.title.isEmpty ? (block.task?.title ?? "Bloc") : block.title,
            start: block.start,
            end: block.end,
            colorHex: block.colorHex,
            source: .block,
            symbolName: block.task?.isBoss == true ? "crown.fill" : "rectangle.fill",
            taskIdentifier: block.task?.identifier,
            blockIdentifier: block.identifier,
            isCompleted: block.task?.isCompleted ?? false
        )
    }

    static func from(task: TaskItem, defaultMinutes: Int = 30) -> TimedEntry {
        let start = task.dueDate ?? Date()
        let minutes = task.estimatedMinutes > 0 ? task.estimatedMinutes : defaultMinutes
        return TimedEntry(
            id: "task-\(task.identifier.uuidString)",
            title: task.title,
            start: start,
            end: start.addingTimeInterval(TimeInterval(minutes * 60)),
            colorHex: task.lifeArea?.hex ?? task.priority.hex,
            source: .task,
            symbolName: task.isBoss ? "crown.fill" : "checkmark.circle",
            taskIdentifier: task.identifier,
            blockIdentifier: nil,
            isCompleted: task.isCompleted
        )
    }

    static func from(external: CalendarService.ExternalEvent) -> TimedEntry {
        TimedEntry(
            id: "ext-\(external.id)",
            title: external.title,
            start: external.start,
            end: external.end,
            colorHex: external.colorHex,
            source: .external,
            symbolName: "calendar",
            taskIdentifier: nil,
            blockIdentifier: nil,
            isCompleted: false
        )
    }
}

// MARK: - Disposition des chevauchements

/// Place côte à côte les entrées qui se chevauchent, comme le fait
/// Calendar d'Apple : sans ça, une journée chargée devient illisible.
enum TimelineLayout {

    struct Placement: Identifiable, Equatable {
        let entry: TimedEntry
        /// Colonne occupée (0 = la plus à gauche).
        let column: Int
        /// Nombre total de colonnes dans le groupe de chevauchement.
        let columnCount: Int

        var id: String { entry.id }
    }

    static func place(_ entries: [TimedEntry]) -> [Placement] {
        let sorted = entries.sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return lhs.end > rhs.end
        }

        var placements: [Placement] = []
        var cluster: [TimedEntry] = []
        var clusterEnd: Date?

        func flush() {
            guard !cluster.isEmpty else { return }
            placements.append(contentsOf: assignColumns(cluster))
            cluster = []
            clusterEnd = nil
        }

        for entry in sorted {
            if let end = clusterEnd, entry.start >= end {
                flush()
            }
            cluster.append(entry)
            clusterEnd = max(clusterEnd ?? entry.end, entry.end)
        }
        flush()

        return placements
    }

    /// Attribue une colonne à chaque entrée d'un groupe qui se chevauche.
    private static func assignColumns(_ cluster: [TimedEntry]) -> [Placement] {
        var columnEnds: [Date] = []
        var assignments: [(TimedEntry, Int)] = []

        for entry in cluster {
            var placed = false
            for index in columnEnds.indices where columnEnds[index] <= entry.start {
                columnEnds[index] = entry.end
                assignments.append((entry, index))
                placed = true
                break
            }
            if !placed {
                columnEnds.append(entry.end)
                assignments.append((entry, columnEnds.count - 1))
            }
        }

        let total = max(1, columnEnds.count)
        return assignments.map { Placement(entry: $0.0, column: $0.1, columnCount: total) }
    }
}

// MARK: - Géométrie de la timeline

/// Conversions entre minutes et points sur la timeline.
struct TimelineGeometry {
    var hourHeight: CGFloat = Metrics.hourHeight
    var startHour: Int = 0
    var endHour: Int = 24

    var totalHeight: CGFloat {
        CGFloat(endHour - startHour) * hourHeight
    }

    func offset(for date: Date, in day: Date, calendar: Calendar) -> CGFloat {
        let minutes = Double(date.minutesSinceMidnight(calendar: calendar))
        let dayDelta = Double(calendar.daysBetween(day, date)) * 24 * 60
        let total = minutes + dayDelta - Double(startHour * 60)
        return CGFloat(total / 60) * hourHeight
    }

    func height(forMinutes minutes: Int) -> CGFloat {
        max(18, CGFloat(minutes) / 60 * hourHeight)
    }

    /// Instant correspondant à une position verticale, arrondi au pas donné.
    func date(atOffset offset: CGFloat, in day: Date, calendar: Calendar, snapMinutes: Int = 15) -> Date {
        let rawMinutes = Double(offset / hourHeight) * 60 + Double(startHour * 60)
        let clamped = min(max(rawMinutes, 0), 24 * 60 - Double(snapMinutes))
        let snapped = (clamped / Double(snapMinutes)).rounded() * Double(snapMinutes)
        return calendar.startOfDay(for: day).addingTimeInterval(snapped * 60)
    }
}

// MARK: - Mode d'affichage

enum CalendarMode: String, CaseIterable, Identifiable, Hashable {
    case day
    case week
    case month
    case year
    case agenda

    var id: String { rawValue }

    var label: String {
        switch self {
        case .day: return "Jour"
        case .week: return "Semaine"
        case .month: return "Mois"
        case .year: return "Année"
        case .agenda: return "Agenda"
        }
    }

    var symbolName: String {
        switch self {
        case .day: return "rectangle.grid.1x2"
        case .week: return "calendar.day.timeline.left"
        case .month: return "calendar"
        case .year: return "square.grid.3x3"
        case .agenda: return "list.bullet"
        }
    }
}

// MARK: - Densité d'une journée

/// Résumé d'une journée, utilisé par la grille du mois et la vue année.
struct DaySummary: Equatable {
    var taskCount: Int = 0
    var completedCount: Int = 0
    var blockMinutes: Int = 0
    var hasBoss: Bool = false
    var hasOverdue: Bool = false
    var areaHexes: [String] = []

    var isEmpty: Bool { taskCount == 0 && blockMinutes == 0 }

    var completionFraction: Double {
        guard taskCount > 0 else { return 0 }
        return Double(completedCount) / Double(taskCount)
    }

    /// Charge de la journée, 0…1, pour teinter la case du mois.
    func load(capacityMinutes: Int) -> Double {
        guard capacityMinutes > 0 else { return 0 }
        return min(1, Double(blockMinutes) / Double(capacityMinutes))
    }
}
