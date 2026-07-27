import Foundation

// MARK: - Types

public struct TimeSlot: Identifiable, Equatable, Sendable {
    public let start: Date
    public let end: Date

    public var id: String { "\(start.timeIntervalSince1970)-\(end.timeIntervalSince1970)" }
    public var minutes: Int { max(0, Int(end.timeIntervalSince(start) / 60)) }

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public func overlaps(_ other: TimeSlot) -> Bool {
        start < other.end && other.start < end
    }
}

public struct BusyInterval: Identifiable, Equatable, Sendable {
    public let id: String
    public let start: Date
    public let end: Date
    public let title: String

    public init(id: String = UUID().uuidString, start: Date, end: Date, title: String = "") {
        self.id = id
        self.start = start
        self.end = end
        self.title = title
    }
}

/// Plage de travail par défaut de l'utilisateur.
public struct WorkingHours: Equatable, Sendable, Codable {
    /// Minutes depuis minuit.
    public var startMinute: Int
    public var endMinute: Int
    /// Jours travaillés (1 = dimanche … 7 = samedi).
    public var weekdays: Set<Int>
    /// Fenêtre de pointe où l'énergie est au maximum.
    public var peakStartMinute: Int
    public var peakEndMinute: Int

    public init(
        startMinute: Int = 9 * 60,
        endMinute: Int = 18 * 60,
        weekdays: Set<Int> = [2, 3, 4, 5, 6],
        peakStartMinute: Int = 9 * 60,
        peakEndMinute: Int = 12 * 60
    ) {
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.weekdays = weekdays
        self.peakStartMinute = peakStartMinute
        self.peakEndMinute = peakEndMinute
    }

    public static let `default` = WorkingHours()

    public func isWorkingDay(_ date: Date, calendar: Calendar) -> Bool {
        weekdays.contains(calendar.component(.weekday, from: date))
    }
}

/// Une tâche candidate à la planification automatique.
public struct PlannableTask: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let estimatedMinutes: Int
    public let priority: Priority
    public let difficulty: Difficulty
    public let energy: EnergyLevel
    public let dueDate: Date?
    public let isBoss: Bool

    public init(
        id: String,
        title: String,
        estimatedMinutes: Int,
        priority: Priority = .p4,
        difficulty: Difficulty = .medium,
        energy: EnergyLevel = .medium,
        dueDate: Date? = nil,
        isBoss: Bool = false
    ) {
        self.id = id
        self.title = title
        self.estimatedMinutes = max(5, estimatedMinutes)
        self.priority = priority
        self.difficulty = difficulty
        self.energy = energy
        self.dueDate = dueDate
        self.isBoss = isBoss
    }
}

public struct PlannedBlock: Identifiable, Equatable, Sendable {
    public let id: String
    public let taskID: String
    public let title: String
    public let start: Date
    public let end: Date
    /// Explication affichée à l'utilisateur (« placé au pic d'énergie »).
    public let rationale: String

    public init(taskID: String, title: String, start: Date, end: Date, rationale: String) {
        self.id = "\(taskID)-\(start.timeIntervalSince1970)"
        self.taskID = taskID
        self.title = title
        self.start = start
        self.end = end
        self.rationale = rationale
    }
}

public struct PlanResult: Equatable, Sendable {
    public let blocks: [PlannedBlock]
    public let unplaced: [PlannableTask]
    public let usedMinutes: Int
    public let freeMinutes: Int

    public init(blocks: [PlannedBlock], unplaced: [PlannableTask], usedMinutes: Int, freeMinutes: Int) {
        self.blocks = blocks
        self.unplaced = unplaced
        self.usedMinutes = usedMinutes
        self.freeMinutes = freeMinutes
    }
}

// MARK: - Engine

/// Trouve les trous dans une journée et y range les quêtes intelligemment.
public enum ScheduleEngine {

    /// Fusionne les occupations qui se chevauchent.
    public static func merge(_ intervals: [BusyInterval]) -> [TimeSlot] {
        let sorted = intervals
            .filter { $0.end > $0.start }
            .sorted { $0.start < $1.start }
        var merged: [TimeSlot] = []
        for interval in sorted {
            if let last = merged.last, interval.start <= last.end {
                if interval.end > last.end {
                    merged[merged.count - 1] = TimeSlot(start: last.start, end: interval.end)
                }
            } else {
                merged.append(TimeSlot(start: interval.start, end: interval.end))
            }
        }
        return merged
    }

    /// Créneaux libres d'une journée, dans les heures de travail.
    public static func freeSlots(
        on day: Date,
        busy: [BusyInterval],
        workingHours: WorkingHours = .default,
        minimumMinutes: Int = 15,
        bufferMinutes: Int = 0,
        notBefore: Date? = nil,
        calendar: Calendar = .questly()
    ) -> [TimeSlot] {
        let dayStart = calendar.startOfDay(for: day)
        var windowStart = dayStart.adding(minutes: workingHours.startMinute)
        let windowEnd = dayStart.adding(minutes: workingHours.endMinute)

        if let notBefore, notBefore > windowStart, calendar.isSameDay(notBefore, day) {
            windowStart = notBefore
        }
        guard windowEnd > windowStart else { return [] }

        let occupied = merge(busy.filter { $0.end > windowStart && $0.start < windowEnd })
        var slots: [TimeSlot] = []
        var cursor = windowStart

        for block in occupied {
            let blockStart = max(block.start, windowStart)
            if blockStart > cursor {
                let end = min(blockStart, windowEnd).addingTimeInterval(TimeInterval(-bufferMinutes * 60))
                if end > cursor {
                    slots.append(TimeSlot(start: cursor, end: end))
                }
            }
            cursor = max(cursor, min(block.end, windowEnd).addingTimeInterval(TimeInterval(bufferMinutes * 60)))
        }

        if cursor < windowEnd {
            slots.append(TimeSlot(start: cursor, end: windowEnd))
        }

        return slots.filter { $0.minutes >= minimumMinutes }
    }

    /// Range les tâches dans les trous de la journée.
    ///
    /// Heuristique : échéance la plus proche d'abord, puis priorité, puis
    /// difficulté. Les tâches exigeantes visent la fenêtre de pointe ; les
    /// petites tâches bouchent les trous restants.
    public static func autoPlan(
        tasks: [PlannableTask],
        on day: Date,
        busy: [BusyInterval],
        workingHours: WorkingHours = .default,
        bufferMinutes: Int = 5,
        notBefore: Date? = nil,
        calendar: Calendar = .questly()
    ) -> PlanResult {
        var slots = freeSlots(
            on: day,
            busy: busy,
            workingHours: workingHours,
            minimumMinutes: 10,
            bufferMinutes: 0,
            notBefore: notBefore,
            calendar: calendar
        )
        let totalFree = slots.reduce(0) { $0 + $1.minutes }

        let ordered = tasks.sorted(by: rankTasks)
        var blocks: [PlannedBlock] = []
        var unplaced: [PlannableTask] = []
        var used = 0

        let dayStart = calendar.startOfDay(for: day)
        let peakStart = dayStart.adding(minutes: workingHours.peakStartMinute)
        let peakEnd = dayStart.adding(minutes: workingHours.peakEndMinute)

        for task in ordered {
            let needed = task.estimatedMinutes
            let wantsPeak = task.energy == .high || task.difficulty.rawValue >= Difficulty.hard.rawValue || task.isBoss

            // On cherche d'abord un créneau dans la fenêtre de pointe.
            var chosenIndex: Int?
            if wantsPeak {
                chosenIndex = slots.firstIndex { slot in
                    slot.minutes >= needed && slot.start < peakEnd && slot.end > peakStart
                }
            }
            if chosenIndex == nil {
                chosenIndex = slots.firstIndex { $0.minutes >= needed }
            }

            guard let index = chosenIndex else {
                unplaced.append(task)
                continue
            }

            let slot = slots[index]
            var start = slot.start
            if wantsPeak, slot.start < peakStart, slot.end >= peakStart.addingTimeInterval(TimeInterval(needed * 60)) {
                start = peakStart
            }
            let end = start.addingTimeInterval(TimeInterval(needed * 60))

            blocks.append(PlannedBlock(
                taskID: task.id,
                title: task.title,
                start: start,
                end: end,
                rationale: rationale(for: task, start: start, peakStart: peakStart, peakEnd: peakEnd)
            ))
            used += needed

            // On reconstruit les morceaux de créneau restants.
            var replacements: [TimeSlot] = []
            if start > slot.start {
                replacements.append(TimeSlot(start: slot.start, end: start))
            }
            let resumeAt = end.addingTimeInterval(TimeInterval(bufferMinutes * 60))
            if resumeAt < slot.end {
                replacements.append(TimeSlot(start: resumeAt, end: slot.end))
            }
            slots.remove(at: index)
            slots.insert(contentsOf: replacements.filter { $0.minutes >= 10 }, at: index)
            slots.sort { $0.start < $1.start }
        }

        return PlanResult(
            blocks: blocks.sorted { $0.start < $1.start },
            unplaced: unplaced,
            usedMinutes: used,
            freeMinutes: max(0, totalFree - used)
        )
    }

    static func rankTasks(_ a: PlannableTask, _ b: PlannableTask) -> Bool {
        // 1. Échéance
        switch (a.dueDate, b.dueDate) {
        case (let x?, let y?) where x != y:
            return x < y
        case (nil, .some):
            return false
        case (.some, nil):
            return true
        default:
            break
        }
        // 2. Priorité
        if a.priority != b.priority { return a.priority.urgencyScore > b.priority.urgencyScore }
        // 3. Boss d'abord
        if a.isBoss != b.isBoss { return a.isBoss }
        // 4. Difficulté décroissante : on attaque le gros le matin.
        if a.difficulty != b.difficulty { return a.difficulty.rawValue > b.difficulty.rawValue }
        // 5. Stabilité
        return a.id < b.id
    }

    static func rationale(for task: PlannableTask, start: Date, peakStart: Date, peakEnd: Date) -> String {
        if start >= peakStart && start < peakEnd {
            if task.isBoss { return "Boss placé au pic d'énergie" }
            if task.energy == .high { return "Tâche exigeante au pic d'énergie" }
            return "Placée au meilleur moment"
        }
        if let due = task.dueDate {
            let calendar = Calendar.questly()
            if calendar.isSameDay(due, start) { return "À rendre aujourd'hui" }
        }
        if task.priority == .p1 { return "Priorité critique" }
        return "Comble un créneau libre"
    }

    /// Suggère les 3 meilleurs créneaux pour une durée donnée, sur plusieurs jours.
    public static func suggestSlots(
        forMinutes minutes: Int,
        startingFrom date: Date,
        days: Int = 7,
        busyByDay: [Date: [BusyInterval]],
        workingHours: WorkingHours = .default,
        limit: Int = 3,
        calendar: Calendar = .questly()
    ) -> [TimeSlot] {
        var suggestions: [TimeSlot] = []
        for offset in 0..<max(1, days) {
            let day = calendar.startOfDay(for: date.adding(days: offset, calendar: calendar))
            guard workingHours.isWorkingDay(day, calendar: calendar) else { continue }
            let busy = busyByDay[day] ?? []
            let slots = freeSlots(
                on: day,
                busy: busy,
                workingHours: workingHours,
                minimumMinutes: minutes,
                bufferMinutes: 0,
                notBefore: offset == 0 ? date : nil,
                calendar: calendar
            )
            for slot in slots {
                suggestions.append(TimeSlot(
                    start: slot.start,
                    end: slot.start.addingTimeInterval(TimeInterval(minutes * 60))
                ))
                if suggestions.count >= limit { return suggestions }
            }
        }
        return suggestions
    }

    /// Détecte les journées surchargées : plus de tâches planifiées que d'heures.
    public static func workloadRatio(
        plannedMinutes: Int,
        workingHours: WorkingHours = .default
    ) -> Double {
        let capacity = max(1, workingHours.endMinute - workingHours.startMinute)
        return Double(plannedMinutes) / Double(capacity)
    }
}
