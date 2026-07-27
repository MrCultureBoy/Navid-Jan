import Foundation
import SwiftData
import SwiftUI
import QuestlyKit

// MARK: - Récompense

/// Montée de niveau d'un attribut (domaine de vie).
struct AttributeLevelUp: Equatable {
    let area: LifeArea
    let level: Int
}

/// Tout ce qui doit être célébré après une validation, en un seul paquet.
struct RewardBundle: Equatable {
    var award: XPAward = .none
    var comboCount: Int = 1
    var leveledUp: Bool = false
    var newLevel: Int = 1
    var newRank: Rank?
    var unlockedAchievements: [AchievementDefinition] = []
    var completedQuests: [String] = []
    var streakMilestone: Int?
    var attributeLevelUp: AttributeLevelUp?

    var isEmpty: Bool {
        award.totalXP == 0 && unlockedAchievements.isEmpty && completedQuests.isEmpty
    }
}

// MARK: - Store

/// Point d'entrée unique pour tout ce qui modifie l'état du jeu.
///
/// Les vues lisent les données via `@Query` (SwiftData les tient à jour toutes
/// seules) et passent ici pour écrire, afin que les règles du jeu — XP, séries,
/// quêtes, hauts faits, récurrences — soient appliquées au même endroit.
@MainActor
@Observable
final class QuestlyStore {

    var modelContext: ModelContext
    var calendar: Calendar

    /// Combo en cours, volontairement non persisté : il expire avec la session.
    private(set) var combo = ComboTracker()
    /// Dernier état de série calculé.
    private(set) var streak: StreakState = .empty
    /// File des célébrations à jouer.
    var pendingCelebrations: [RewardBundle] = []

    init(modelContext: ModelContext, calendar: Calendar = .questly()) {
        self.modelContext = modelContext
        self.calendar = calendar
    }

    // MARK: - Accès

    func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        (try? modelContext.fetch(descriptor)) ?? []
    }

    func allTasks() -> [TaskItem] {
        fetch(FetchDescriptor<TaskItem>())
    }

    func openTasks() -> [TaskItem] {
        allTasks().filter(\.isOpen)
    }

    func completionEvents() -> [CompletionEvent] {
        fetch(FetchDescriptor<CompletionEvent>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
    }

    /// Le profil du joueur, créé au premier lancement.
    @discardableResult
    func profile() -> PlayerProfile {
        if let existing = fetch(FetchDescriptor<PlayerProfile>()).first {
            return existing
        }
        let created = PlayerProfile()
        modelContext.insert(created)
        save()
        return created
    }

    func save() {
        do {
            try modelContext.save()
        } catch {
            // Une écriture ratée ne doit jamais faire tomber l'app : on garde
            // l'état en mémoire, la prochaine sauvegarde réessaiera.
            print("Questly: échec de sauvegarde — \(error.localizedDescription)")
        }
    }

    // MARK: - Démarrage

    func bootstrap() {
        let player = profile()
        refreshStreak()
        refreshQuests(for: Date(), player: player)
        expireBoostIfNeeded(player: player)
        player.lastActiveDate = Date()
        save()
    }

    func expireBoostIfNeeded(player: PlayerProfile) {
        if let expiry = player.boostExpiresAt, expiry <= Date() {
            player.boostMultiplier = 1.0
            player.boostExpiresAt = nil
        }
    }

    // MARK: - Création

    @discardableResult
    func createTask(from parsed: ParsedInput, defaultProject: Project? = nil) -> TaskItem {
        let task = TaskItem(
            title: parsed.title.isEmpty ? "Nouvelle quête" : parsed.title,
            dueDate: parsed.dueDate,
            hasTime: parsed.hasTime,
            estimatedMinutes: parsed.durationMinutes ?? 0,
            priority: parsed.priority ?? .p4,
            difficulty: parsed.difficulty ?? .medium,
            status: parsed.dueDate == nil ? .inbox : .active,
            lifeArea: parsed.lifeArea,
            isBoss: parsed.isBoss
        )
        task.reminderMinutesBefore = parsed.reminderMinutesBefore

        if let rule = parsed.recurrence {
            task.recurrenceAnchor = parsed.dueDate ?? Date()
            task.recurrence = rule
        }

        if let projectName = parsed.project {
            task.project = findOrCreateProject(named: projectName)
        } else {
            task.project = defaultProject
        }

        var tags: [Tag] = []
        for name in parsed.tags {
            tags.append(findOrCreateTag(named: name))
        }
        task.tags = tags

        modelContext.insert(task)
        profile().tasksCreated += 1
        save()
        return task
    }

    @discardableResult
    func createTask(title: String, dueDate: Date? = nil, hasTime: Bool = false) -> TaskItem {
        let task = TaskItem(title: title, dueDate: dueDate, hasTime: hasTime,
                            status: dueDate == nil ? .inbox : .active)
        modelContext.insert(task)
        profile().tasksCreated += 1
        save()
        return task
    }

    func findOrCreateProject(named name: String) -> Project {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = fetch(FetchDescriptor<Project>()).first {
            $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }
        if let existing { return existing }
        let project = Project(name: trimmed, colorHex: Palette.randomProjectHex(seed: trimmed))
        modelContext.insert(project)
        return project
    }

    func findOrCreateTag(named name: String) -> Tag {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let existing = fetch(FetchDescriptor<Tag>()).first {
            $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }
        if let existing { return existing }
        let tag = Tag(name: trimmed, colorHex: Palette.randomTagHex(seed: trimmed))
        modelContext.insert(tag)
        return tag
    }

    // MARK: - Validation d'une quête

    /// Le cœur du jeu : valider une quête, distribuer les récompenses et
    /// renvoyer de quoi animer la célébration.
    @discardableResult
    func complete(_ task: TaskItem, at date: Date = Date()) -> RewardBundle {
        guard task.isOpen else { return RewardBundle() }

        let player = profile()
        expireBoostIfNeeded(player: player)

        let levelBefore = player.level
        let rankBefore = player.rank
        let areaLevelBefore = task.lifeArea.map { player.attributeLevel(for: $0) }

        let comboCount = combo.register(at: date)
        let isFirstToday = completionCount(on: date) == 0

        let context = XPContext(
            streakDays: streak.current,
            comboCount: comboCount,
            boostMultiplier: player.activeBoost(now: date),
            isFirstCompletionOfDay: isFirstToday,
            isDailyQuestTarget: isTargetedByActiveQuest(task),
            completionDate: date
        )

        let award = XPEngine.award(for: task.xpDescriptor(), context: context, calendar: calendar)
        let wasOnTime = !task.isOverdue(now: date, calendar: calendar)

        // 1. La quête elle-même.
        task.status = .completed
        task.completedAt = date
        task.earnedXP = award.totalXP
        task.touch()
        for subtask in task.orderedSubtasks where !subtask.isDone {
            subtask.isDone = true
            subtask.completedAt = date
        }

        // 2. Le journal.
        let event = CompletionEvent(
            date: date,
            taskTitle: task.title,
            taskIdentifier: task.identifier,
            xp: award.totalXP,
            coins: award.coins,
            focusMinutes: task.focusedMinutes,
            priority: task.priority,
            difficulty: task.difficulty,
            lifeArea: task.lifeArea,
            wasOnTime: wasOnTime,
            isHabit: task.isRecurring,
            isBoss: task.isBoss
        )
        modelContext.insert(event)

        // 3. Le profil.
        player.totalXP += award.totalXP
        player.coins += award.coins
        player.gems += award.gems
        player.coinsEarned += award.coins
        player.gemsEarned += award.gems
        player.tasksCompleted += 1
        player.maxCombo = max(player.maxCombo, comboCount)
        if task.isBoss { player.bossesDefeated += 1 }
        if task.isRecurring { player.habitsCompleted += 1 }
        if wasOnTime { player.onTimeCompletions += 1 }
        if let area = award.lifeArea {
            player.addAttributeXP(award.attributeXP, to: area)
        }

        let hour = calendar.component(.hour, from: date)
        if hour < 7 { player.earlyBirdCompletions += 1 }
        if hour >= 23 { player.nightOwlCompletions += 1 }
        if calendar.isWeekend(date) { player.weekendCompletions += 1 }

        // 4. La récurrence engendre la prochaine occurrence.
        spawnNextOccurrence(of: task, completedAt: date)

        // 5. Projet terminé ?
        if let project = task.project, project.isComplete {
            player.projectsCompleted += 1
        }

        save()

        // 6. Recalculs et récompenses annexes.
        refreshStreak()
        let questsDone = refreshQuestProgress()
        let achievements = grantNewAchievements(player: player)

        var bundle = RewardBundle(
            award: award,
            comboCount: comboCount,
            leveledUp: player.level > levelBefore,
            newLevel: player.level,
            newRank: player.rank > rankBefore ? player.rank : nil,
            unlockedAchievements: achievements,
            completedQuests: questsDone,
            streakMilestone: streak.milestoneReached
        )

        if let area = task.lifeArea, let before = areaLevelBefore {
            let after = player.attributeLevel(for: area)
            if after > before {
                bundle.attributeLevelUp = AttributeLevelUp(area: area, level: after)
            }
        }

        player.longestStreak = max(player.longestStreak, streak.current)
        save()

        pendingCelebrations.append(bundle)
        return bundle
    }

    /// Annule une validation — y compris les récompenses, pour éviter la triche
    /// involontaire (valider / annuler en boucle).
    func uncomplete(_ task: TaskItem) {
        guard task.isCompleted else { return }
        let player = profile()

        if let event = fetch(FetchDescriptor<CompletionEvent>()).first(where: { $0.taskIdentifier == task.identifier && $0.date == task.completedAt }) {
            player.totalXP = max(0, player.totalXP - event.xp)
            player.coins = max(0, player.coins - event.coins)
            player.coinsEarned = max(0, player.coinsEarned - event.coins)
            modelContext.delete(event)
        } else {
            player.totalXP = max(0, player.totalXP - task.earnedXP)
        }

        player.tasksCompleted = max(0, player.tasksCompleted - 1)
        if task.isBoss { player.bossesDefeated = max(0, player.bossesDefeated - 1) }

        task.status = task.dueDate == nil ? .inbox : .active
        task.completedAt = nil
        task.earnedXP = 0
        task.touch()

        save()
        refreshStreak()
        _ = refreshQuestProgress()
    }

    func delete(_ task: TaskItem) {
        modelContext.delete(task)
        save()
    }

    func archive(_ task: TaskItem) {
        task.status = .archived
        task.touch()
        save()
    }

    // MARK: - Récurrence

    /// Crée la prochaine occurrence d'une quête récurrente.
    private func spawnNextOccurrence(of task: TaskItem, completedAt: Date) {
        guard let rule = task.recurrence else { return }
        let anchor = task.recurrenceAnchor ?? task.dueDate ?? task.createdAt
        let reference = rule.mode == .afterCompletion ? completedAt : (task.dueDate ?? completedAt)

        guard let next = RecurrenceEngine.nextDate(
            rule: rule,
            after: reference,
            anchor: anchor,
            calendar: calendar
        ) else { return }

        let copy = TaskItem(
            title: task.title,
            notes: task.notes,
            dueDate: next,
            hasTime: task.hasTime,
            estimatedMinutes: task.estimatedMinutes,
            priority: task.priority,
            difficulty: task.difficulty,
            energy: task.energy,
            status: .active,
            lifeArea: task.lifeArea,
            isBoss: task.isBoss,
            project: task.project
        )
        copy.recurrenceAnchor = anchor
        copy.recurrenceData = task.recurrenceData
        copy.recurrenceCount = task.recurrenceCount + 1
        copy.reminderMinutesBefore = task.reminderMinutesBefore
        copy.tags = task.tags
        copy.sortIndex = task.sortIndex

        // Les sous-quêtes repartent à zéro à chaque occurrence.
        var newSubtasks: [Subtask] = []
        for subtask in task.orderedSubtasks {
            let fresh = Subtask(title: subtask.title, sortIndex: subtask.sortIndex)
            newSubtasks.append(fresh)
            modelContext.insert(fresh)
        }
        copy.subtasks = newSubtasks

        modelContext.insert(copy)

        // L'occurrence accomplie ne porte plus la règle : elle devient une
        // ligne d'historique.
        task.recurrenceData = nil
    }

    // MARK: - Planification

    @discardableResult
    func schedule(_ task: TaskItem, at start: Date, minutes: Int? = nil) -> TimeBlock {
        let duration = minutes ?? (task.estimatedMinutes > 0 ? task.estimatedMinutes : 30)
        let block = TimeBlock(
            title: task.title,
            start: start,
            end: start.addingTimeInterval(TimeInterval(duration * 60)),
            colorHex: task.lifeArea?.hex ?? task.priority.hex,
            task: task
        )
        modelContext.insert(block)
        if task.dueDate == nil {
            task.dueDate = start
            task.hasTime = true
            task.status = .active
        }
        profile().calendarBlocksScheduled += 1
        save()
        return block
    }

    func move(_ block: TimeBlock, to start: Date) {
        let duration = block.end.timeIntervalSince(block.start)
        block.start = start
        block.end = start.addingTimeInterval(duration)
        save()
    }

    func resize(_ block: TimeBlock, toMinutes minutes: Int) {
        block.end = block.start.addingTimeInterval(TimeInterval(max(5, minutes) * 60))
        save()
    }

    func delete(_ block: TimeBlock) {
        modelContext.delete(block)
        save()
    }

    func snooze(_ task: TaskItem, to date: Date, keepTime: Bool = false) {
        if keepTime, let current = task.dueDate {
            let comps = calendar.dateComponents([.hour, .minute], from: current)
            task.dueDate = calendar.setting(hour: comps.hour ?? 9, minute: comps.minute ?? 0, of: date)
        } else {
            task.dueDate = date
        }
        task.status = .active
        task.touch()
        save()
    }

    // MARK: - Concentration

    @discardableResult
    func recordFocus(minutes: Int, on task: TaskItem?, completed: Bool, distractions: Int = 0) -> FocusSession {
        let session = FocusSession(
            start: Date().addingTimeInterval(TimeInterval(-minutes * 60)),
            plannedMinutes: minutes,
            taskIdentifier: task?.identifier,
            taskTitle: task?.title ?? ""
        )
        session.end = Date()
        session.actualMinutes = minutes
        session.wasCompleted = completed
        session.distractions = distractions
        modelContext.insert(session)

        if let task {
            task.focusedMinutes += minutes
            task.touch()
        }

        let player = profile()
        player.focusMinutes += minutes
        if completed { player.focusSessions += 1 }
        save()
        _ = refreshQuestProgress()
        return session
    }

    // MARK: - Séries

    func refreshStreak() {
        let player = profile()
        let days = Set(completionEvents().map { calendar.startOfDay(for: $0.date) })
        let config = StreakEngine.Configuration(
            restWeekdays: [],
            availableFreezes: player.streakFreezes,
            maxGapPerFreeze: 1
        )
        streak = StreakEngine.evaluate(
            activeDays: days,
            today: Date(),
            configuration: config,
            calendar: calendar
        )
        if streak.freezesConsumed > 0 {
            player.streakFreezes = max(0, player.streakFreezes - streak.freezesConsumed)
        }
        player.longestStreak = max(player.longestStreak, streak.longest)
    }

    func completionCount(on day: Date) -> Int {
        completionEvents().filter { calendar.isSameDay($0.date, day) }.count
    }

    // MARK: - Quêtes quotidiennes

    func todayQuests() -> [QuestRecord] {
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.startOfWeek(Date())
        return fetch(FetchDescriptor<QuestRecord>()).filter { record in
            record.period == .daily
                ? calendar.isSameDay(record.day, today)
                : calendar.isSameDay(record.day, weekStart)
        }
    }

    func refreshQuests(for date: Date, player: PlayerProfile) {
        let today = calendar.startOfDay(for: date)
        let existingDaily = fetch(FetchDescriptor<QuestRecord>()).filter {
            $0.period == .daily && calendar.isSameDay($0.day, today)
        }

        if existingDaily.isEmpty {
            let stats = currentStats(days: 30)
            let neglected = InsightEngine.neglectedAreas(stats: stats, limit: 1)
            let generated = QuestGenerator.daily(
                for: today,
                playerLevel: player.level,
                preferredAreas: neglected,
                calendar: calendar
            )
            for quest in generated {
                modelContext.insert(QuestRecord(quest: quest, day: today))
            }
        }

        let weekStart = calendar.startOfWeek(date)
        let existingWeekly = fetch(FetchDescriptor<QuestRecord>()).filter {
            $0.period == .weekly && calendar.isSameDay($0.day, weekStart)
        }
        if existingWeekly.isEmpty {
            let weekly = QuestGenerator.weekly(for: date, playerLevel: player.level, calendar: calendar)
            modelContext.insert(QuestRecord(quest: weekly, day: weekStart))
        }

        player.lastQuestRollDate = today
        save()
        _ = refreshQuestProgress()
    }

    /// Recalcule l'avancement de chaque quête et renvoie celles qui viennent
    /// d'être bouclées.
    @discardableResult
    func refreshQuestProgress() -> [String] {
        let quests = todayQuests()
        guard !quests.isEmpty else { return [] }

        var newlyCompleted: [String] = []
        for quest in quests {
            let window = quest.period == .daily
                ? (start: calendar.startOfDay(for: Date()), end: calendar.endOfDay(Date()))
                : (start: calendar.startOfWeek(Date()), end: calendar.endOfWeek(Date()))
            let value = progressValue(for: quest, from: window.start, to: window.end)
            let wasComplete = quest.isComplete
            quest.progress = value
            if !wasComplete && quest.isComplete {
                quest.completedAt = Date()
                newlyCompleted.append(quest.title)
            }
        }
        save()
        return newlyCompleted
    }

    private func progressValue(for quest: QuestRecord, from start: Date, to end: Date) -> Int {
        let events = completionEvents().filter { $0.date >= start && $0.date <= end }

        switch quest.kind {
        case .completeTasks:
            return events.count
        case .completeHighPriority:
            return events.filter { $0.priority == .p1 || $0.priority == .p2 }.count
        case .focusMinutes:
            let sessions = fetch(FetchDescriptor<FocusSession>()).filter {
                $0.start >= start && $0.start <= end && !$0.isBreak
            }
            return sessions.reduce(0) { $0 + $1.actualMinutes }
        case .completeInArea:
            guard let area = quest.lifeArea else { return 0 }
            return events.filter { $0.lifeArea == area }.count
        case .completeBeforeNoon:
            return events.filter { calendar.component(.hour, from: $0.date) < 12 }.count
        case .clearOverdue:
            return events.filter { !$0.wasOnTime }.count
        case .defeatBoss:
            return events.filter(\.isBoss).count
        case .completeHabit:
            return events.filter(\.isHabit).count
        case .scheduleBlocks:
            return fetch(FetchDescriptor<TimeBlock>()).filter {
                !$0.isExternal && $0.start >= start && $0.start <= end
            }.count
        case .planTomorrow:
            let tomorrow = Date().adding(days: 1, calendar: calendar)
            return allTasks().filter { task in
                guard let due = task.dueDate else { return false }
                return calendar.isSameDay(due, tomorrow)
            }.count
        case .completeDifficult:
            return events.filter { $0.difficulty.rawValue >= Difficulty.hard.rawValue }.count
        case .writeNote:
            return fetch(FetchDescriptor<JournalEntry>()).filter {
                $0.createdAt >= start && $0.createdAt <= end
            }.count
        case .comboChain:
            return combo.count
        case .noSnooze:
            return 0
        }
    }

    /// Encaisse la récompense d'une quête bouclée.
    @discardableResult
    func claim(_ quest: QuestRecord) -> Bool {
        guard quest.isComplete, !quest.isClaimed else { return false }
        let player = profile()
        quest.isClaimed = true
        player.totalXP += quest.xpReward
        player.coins += quest.coinReward
        player.gems += quest.gemReward
        player.coinsEarned += quest.coinReward
        player.gemsEarned += quest.gemReward
        player.questsCompleted += 1
        save()
        return true
    }

    private func isTargetedByActiveQuest(_ task: TaskItem) -> Bool {
        todayQuests().contains { quest in
            guard !quest.isComplete else { return false }
            switch quest.kind {
            case .completeHighPriority:
                return task.priority == .p1 || task.priority == .p2
            case .defeatBoss:
                return task.isBoss
            case .completeInArea:
                return quest.lifeArea != nil && task.lifeArea == quest.lifeArea
            case .completeDifficult:
                return task.difficulty.rawValue >= Difficulty.hard.rawValue
            case .completeHabit:
                return task.isRecurring
            default:
                return false
            }
        }
    }

    // MARK: - Hauts faits

    func playerSnapshot() -> PlayerSnapshot {
        let player = profile()
        var byArea: [LifeArea: Int] = [:]
        for event in completionEvents() {
            if let area = event.lifeArea {
                byArea[area, default: 0] += 1
            }
        }
        return player.snapshot(currentStreak: streak.current, completionsByArea: byArea, calendar: calendar)
    }

    @discardableResult
    func grantNewAchievements(player: PlayerProfile) -> [AchievementDefinition] {
        let snapshot = playerSnapshot()
        let known = Set(player.unlockedAchievements.keys)
        let unlocked = AchievementEngine.newlyUnlocked(snapshot: snapshot, alreadyUnlocked: known)
        guard !unlocked.isEmpty else { return [] }

        var dates = player.unlockedAchievements
        for definition in unlocked {
            dates[definition.id] = Date()
            player.totalXP += definition.xpReward
            player.coins += definition.coinReward
            player.gems += definition.gemReward
            player.coinsEarned += definition.coinReward
            player.gemsEarned += definition.gemReward
        }
        player.unlockedAchievements = dates
        save()
        return unlocked
    }

    func achievementProgress() -> [AchievementProgress] {
        AchievementEngine.evaluate(
            snapshot: playerSnapshot(),
            unlockDates: profile().unlockedAchievements
        )
    }

    // MARK: - Boutique

    @discardableResult
    func purchase(_ item: ShopItem) -> Bool {
        let player = profile()
        guard player.level >= item.requiredLevel else { return false }
        if !item.isConsumable && player.owns(itemID: item.id) { return false }

        var wallet = player.wallet
        guard wallet.spend(item.price) else { return false }
        player.wallet = wallet
        player.coinsSpent += item.price.coins

        apply(effect: item.effect, to: player)
        if !item.isConsumable {
            player.unlockedItems.append(item.id)
        }
        save()
        _ = grantNewAchievements(player: player)
        return true
    }

    func apply(effect: ShopEffect, to player: PlayerProfile) {
        switch effect {
        case .xpBoost(let multiplier, let hours):
            player.boostMultiplier = multiplier
            player.boostExpiresAt = Date().addingTimeInterval(TimeInterval(hours * 3600))
        case .streakFreeze(let count):
            player.streakFreezes += count
        case .restDayToken(let count):
            player.restDayTokens += count
        case .unlockTheme(let id):
            if !player.unlockedItems.contains("theme.\(id)") {
                player.unlockedItems.append("theme.\(id)")
            }
        case .unlockAvatarPart(let id):
            if !player.unlockedItems.contains(id) {
                player.unlockedItems.append(id)
            }
        case .openChest(let tier):
            let seed = UInt64(abs(Date().timeIntervalSince1970.hashValue % 1_000_000))
            for drop in LootEngine.openChest(tier: tier, seed: seed) {
                apply(effect: drop.effect, to: player)
            }
        case .coinPouch(let amount):
            player.coins += amount
            player.coinsEarned += amount
        }
    }

    func equip(part: AvatarPart, on player: PlayerProfile) {
        var loadout = player.avatarLoadout
        loadout[part.slot.rawValue] = part.id
        player.avatarLoadout = loadout
        save()
    }

    // MARK: - Statistiques

    func currentStats(days: Int = 30) -> ProductivityStats {
        let end = Date()
        let start = end.adding(days: -max(1, days), calendar: calendar)
        return StatsEngine.compute(
            records: completionEvents().map(\.record),
            from: start,
            to: end,
            calendar: calendar
        )
    }

    func heatmapCells(months: Int = 12) -> [HeatmapCell] {
        let end = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .month, value: -months, to: end) ?? end
        var counts: [Date: Int] = [:]
        for event in completionEvents() {
            let day = calendar.startOfDay(for: event.date)
            counts[day, default: 0] += 1
        }
        return StreakEngine.heatmap(completionsByDay: counts, from: start, to: end, calendar: calendar)
    }

    // MARK: - Planification automatique

    func autoPlanToday(workingHours: WorkingHours) -> PlanResult {
        let today = Date()
        let candidates = openTasks()
            .filter { task in
                guard let due = task.dueDate else { return false }
                return calendar.startOfDay(for: due) <= calendar.startOfDay(for: today)
            }
            .filter { $0.scheduledBlocks.isEmpty }
            .map { task in
                PlannableTask(
                    id: task.identifier.uuidString,
                    title: task.title,
                    estimatedMinutes: task.estimatedMinutes > 0 ? task.estimatedMinutes : 30,
                    priority: task.priority,
                    difficulty: task.difficulty,
                    energy: task.energy,
                    dueDate: task.dueDate,
                    isBoss: task.isBoss
                )
            }

        let busy = blocks(on: today).map {
            BusyInterval(id: $0.identifier.uuidString, start: $0.start, end: $0.end, title: $0.title)
        }

        return ScheduleEngine.autoPlan(
            tasks: candidates,
            on: today,
            busy: busy,
            workingHours: workingHours,
            notBefore: today,
            calendar: calendar
        )
    }

    func applyPlan(_ plan: PlanResult) {
        let tasksByID = Dictionary(
            allTasks().map { ($0.identifier.uuidString, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for block in plan.blocks {
            guard let task = tasksByID[block.taskID] else { continue }
            schedule(task, at: block.start, minutes: Int(block.end.timeIntervalSince(block.start) / 60))
        }
    }

    func blocks(on day: Date) -> [TimeBlock] {
        fetch(FetchDescriptor<TimeBlock>()).filter { calendar.isSameDay($0.start, day) }
            .sorted { $0.start < $1.start }
    }

    // MARK: - Journal

    @discardableResult
    func writeJournal(text: String, mood: Int, on day: Date = Date()) -> JournalEntry {
        let entry = JournalEntry(day: calendar.startOfDay(for: day), text: text, mood: mood)
        modelContext.insert(entry)
        profile().notesWritten += 1
        save()
        _ = refreshQuestProgress()
        return entry
    }

    // MARK: - Maintenance

    /// Bascule les quêtes en retard vers aujourd'hui, à la demande.
    func rescheduleOverdueToToday() {
        let today = Date()
        for task in openTasks() where task.isOverdue(now: today, calendar: calendar) {
            snooze(task, to: today, keepTime: task.hasTime)
        }
    }

    func consumeCelebration() -> RewardBundle? {
        guard !pendingCelebrations.isEmpty else { return nil }
        return pendingCelebrations.removeFirst()
    }
}
