import Foundation
import SwiftData
import QuestlyKit

// MARK: - Profil du héros

/// Enregistrement unique qui porte toute la progression du joueur.
/// Les dictionnaires sont stockés en JSON : SwiftData reste alors compatible
/// avec CloudKit sans type transformable exotique.
@Model
final class PlayerProfile {

    var identifier: UUID = UUID()
    var displayName: String = "Aventurier·ère"
    var createdAt: Date = Date()

    var totalXP: Int = 0
    var coins: Int = 0
    var gems: Int = 0

    // Compteurs cumulés (dérivables du journal, mis en cache pour la vitesse).
    var tasksCompleted: Int = 0
    var tasksCreated: Int = 0
    var bossesDefeated: Int = 0
    var focusMinutes: Int = 0
    var focusSessions: Int = 0
    var perfectDays: Int = 0
    var inboxZeroDays: Int = 0
    var questsCompleted: Int = 0
    var maxCombo: Int = 0
    var longestStreak: Int = 0
    var coinsEarned: Int = 0
    var coinsSpent: Int = 0
    var gemsEarned: Int = 0
    var notesWritten: Int = 0
    var calendarBlocksScheduled: Int = 0

    // Consommables
    var streakFreezes: Int = 1
    var restDayTokens: Int = 0
    var boostMultiplier: Double = 1.0
    var boostExpiresAt: Date?

    // Apparence
    var themeIdentifier: String = "nebula"
    var avatarLoadoutData: Data?
    var unlockedItems: [String] = []
    var unlockedAchievementsData: Data?
    var attributeXPData: Data?
    /// Compteurs secondaires (lève-tôt, week-end, habitudes…) en JSON.
    var secondaryCountersData: Data?

    // Suivi
    var lastActiveDate: Date?
    var lastQuestRollDate: Date?
    var hasCompletedOnboarding: Bool = false

    init() {
        self.identifier = UUID()
        self.createdAt = Date()
        self.unlockedItems = AvatarCatalog.defaultLoadout.values.map { $0 }
    }
}

extension PlayerProfile {

    // MARK: Blobs JSON

    var avatarLoadout: [String: String] {
        get { PlayerProfile.decode(avatarLoadoutData) ?? defaultLoadout }
        set { avatarLoadoutData = PlayerProfile.encode(newValue) }
    }

    private var defaultLoadout: [String: String] {
        var output: [String: String] = [:]
        for (slot, id) in AvatarCatalog.defaultLoadout {
            output[slot.rawValue] = id
        }
        return output
    }

    var unlockedAchievements: [String: Date] {
        get { PlayerProfile.decode(unlockedAchievementsData) ?? [:] }
        set { unlockedAchievementsData = PlayerProfile.encode(newValue) }
    }

    var attributeXP: [String: Int] {
        get { PlayerProfile.decode(attributeXPData) ?? [:] }
        set { attributeXPData = PlayerProfile.encode(newValue) }
    }

    static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    static func decode<T: Decodable>(_ data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // MARK: Progression

    var levelProgress: LevelProgress {
        LevelCurve.progress(forTotalXP: totalXP)
    }

    var level: Int { levelProgress.level }
    var rank: Rank { levelProgress.rank }

    var wallet: Wallet {
        get { Wallet(coins: coins, gems: gems) }
        set {
            coins = newValue.coins
            gems = newValue.gems
        }
    }

    func attributeXP(for area: LifeArea) -> Int {
        attributeXP[area.rawValue] ?? 0
    }

    func attributeLevel(for area: LifeArea) -> Int {
        AttributeCurve.level(forTotalXP: attributeXP(for: area))
    }

    func addAttributeXP(_ amount: Int, to area: LifeArea) {
        var current = attributeXP
        current[area.rawValue] = (current[area.rawValue] ?? 0) + amount
        attributeXP = current
    }

    /// Le multiplicateur de potion, s'il n'a pas expiré.
    func activeBoost(now: Date = Date()) -> Double {
        guard let boostExpiresAt, boostExpiresAt > now else { return 1.0 }
        return boostMultiplier
    }

    func avatarPart(for slot: AvatarSlot) -> AvatarPart? {
        guard let id = avatarLoadout[slot.rawValue] else { return nil }
        return AvatarCatalog.part(id: id)
    }

    func owns(itemID: String) -> Bool {
        unlockedItems.contains(itemID)
    }

    func snapshot(
        currentStreak: Int,
        completionsByArea: [LifeArea: Int],
        calendar: Calendar = .questly()
    ) -> PlayerSnapshot {
        var levels: [LifeArea: Int] = [:]
        for area in LifeArea.allCases {
            levels[area] = attributeLevel(for: area)
        }
        return PlayerSnapshot(
            level: level,
            totalXP: totalXP,
            tasksCompleted: tasksCompleted,
            tasksCreated: tasksCreated,
            bossesDefeated: bossesDefeated,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            focusMinutes: focusMinutes,
            focusSessions: focusSessions,
            perfectDays: perfectDays,
            earlyBirdCompletions: earlyBirdCompletions,
            nightOwlCompletions: nightOwlCompletions,
            weekendCompletions: weekendCompletions,
            habitsCompleted: habitsCompleted,
            longestHabitChain: longestHabitChain,
            projectsCompleted: projectsCompleted,
            coinsEarned: coinsEarned,
            coinsSpent: coinsSpent,
            gemsEarned: gemsEarned,
            questsCompleted: questsCompleted,
            maxCombo: maxCombo,
            inboxZeroDays: inboxZeroDays,
            onTimeCompletions: onTimeCompletions,
            completionsByArea: completionsByArea,
            attributeLevels: levels,
            calendarBlocksScheduled: calendarBlocksScheduled,
            notesWritten: notesWritten,
            daysSinceFirstLaunch: calendar.daysBetween(createdAt, Date())
        )
    }

    // Compteurs secondaires, également mis en cache.
    var earlyBirdCompletions: Int {
        get { secondaryCounters["earlyBird"] ?? 0 }
        set { setCounter("earlyBird", newValue) }
    }
    var nightOwlCompletions: Int {
        get { secondaryCounters["nightOwl"] ?? 0 }
        set { setCounter("nightOwl", newValue) }
    }
    var weekendCompletions: Int {
        get { secondaryCounters["weekend"] ?? 0 }
        set { setCounter("weekend", newValue) }
    }
    var habitsCompleted: Int {
        get { secondaryCounters["habits"] ?? 0 }
        set { setCounter("habits", newValue) }
    }
    var longestHabitChain: Int {
        get { secondaryCounters["habitChain"] ?? 0 }
        set { setCounter("habitChain", newValue) }
    }
    var projectsCompleted: Int {
        get { secondaryCounters["projects"] ?? 0 }
        set { setCounter("projects", newValue) }
    }
    var onTimeCompletions: Int {
        get { secondaryCounters["onTime"] ?? 0 }
        set { setCounter("onTime", newValue) }
    }

    private var secondaryCounters: [String: Int] {
        PlayerProfile.decode(secondaryCountersData) ?? [:]
    }

    private func setCounter(_ key: String, _ value: Int) {
        var current = secondaryCounters
        current[key] = value
        secondaryCountersData = PlayerProfile.encode(current)
    }

    /// Incrémente un compteur secondaire en une seule écriture.
    func bumpCounter(_ key: String, by amount: Int = 1) {
        var current = secondaryCounters
        current[key] = (current[key] ?? 0) + amount
        secondaryCountersData = PlayerProfile.encode(current)
    }
}

// MARK: - Journal d'accomplissement

/// Une ligne immuable par quête accomplie. C'est la source de vérité des
/// statistiques, des séries et de la carte de chaleur ; elle survit à la
/// suppression de la quête d'origine.
@Model
final class CompletionEvent {
    var identifier: UUID = UUID()
    var date: Date = Date()
    var taskTitle: String = ""
    var taskIdentifier: UUID?
    var xp: Int = 0
    var coins: Int = 0
    var focusMinutes: Int = 0
    var priorityRaw: Int = Priority.p4.rawValue
    var difficultyRaw: Int = Difficulty.medium.rawValue
    var lifeAreaRaw: String?
    var wasOnTime: Bool = true
    var isHabit: Bool = false
    var isBoss: Bool = false

    init(
        date: Date = Date(),
        taskTitle: String = "",
        taskIdentifier: UUID? = nil,
        xp: Int = 0,
        coins: Int = 0,
        focusMinutes: Int = 0,
        priority: Priority = .p4,
        difficulty: Difficulty = .medium,
        lifeArea: LifeArea? = nil,
        wasOnTime: Bool = true,
        isHabit: Bool = false,
        isBoss: Bool = false
    ) {
        self.identifier = UUID()
        self.date = date
        self.taskTitle = taskTitle
        self.taskIdentifier = taskIdentifier
        self.xp = xp
        self.coins = coins
        self.focusMinutes = focusMinutes
        self.priorityRaw = priority.rawValue
        self.difficultyRaw = difficulty.rawValue
        self.lifeAreaRaw = lifeArea?.rawValue
        self.wasOnTime = wasOnTime
        self.isHabit = isHabit
        self.isBoss = isBoss
    }

    var priority: Priority { Priority(rawValue: priorityRaw) ?? .p4 }
    var difficulty: Difficulty { Difficulty(rawValue: difficultyRaw) ?? .medium }
    var lifeArea: LifeArea? { lifeAreaRaw.flatMap { LifeArea(rawValue: $0) } }

    var record: CompletionRecord {
        CompletionRecord(
            id: identifier.uuidString,
            date: date,
            xp: xp,
            focusMinutes: focusMinutes,
            priority: priority,
            difficulty: difficulty,
            lifeArea: lifeArea,
            wasOnTime: wasOnTime,
            isHabit: isHabit,
            isBoss: isBoss
        )
    }
}

// MARK: - Quête quotidienne

@Model
final class QuestRecord {
    var identifier: String = ""
    var day: Date = Date()
    var kindRaw: String = ""
    var periodRaw: String = QuestPeriod.daily.rawValue
    var title: String = ""
    var detail: String = ""
    var target: Int = 1
    var progress: Int = 0
    var xpReward: Int = 0
    var coinReward: Int = 0
    var gemReward: Int = 0
    var rarityRaw: Int = Rarity.common.rawValue
    var symbolName: String = "scroll.fill"
    var lifeAreaRaw: String?
    var isClaimed: Bool = false
    var completedAt: Date?

    init(quest: GeneratedQuest, day: Date) {
        self.identifier = quest.id
        self.day = day
        self.kindRaw = quest.kind.rawValue
        self.periodRaw = quest.period.rawValue
        self.title = quest.title
        self.detail = quest.detail
        self.target = quest.target
        self.xpReward = quest.xpReward
        self.coinReward = quest.coinReward
        self.gemReward = quest.gemReward
        self.rarityRaw = quest.rarity.rawValue
        self.symbolName = quest.symbolName
        self.lifeAreaRaw = quest.lifeArea?.rawValue
    }

    var kind: QuestKind { QuestKind(rawValue: kindRaw) ?? .completeTasks }
    var period: QuestPeriod { QuestPeriod(rawValue: periodRaw) ?? .daily }
    var rarity: Rarity { Rarity(rawValue: rarityRaw) ?? .common }
    var lifeArea: LifeArea? { lifeAreaRaw.flatMap { LifeArea(rawValue: $0) } }

    var isComplete: Bool { progress >= target }
    var fraction: Double {
        guard target > 0 else { return 1 }
        return min(1, Double(progress) / Double(target))
    }
}

// MARK: - Session de concentration

@Model
final class FocusSession {
    var identifier: UUID = UUID()
    var start: Date = Date()
    var end: Date?
    var plannedMinutes: Int = 25
    var actualMinutes: Int = 0
    var wasCompleted: Bool = false
    var distractions: Int = 0
    var taskIdentifier: UUID?
    var taskTitle: String = ""
    var isBreak: Bool = false

    init(
        start: Date = Date(),
        plannedMinutes: Int = 25,
        taskIdentifier: UUID? = nil,
        taskTitle: String = "",
        isBreak: Bool = false
    ) {
        self.identifier = UUID()
        self.start = start
        self.plannedMinutes = plannedMinutes
        self.taskIdentifier = taskIdentifier
        self.taskTitle = taskTitle
        self.isBreak = isBreak
    }
}

// MARK: - Note de journal

@Model
final class JournalEntry {
    var identifier: UUID = UUID()
    var day: Date = Date()
    var text: String = ""
    /// 1 (difficile) à 5 (excellent).
    var mood: Int = 3
    var createdAt: Date = Date()

    init(day: Date = Date(), text: String = "", mood: Int = 3) {
        self.identifier = UUID()
        self.day = day
        self.text = text
        self.mood = mood
        self.createdAt = Date()
    }

    var moodEmoji: String {
        switch mood {
        case 1: return "😞"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        default: return "🤩"
        }
    }
}
