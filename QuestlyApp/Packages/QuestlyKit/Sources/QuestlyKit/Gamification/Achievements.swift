import Foundation

// MARK: - Snapshot

/// Tous les compteurs du joueur, agrégés par le layer app puis passés au
/// moteur de hauts faits.
public struct PlayerSnapshot: Sendable, Equatable {
    public var level: Int
    public var totalXP: Int
    public var tasksCompleted: Int
    public var tasksCreated: Int
    public var bossesDefeated: Int
    public var currentStreak: Int
    public var longestStreak: Int
    public var focusMinutes: Int
    public var focusSessions: Int
    public var perfectDays: Int
    public var earlyBirdCompletions: Int
    public var nightOwlCompletions: Int
    public var weekendCompletions: Int
    public var habitsCompleted: Int
    public var longestHabitChain: Int
    public var projectsCompleted: Int
    public var coinsEarned: Int
    public var coinsSpent: Int
    public var gemsEarned: Int
    public var questsCompleted: Int
    public var maxCombo: Int
    public var inboxZeroDays: Int
    public var onTimeCompletions: Int
    public var completionsByArea: [LifeArea: Int]
    public var attributeLevels: [LifeArea: Int]
    public var calendarBlocksScheduled: Int
    public var notesWritten: Int
    public var daysSinceFirstLaunch: Int

    public init(
        level: Int = 1,
        totalXP: Int = 0,
        tasksCompleted: Int = 0,
        tasksCreated: Int = 0,
        bossesDefeated: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        focusMinutes: Int = 0,
        focusSessions: Int = 0,
        perfectDays: Int = 0,
        earlyBirdCompletions: Int = 0,
        nightOwlCompletions: Int = 0,
        weekendCompletions: Int = 0,
        habitsCompleted: Int = 0,
        longestHabitChain: Int = 0,
        projectsCompleted: Int = 0,
        coinsEarned: Int = 0,
        coinsSpent: Int = 0,
        gemsEarned: Int = 0,
        questsCompleted: Int = 0,
        maxCombo: Int = 0,
        inboxZeroDays: Int = 0,
        onTimeCompletions: Int = 0,
        completionsByArea: [LifeArea: Int] = [:],
        attributeLevels: [LifeArea: Int] = [:],
        calendarBlocksScheduled: Int = 0,
        notesWritten: Int = 0,
        daysSinceFirstLaunch: Int = 0
    ) {
        self.level = level
        self.totalXP = totalXP
        self.tasksCompleted = tasksCompleted
        self.tasksCreated = tasksCreated
        self.bossesDefeated = bossesDefeated
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.focusMinutes = focusMinutes
        self.focusSessions = focusSessions
        self.perfectDays = perfectDays
        self.earlyBirdCompletions = earlyBirdCompletions
        self.nightOwlCompletions = nightOwlCompletions
        self.weekendCompletions = weekendCompletions
        self.habitsCompleted = habitsCompleted
        self.longestHabitChain = longestHabitChain
        self.projectsCompleted = projectsCompleted
        self.coinsEarned = coinsEarned
        self.coinsSpent = coinsSpent
        self.gemsEarned = gemsEarned
        self.questsCompleted = questsCompleted
        self.maxCombo = maxCombo
        self.inboxZeroDays = inboxZeroDays
        self.onTimeCompletions = onTimeCompletions
        self.completionsByArea = completionsByArea
        self.attributeLevels = attributeLevels
        self.calendarBlocksScheduled = calendarBlocksScheduled
        self.notesWritten = notesWritten
        self.daysSinceFirstLaunch = daysSinceFirstLaunch
    }

    public func value(for metric: AchievementMetric) -> Int {
        switch metric {
        case .level: return level
        case .totalXP: return totalXP
        case .tasksCompleted: return tasksCompleted
        case .tasksCreated: return tasksCreated
        case .bossesDefeated: return bossesDefeated
        case .currentStreak: return currentStreak
        case .longestStreak: return longestStreak
        case .focusMinutes: return focusMinutes
        case .focusSessions: return focusSessions
        case .perfectDays: return perfectDays
        case .earlyBird: return earlyBirdCompletions
        case .nightOwl: return nightOwlCompletions
        case .weekendWarrior: return weekendCompletions
        case .habitsCompleted: return habitsCompleted
        case .habitChain: return longestHabitChain
        case .projectsCompleted: return projectsCompleted
        case .coinsEarned: return coinsEarned
        case .coinsSpent: return coinsSpent
        case .gemsEarned: return gemsEarned
        case .questsCompleted: return questsCompleted
        case .maxCombo: return maxCombo
        case .inboxZeroDays: return inboxZeroDays
        case .onTimeCompletions: return onTimeCompletions
        case .calendarBlocks: return calendarBlocksScheduled
        case .notesWritten: return notesWritten
        case .loyaltyDays: return daysSinceFirstLaunch
        case .areaCompletions(let area): return completionsByArea[area] ?? 0
        case .attributeLevel(let area): return attributeLevels[area] ?? 1
        case .balancedAreas:
            // Nombre de domaines ayant au moins 10 tâches accomplies.
            return LifeArea.allCases.filter { (completionsByArea[$0] ?? 0) >= 10 }.count
        }
    }
}

// MARK: - Metric

public enum AchievementMetric: Hashable, Sendable {
    case level
    case totalXP
    case tasksCompleted
    case tasksCreated
    case bossesDefeated
    case currentStreak
    case longestStreak
    case focusMinutes
    case focusSessions
    case perfectDays
    case earlyBird
    case nightOwl
    case weekendWarrior
    case habitsCompleted
    case habitChain
    case projectsCompleted
    case coinsEarned
    case coinsSpent
    case gemsEarned
    case questsCompleted
    case maxCombo
    case inboxZeroDays
    case onTimeCompletions
    case calendarBlocks
    case notesWritten
    case loyaltyDays
    case areaCompletions(LifeArea)
    case attributeLevel(LifeArea)
    case balancedAreas
}

// MARK: - Definition

public enum AchievementCategory: String, CaseIterable, Sendable, Identifiable {
    case beginnings
    case volume
    case consistency
    case focus
    case mastery
    case balance
    case collection
    case secret

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .beginnings: return "Premiers pas"
        case .volume: return "Volume"
        case .consistency: return "Régularité"
        case .focus: return "Concentration"
        case .mastery: return "Maîtrise"
        case .balance: return "Équilibre"
        case .collection: return "Collection"
        case .secret: return "Secrets"
        }
    }

    public var symbolName: String {
        switch self {
        case .beginnings: return "sparkle"
        case .volume: return "square.stack.3d.up.fill"
        case .consistency: return "flame.fill"
        case .focus: return "timer"
        case .mastery: return "crown.fill"
        case .balance: return "circle.hexagongrid.fill"
        case .collection: return "shippingbox.fill"
        case .secret: return "eye.slash.fill"
        }
    }
}

public struct AchievementDefinition: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let detail: String
    public let symbolName: String
    public let rarity: Rarity
    public let category: AchievementCategory
    public let metric: AchievementMetric
    public let goal: Int
    public let xpReward: Int
    public let coinReward: Int
    public let gemReward: Int
    /// Un haut fait secret reste masqué tant qu'il n'est pas débloqué.
    public let isSecret: Bool

    public init(
        id: String,
        title: String,
        detail: String,
        symbolName: String,
        rarity: Rarity,
        category: AchievementCategory,
        metric: AchievementMetric,
        goal: Int,
        xpReward: Int? = nil,
        coinReward: Int? = nil,
        gemReward: Int? = nil,
        isSecret: Bool = false
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.symbolName = symbolName
        self.rarity = rarity
        self.category = category
        self.metric = metric
        self.goal = goal
        self.xpReward = xpReward ?? AchievementDefinition.defaultXP(for: rarity)
        self.coinReward = coinReward ?? AchievementDefinition.defaultCoins(for: rarity)
        self.gemReward = gemReward ?? AchievementDefinition.defaultGems(for: rarity)
        self.isSecret = isSecret
    }

    static func defaultXP(for rarity: Rarity) -> Int {
        switch rarity {
        case .common: return 50
        case .uncommon: return 120
        case .rare: return 250
        case .epic: return 500
        case .legendary: return 1000
        case .mythic: return 2500
        }
    }

    static func defaultCoins(for rarity: Rarity) -> Int {
        switch rarity {
        case .common: return 20
        case .uncommon: return 50
        case .rare: return 120
        case .epic: return 300
        case .legendary: return 700
        case .mythic: return 1500
        }
    }

    static func defaultGems(for rarity: Rarity) -> Int {
        switch rarity {
        case .common: return 0
        case .uncommon: return 1
        case .rare: return 3
        case .epic: return 8
        case .legendary: return 20
        case .mythic: return 50
        }
    }
}

// MARK: - Progress

public struct AchievementProgress: Identifiable, Sendable, Equatable {
    public let definition: AchievementDefinition
    public let value: Int
    public let unlockedAt: Date?

    public var id: String { definition.id }
    public var isUnlocked: Bool { unlockedAt != nil || value >= definition.goal }
    public var fraction: Double {
        guard definition.goal > 0 else { return 1 }
        return min(1, Double(value) / Double(definition.goal))
    }
    public var remaining: Int { max(0, definition.goal - value) }

    public init(definition: AchievementDefinition, value: Int, unlockedAt: Date?) {
        self.definition = definition
        self.value = value
        self.unlockedAt = unlockedAt
    }
}

// MARK: - Engine

public enum AchievementEngine {

    /// Évalue tout le catalogue et renvoie la progression de chaque haut fait.
    public static func evaluate(
        snapshot: PlayerSnapshot,
        unlockDates: [String: Date] = [:]
    ) -> [AchievementProgress] {
        AchievementCatalog.all.map { definition in
            AchievementProgress(
                definition: definition,
                value: snapshot.value(for: definition.metric),
                unlockedAt: unlockDates[definition.id]
            )
        }
    }

    /// Hauts faits franchis depuis le dernier passage : c'est ce qui déclenche
    /// la fanfare et les confettis.
    public static func newlyUnlocked(
        snapshot: PlayerSnapshot,
        alreadyUnlocked: Set<String>
    ) -> [AchievementDefinition] {
        AchievementCatalog.all.filter { definition in
            !alreadyUnlocked.contains(definition.id)
                && snapshot.value(for: definition.metric) >= definition.goal
        }
    }

    /// Les prochains objectifs à portée de main, pour la carte « bientôt ».
    public static func almostThere(
        snapshot: PlayerSnapshot,
        unlockDates: [String: Date] = [:],
        limit: Int = 3
    ) -> [AchievementProgress] {
        evaluate(snapshot: snapshot, unlockDates: unlockDates)
            .filter { !$0.isUnlocked && $0.fraction > 0 }
            .sorted { $0.fraction > $1.fraction }
            .prefix(limit)
            .map { $0 }
    }
}
