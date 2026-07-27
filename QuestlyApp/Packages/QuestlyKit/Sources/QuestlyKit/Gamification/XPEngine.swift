import Foundation

// MARK: - Inputs

/// Photographie d'une tâche au moment où elle est accomplie.
/// `QuestlyKit` ne connaît pas SwiftData : le layer app fournit ce descripteur.
public struct XPTaskDescriptor: Sendable, Equatable {
    public var difficulty: Difficulty
    public var priority: Priority
    public var estimatedMinutes: Int?
    public var completedSubtaskCount: Int
    public var totalSubtaskCount: Int
    public var dueDate: Date?
    public var hasTimeComponent: Bool
    public var isBoss: Bool
    public var lifeArea: LifeArea?
    public var focusedMinutes: Int
    public var isHabit: Bool

    public init(
        difficulty: Difficulty = .medium,
        priority: Priority = .p4,
        estimatedMinutes: Int? = nil,
        completedSubtaskCount: Int = 0,
        totalSubtaskCount: Int = 0,
        dueDate: Date? = nil,
        hasTimeComponent: Bool = false,
        isBoss: Bool = false,
        lifeArea: LifeArea? = nil,
        focusedMinutes: Int = 0,
        isHabit: Bool = false
    ) {
        self.difficulty = difficulty
        self.priority = priority
        self.estimatedMinutes = estimatedMinutes
        self.completedSubtaskCount = completedSubtaskCount
        self.totalSubtaskCount = totalSubtaskCount
        self.dueDate = dueDate
        self.hasTimeComponent = hasTimeComponent
        self.isBoss = isBoss
        self.lifeArea = lifeArea
        self.focusedMinutes = focusedMinutes
        self.isHabit = isHabit
    }
}

/// Contexte du joueur au moment de la validation.
public struct XPContext: Sendable, Equatable {
    /// Série de jours consécutifs en cours.
    public var streakDays: Int
    /// Nombre de tâches validées dans la fenêtre de combo (5 minutes).
    public var comboCount: Int
    /// Multiplicateur actif acheté en boutique (1.0 = aucun).
    public var boostMultiplier: Double
    /// Première tâche de la journée : petit bonus d'élan.
    public var isFirstCompletionOfDay: Bool
    /// La tâche fait partie des quêtes du jour.
    public var isDailyQuestTarget: Bool
    /// Date de validation.
    public var completionDate: Date

    public init(
        streakDays: Int = 0,
        comboCount: Int = 1,
        boostMultiplier: Double = 1.0,
        isFirstCompletionOfDay: Bool = false,
        isDailyQuestTarget: Bool = false,
        completionDate: Date = Date()
    ) {
        self.streakDays = streakDays
        self.comboCount = comboCount
        self.boostMultiplier = boostMultiplier
        self.isFirstCompletionOfDay = isFirstCompletionOfDay
        self.isDailyQuestTarget = isDailyQuestTarget
        self.completionDate = completionDate
    }
}

// MARK: - Output

public struct XPBreakdownLine: Sendable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let detail: String
    public let symbolName: String
    /// `true` pour un bonus, `false` pour un malus — pilote la couleur.
    public let isPositive: Bool

    public init(id: String, label: String, detail: String, symbolName: String, isPositive: Bool = true) {
        self.id = id
        self.label = label
        self.detail = detail
        self.symbolName = symbolName
        self.isPositive = isPositive
    }
}

public struct XPAward: Sendable, Equatable {
    public var totalXP: Int
    public var coins: Int
    public var gems: Int
    public var attributeXP: Int
    public var lifeArea: LifeArea?
    public var multiplier: Double
    public var breakdown: [XPBreakdownLine]

    public init(
        totalXP: Int,
        coins: Int,
        gems: Int,
        attributeXP: Int,
        lifeArea: LifeArea?,
        multiplier: Double,
        breakdown: [XPBreakdownLine]
    ) {
        self.totalXP = totalXP
        self.coins = coins
        self.gems = gems
        self.attributeXP = attributeXP
        self.lifeArea = lifeArea
        self.multiplier = multiplier
        self.breakdown = breakdown
    }

    public static let none = XPAward(
        totalXP: 0, coins: 0, gems: 0, attributeXP: 0,
        lifeArea: nil, multiplier: 1, breakdown: []
    )
}

// MARK: - Engine

/// Calcule les récompenses. Toutes les règles du jeu vivent ici, en un seul
/// endroit, sans dépendance à l'UI ni à la base de données.
public enum XPEngine {

    /// Plafond du multiplicateur de série : +30 % à 30 jours.
    public static let maxStreakBonus = 0.30
    /// Plafond du combo : +25 % à 6 tâches enchaînées.
    public static let maxComboBonus = 0.25
    /// Fenêtre pendant laquelle deux validations comptent dans le même combo.
    public static let comboWindow: TimeInterval = 5 * 60

    public static func award(
        for task: XPTaskDescriptor,
        context: XPContext,
        calendar: Calendar = .questly()
    ) -> XPAward {
        var lines: [XPBreakdownLine] = []

        // 1. Base : la difficulté.
        let base = Double(task.difficulty.baseXP)
        lines.append(XPBreakdownLine(
            id: "base",
            label: task.difficulty.label,
            detail: "+\(Int(base)) XP",
            symbolName: task.difficulty.symbolName
        ))

        // 2. Bonus additifs.
        var flatBonus = 0.0

        let subtaskBonus = min(Double(task.completedSubtaskCount) * 2.0, 20.0)
        if subtaskBonus > 0 {
            flatBonus += subtaskBonus
            lines.append(XPBreakdownLine(
                id: "subtasks",
                label: "\(task.completedSubtaskCount) sous-quête(s)",
                detail: "+\(Int(subtaskBonus)) XP",
                symbolName: "checklist"
            ))
        }

        if let minutes = task.estimatedMinutes, minutes > 0 {
            let durationBonus = min(Double(minutes) / 10.0, 25.0)
            flatBonus += durationBonus
            lines.append(XPBreakdownLine(
                id: "duration",
                label: "Durée \(DurationFormatter.short(minutes: minutes))",
                detail: "+\(Int(durationBonus)) XP",
                symbolName: "hourglass"
            ))
        }

        if task.focusedMinutes > 0 {
            let focusBonus = min(Double(task.focusedMinutes) / 5.0, 40.0)
            flatBonus += focusBonus
            lines.append(XPBreakdownLine(
                id: "focus",
                label: "\(task.focusedMinutes) min de concentration",
                detail: "+\(Int(focusBonus)) XP",
                symbolName: "timer"
            ))
        }

        var subtotal = base + flatBonus

        // 3. Multiplicateurs.
        var multiplier = 1.0

        multiplier *= task.priority.xpMultiplier
        if task.priority != .p4 {
            lines.append(XPBreakdownLine(
                id: "priority",
                label: "Priorité \(task.priority.shortLabel)",
                detail: "×\(format(task.priority.xpMultiplier))",
                symbolName: task.priority.symbolName
            ))
        }

        let timing = timingMultiplier(for: task, at: context.completionDate, calendar: calendar)
        if timing.value != 1.0 {
            multiplier *= timing.value
            lines.append(XPBreakdownLine(
                id: "timing",
                label: timing.label,
                detail: "×\(format(timing.value))",
                symbolName: timing.symbol,
                isPositive: timing.value >= 1.0
            ))
        }

        let streakMult = streakMultiplier(days: context.streakDays)
        if streakMult > 1.0 {
            multiplier *= streakMult
            lines.append(XPBreakdownLine(
                id: "streak",
                label: "Série de \(context.streakDays) jours",
                detail: "×\(format(streakMult))",
                symbolName: "flame.fill"
            ))
        }

        let comboMult = comboMultiplier(count: context.comboCount)
        if comboMult > 1.0 {
            multiplier *= comboMult
            lines.append(XPBreakdownLine(
                id: "combo",
                label: "Combo ×\(context.comboCount)",
                detail: "×\(format(comboMult))",
                symbolName: "bolt.fill"
            ))
        }

        if task.isBoss {
            multiplier *= 2.0
            lines.append(XPBreakdownLine(
                id: "boss",
                label: "Boss vaincu",
                detail: "×2",
                symbolName: "crown.fill"
            ))
        }

        if context.boostMultiplier > 1.0 {
            multiplier *= context.boostMultiplier
            lines.append(XPBreakdownLine(
                id: "boost",
                label: "Potion d'expérience",
                detail: "×\(format(context.boostMultiplier))",
                symbolName: "flask.fill"
            ))
        }

        if context.isFirstCompletionOfDay {
            subtotal += 10
            lines.append(XPBreakdownLine(
                id: "firstOfDay",
                label: "Premier pas du jour",
                detail: "+10 XP",
                symbolName: "sunrise.fill"
            ))
        }

        if context.isDailyQuestTarget {
            multiplier *= 1.15
            lines.append(XPBreakdownLine(
                id: "dailyQuest",
                label: "Quête du jour",
                detail: "×1,15",
                symbolName: "scroll.fill"
            ))
        }

        let total = max(1, Int((subtotal * multiplier).rounded()))

        // 4. Monnaies.
        let coins = max(1, Int((Double(total) / 4.0).rounded()))
        let gems = gemReward(for: task, total: total)

        // 5. XP d'attribut : 60 % de l'XP, arrondi.
        let attributeXP = task.lifeArea == nil ? 0 : max(1, Int((Double(total) * 0.6).rounded()))

        return XPAward(
            totalXP: total,
            coins: coins,
            gems: gems,
            attributeXP: attributeXP,
            lifeArea: task.lifeArea,
            multiplier: multiplier,
            breakdown: lines
        )
    }

    /// Aperçu affiché sur la fiche d'une tâche avant validation.
    public static func previewXP(for task: XPTaskDescriptor) -> Int {
        award(for: task, context: XPContext(completionDate: task.dueDate ?? Date())).totalXP
    }

    public static func streakMultiplier(days: Int) -> Double {
        guard days > 1 else { return 1.0 }
        return 1.0 + min(Double(days), 30.0) * 0.01
    }

    public static func comboMultiplier(count: Int) -> Double {
        guard count > 1 else { return 1.0 }
        return 1.0 + min(Double(count - 1), 5.0) * 0.05
    }

    /// Bonus de ponctualité / malus de retard.
    static func timingMultiplier(
        for task: XPTaskDescriptor,
        at date: Date,
        calendar: Calendar
    ) -> (value: Double, label: String, symbol: String) {
        guard let due = task.dueDate else { return (1.0, "", "") }

        if task.hasTimeComponent {
            if date <= due {
                let hoursEarly = due.timeIntervalSince(date) / 3600
                if hoursEarly >= 24 { return (1.20, "En avance", "hare.fill") }
                return (1.15, "Dans les temps", "checkmark.circle.fill")
            }
            let hoursLate = date.timeIntervalSince(due) / 3600
            if hoursLate <= 1 { return (1.0, "", "") }
            return (0.85, "En retard", "tortoise.fill")
        }

        let dayDelta = calendar.daysBetween(date, calendar.startOfDay(due))
        if dayDelta > 0 { return (1.20, "En avance de \(dayDelta) j", "hare.fill") }
        if dayDelta == 0 { return (1.15, "Le jour dit", "checkmark.circle.fill") }
        return (0.85, "En retard de \(-dayDelta) j", "tortoise.fill")
    }

    /// Les gemmes sont rares : boss, tâches légendaires, longues sessions.
    static func gemReward(for task: XPTaskDescriptor, total: Int) -> Int {
        var gems = 0
        if task.isBoss { gems += 3 }
        if task.difficulty == .legendary { gems += 2 }
        else if task.difficulty == .epic { gems += 1 }
        if task.focusedMinutes >= 90 { gems += 1 }
        if total >= 250 { gems += 1 }
        return gems
    }

    private static func format(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(format: "%.2f", rounded).replacingOccurrences(of: ".", with: ",")
    }
}

// MARK: - Combo tracking

/// Suit les validations rapprochées pour alimenter le multiplicateur de combo.
public struct ComboTracker: Sendable, Equatable {
    public private(set) var count: Int
    public private(set) var lastCompletion: Date?

    public init(count: Int = 0, lastCompletion: Date? = nil) {
        self.count = count
        self.lastCompletion = lastCompletion
    }

    /// Enregistre une validation et renvoie la taille du combo qui en résulte.
    @discardableResult
    public mutating func register(at date: Date) -> Int {
        if let last = lastCompletion, date.timeIntervalSince(last) <= XPEngine.comboWindow {
            count += 1
        } else {
            count = 1
        }
        lastCompletion = date
        return count
    }

    /// Le combo est-il encore actif à l'instant `date` ?
    public func isActive(at date: Date) -> Bool {
        guard let last = lastCompletion else { return false }
        return date.timeIntervalSince(last) <= XPEngine.comboWindow && count > 1
    }

    /// Secondes restantes avant expiration du combo.
    public func remainingSeconds(at date: Date) -> Int {
        guard let last = lastCompletion else { return 0 }
        let remaining = XPEngine.comboWindow - date.timeIntervalSince(last)
        return max(0, Int(remaining.rounded()))
    }

    public mutating func reset() {
        count = 0
        lastCompletion = nil
    }
}
