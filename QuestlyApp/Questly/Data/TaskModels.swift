import Foundation
import SwiftData
import QuestlyKit

// MARK: - Quête

/// Une quête : l'unité de base de l'app. Le vocabulaire du jeu remplace
/// « tâche » côté interface, mais le modèle reste une todo classique enrichie.
///
/// Toutes les propriétés ont une valeur par défaut et aucune contrainte
/// d'unicité n'est déclarée : c'est la condition pour que la synchronisation
/// iCloud (CloudKit) puisse être activée sans migration.
@Model
final class TaskItem {

    var identifier: UUID = UUID()
    var title: String = ""
    var notes: String = ""

    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var dueDate: Date?
    var startDate: Date?
    var completedAt: Date?

    /// `false` = échéance « toute la journée ».
    var hasTime: Bool = false
    var estimatedMinutes: Int = 0
    var focusedMinutes: Int = 0

    var priorityRaw: Int = Priority.p4.rawValue
    var difficultyRaw: Int = Difficulty.medium.rawValue
    var energyRaw: Int = EnergyLevel.medium.rawValue
    var statusRaw: Int = TaskStatus.inbox.rawValue
    var lifeAreaRaw: String?

    var isBoss: Bool = false
    var isFlagged: Bool = false
    /// Position manuelle dans les listes réordonnables.
    var sortIndex: Double = 0

    /// Règle de répétition encodée en JSON : robuste et indépendant du schéma.
    var recurrenceData: Data?
    /// Point de départ de la série, figé à la création.
    var recurrenceAnchor: Date?
    /// Nombre de fois où la quête récurrente a déjà été bouclée.
    var recurrenceCount: Int = 0

    var reminderMinutesBefore: Int?
    /// XP réellement gagné au moment de la validation.
    var earnedXP: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \Subtask.task)
    var subtasks: [Subtask]? = []

    @Relationship(deleteRule: .cascade, inverse: \TimeBlock.task)
    var blocks: [TimeBlock]? = []

    var project: Project?
    var tags: [Tag]? = []

    init(
        title: String = "",
        notes: String = "",
        dueDate: Date? = nil,
        hasTime: Bool = false,
        estimatedMinutes: Int = 0,
        priority: Priority = .p4,
        difficulty: Difficulty = .medium,
        energy: EnergyLevel = .medium,
        status: TaskStatus = .inbox,
        lifeArea: LifeArea? = nil,
        isBoss: Bool = false,
        project: Project? = nil
    ) {
        self.identifier = UUID()
        self.title = title
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.dueDate = dueDate
        self.hasTime = hasTime
        self.estimatedMinutes = estimatedMinutes
        self.priorityRaw = priority.rawValue
        self.difficultyRaw = difficulty.rawValue
        self.energyRaw = energy.rawValue
        self.statusRaw = status.rawValue
        self.lifeAreaRaw = lifeArea?.rawValue
        self.isBoss = isBoss
        self.project = project
        self.sortIndex = Date().timeIntervalSince1970
    }
}

// MARK: - Accesseurs typés

extension TaskItem {

    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .p4 }
        set { priorityRaw = newValue.rawValue }
    }

    var difficulty: Difficulty {
        get { Difficulty(rawValue: difficultyRaw) ?? .medium }
        set { difficultyRaw = newValue.rawValue }
    }

    var energy: EnergyLevel {
        get { EnergyLevel(rawValue: energyRaw) ?? .medium }
        set { energyRaw = newValue.rawValue }
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .inbox }
        set { statusRaw = newValue.rawValue }
    }

    var lifeArea: LifeArea? {
        get { lifeAreaRaw.flatMap { LifeArea(rawValue: $0) } }
        set { lifeAreaRaw = newValue?.rawValue }
    }

    var recurrence: RecurrenceRule? {
        get {
            guard let recurrenceData else { return nil }
            return try? JSONDecoder().decode(RecurrenceRule.self, from: recurrenceData)
        }
        set {
            recurrenceData = newValue.flatMap { try? JSONEncoder().encode($0) }
            if newValue != nil && recurrenceAnchor == nil {
                recurrenceAnchor = dueDate ?? Date()
            }
            if newValue == nil {
                recurrenceAnchor = nil
            }
        }
    }

    var isRecurring: Bool { recurrenceData != nil }

    var orderedSubtasks: [Subtask] {
        (subtasks ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    var sortedTags: [Tag] {
        (tags ?? []).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var scheduledBlocks: [TimeBlock] {
        (blocks ?? []).sorted { $0.start < $1.start }
    }

    var isCompleted: Bool { status == .completed }
    var isOpen: Bool { status.isOpen }

    var completedSubtaskCount: Int { orderedSubtasks.filter(\.isDone).count }

    /// Avancement basé sur les sous-quêtes, sinon 0 ou 1.
    var progress: Double {
        let all = orderedSubtasks
        guard !all.isEmpty else { return isCompleted ? 1 : 0 }
        return Double(all.filter(\.isDone).count) / Double(all.count)
    }

    func isOverdue(now: Date = Date(), calendar: Calendar = .questly()) -> Bool {
        guard isOpen, let dueDate else { return false }
        if hasTime { return dueDate < now }
        return calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: now)
    }

    func isDue(on day: Date, calendar: Calendar = .questly()) -> Bool {
        guard let dueDate else { return false }
        return calendar.isSameDay(dueDate, day)
    }

    func isDueToday(now: Date = Date(), calendar: Calendar = .questly()) -> Bool {
        isDue(on: now, calendar: calendar)
    }

    /// Descripteur consommé par le moteur d'XP.
    func xpDescriptor() -> XPTaskDescriptor {
        XPTaskDescriptor(
            difficulty: difficulty,
            priority: priority,
            estimatedMinutes: estimatedMinutes > 0 ? estimatedMinutes : nil,
            completedSubtaskCount: completedSubtaskCount,
            totalSubtaskCount: orderedSubtasks.count,
            dueDate: dueDate,
            hasTimeComponent: hasTime,
            isBoss: isBoss,
            lifeArea: lifeArea,
            focusedMinutes: focusedMinutes,
            isHabit: isRecurring
        )
    }

    /// XP annoncé sur la fiche, avant validation.
    var previewXP: Int {
        XPEngine.previewXP(for: xpDescriptor())
    }

    /// Points de vie du boss, en minutes de concentration restantes.
    var bossRemainingHP: Int {
        max(0, difficulty.bossHitPoints - focusedMinutes)
    }

    var bossHealthFraction: Double {
        let total = Double(difficulty.bossHitPoints)
        guard total > 0 else { return 0 }
        return max(0, min(1, Double(bossRemainingHP) / total))
    }

    func touch() {
        updatedAt = Date()
    }
}

// MARK: - Sous-quête

@Model
final class Subtask {
    var identifier: UUID = UUID()
    var title: String = ""
    var isDone: Bool = false
    var sortIndex: Double = 0
    var completedAt: Date?
    var task: TaskItem?

    init(title: String = "", sortIndex: Double = 0) {
        self.identifier = UUID()
        self.title = title
        self.sortIndex = sortIndex
    }
}

// MARK: - Projet

/// Un projet regroupe des quêtes et se comporte comme une « campagne » :
/// il a une barre de progression, une couleur et une date cible.
@Model
final class Project {
    var identifier: UUID = UUID()
    var name: String = ""
    var emoji: String = "📁"
    var colorHex: String = "5E5CE6"
    var notes: String = ""
    var isArchived: Bool = false
    var sortIndex: Double = 0
    var createdAt: Date = Date()
    var targetDate: Date?
    var lifeAreaRaw: String?

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.project)
    var tasks: [TaskItem]? = []

    init(
        name: String = "",
        emoji: String = "📁",
        colorHex: String = "5E5CE6",
        targetDate: Date? = nil,
        lifeArea: LifeArea? = nil
    ) {
        self.identifier = UUID()
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.targetDate = targetDate
        self.lifeAreaRaw = lifeArea?.rawValue
        self.createdAt = Date()
        self.sortIndex = Date().timeIntervalSince1970
    }

    var lifeArea: LifeArea? {
        get { lifeAreaRaw.flatMap { LifeArea(rawValue: $0) } }
        set { lifeAreaRaw = newValue?.rawValue }
    }

    var allTasks: [TaskItem] { tasks ?? [] }
    var openTasks: [TaskItem] { allTasks.filter(\.isOpen) }
    var completedTasks: [TaskItem] { allTasks.filter(\.isCompleted) }

    var progress: Double {
        let total = allTasks.count
        guard total > 0 else { return 0 }
        return Double(completedTasks.count) / Double(total)
    }

    var isComplete: Bool {
        !allTasks.isEmpty && openTasks.isEmpty
    }
}

// MARK: - Étiquette

@Model
final class Tag {
    var identifier: UUID = UUID()
    var name: String = ""
    var colorHex: String = "BF5AF2"
    var createdAt: Date = Date()

    @Relationship(inverse: \TaskItem.tags)
    var tasks: [TaskItem]? = []

    init(name: String = "", colorHex: String = "BF5AF2") {
        self.identifier = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
    }

    var openTaskCount: Int { (tasks ?? []).filter(\.isOpen).count }
}

// MARK: - Bloc de temps

/// Un créneau posé dans le calendrier. Il peut porter une quête (time-blocking)
/// ou refléter un évènement du calendrier système.
@Model
final class TimeBlock {
    var identifier: UUID = UUID()
    var title: String = ""
    var start: Date = Date()
    var end: Date = Date().addingTimeInterval(3600)
    var colorHex: String = "5E5CE6"
    var notes: String = ""
    /// Miroir en lecture seule d'un évènement EventKit.
    var isExternal: Bool = false
    var externalIdentifier: String?
    var isAllDay: Bool = false
    var task: TaskItem?

    init(
        title: String = "",
        start: Date = Date(),
        end: Date = Date().addingTimeInterval(3600),
        colorHex: String = "5E5CE6",
        task: TaskItem? = nil,
        isAllDay: Bool = false
    ) {
        self.identifier = UUID()
        self.title = title
        self.start = start
        self.end = end
        self.colorHex = colorHex
        self.task = task
        self.isAllDay = isAllDay
    }

    var durationMinutes: Int {
        max(0, Int(end.timeIntervalSince(start) / 60))
    }

    func overlaps(_ other: TimeBlock) -> Bool {
        start < other.end && other.start < end
    }
}
