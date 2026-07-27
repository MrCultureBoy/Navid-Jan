import SwiftUI
import SwiftData
import QuestlyKit

/// Le Repaire : l'écran d'accueil. Il répond à une seule question — « qu'est-ce
/// que je fais maintenant ? » — puis récompense chaque réponse.
struct TodayView: View {

    var onQuickAdd: () -> Void

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(\.questlyTheme) private var theme

    @Query private var allTasks: [TaskItem]
    @Query private var profiles: [PlayerProfile]
    @Query private var quests: [QuestRecord]

    @State private var selectedTask: TaskItem?
    @State private var showsOverdue = true
    @State private var showsJournal = false

    private var calendar: Calendar { settings.calendar }
    private var player: PlayerProfile? { profiles.first }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Metrics.spacingL) {
                header
                questBoard
                if let hero = focusTask { heroCard(hero) }
                overdueSection
                todaySection
                habitsSection
                insightsSection
                Color.clear.frame(height: 110)
            }
            .padding(.horizontal, Metrics.spacingM)
            .padding(.top, Metrics.spacingS)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
        .sheet(isPresented: $showsJournal) {
            JournalSheet()
                .presentationDetents([.height(420)])
        }
    }

    // MARK: En-tête

    private var header: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingM) {
            HStack(alignment: .center, spacing: Metrics.spacingM) {
                LevelRing(
                    progress: player?.levelProgress ?? .zero,
                    size: 68,
                    emoji: avatarEmoji
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(QuestlyFormat.greeting(for: Date(), calendar: calendar))
                        .font(.questCaption)
                        .foregroundStyle(.secondary)
                    Text(player?.rank.title ?? "Novice")
                        .font(.questHeadline)
                    Text(QuestlyFormat.fullDay(Date(), calendar: calendar))
                        .font(.questMicro)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    StreakFlame(days: store.streak.current, isAtRisk: store.streak.isAtRisk, size: 20)
                    HStack(spacing: 5) {
                        CurrencyPill(kind: .coins, amount: player?.coins ?? 0)
                        CurrencyPill(kind: .gems, amount: player?.gems ?? 0)
                    }
                }
            }

            XPBar(progress: player?.levelProgress ?? .zero)

            dayProgressStrip
        }
        .padding(Metrics.spacingM)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerRadiusLarge, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.cornerRadiusLarge, style: .continuous)
                        .fill(theme.softGradient)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cornerRadiusLarge, style: .continuous)
                .strokeBorder(theme.accent.opacity(0.22), lineWidth: 1)
        }
    }

    private var avatarEmoji: String {
        player?.avatarPart(for: .face)?.emoji ?? "🧭"
    }

    /// Bandeau « x/y quêtes du jour » avec un anneau de complétion.
    private var dayProgressStrip: some View {
        let total = todayTasks.count + completedToday.count
        let done = completedToday.count
        let fraction = total > 0 ? Double(done) / Double(total) : 0

        return HStack(spacing: Metrics.spacingM) {
            ProgressRing(
                fraction: fraction,
                size: 38,
                lineWidth: 4,
                color: theme.accent,
                content: AnyView(
                    Text("\(done)")
                        .font(.questCaption)
                        .monospacedDigit()
                )
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(total == 0 ? "Journée libre" : "\(done) sur \(total) quêtes")
                    .font(.questCallout)
                Text(dayMessage(done: done, total: total))
                    .font(.questMicro)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showsJournal = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(SoftButtonStyle(tint: theme.accent))
        }
    }

    private func dayMessage(done: Int, total: Int) -> String {
        if total == 0 { return "Ajoute une quête pour lancer la journée." }
        if done == 0 { return "La première est toujours la plus dure." }
        if done == total { return "Journée parfaite. Rien à ajouter." }
        if Double(done) / Double(total) >= 0.66 { return "Le plus dur est derrière toi." }
        return "Bon rythme, continue."
    }

    // MARK: Quêtes du jour

    private var questBoard: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            sectionTitle("Quêtes du jour", symbol: "scroll.fill")

            if todayQuests.isEmpty {
                Text("Le tableau se remplit au premier lancement de la journée.")
                    .font(.questCaption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Metrics.spacingS) {
                        ForEach(todayQuests) { quest in
                            DailyQuestCard(quest: quest) {
                                if store.claim(quest) {
                                    Haptics.play(.questComplete)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
                .scrollClipDisabled()
            }
        }
    }

    private var todayQuests: [QuestRecord] {
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.startOfWeek(Date())
        return quests
            .filter { record in
                record.period == .daily
                    ? calendar.isSameDay(record.day, today)
                    : calendar.isSameDay(record.day, weekStart)
            }
            .sorted { lhs, rhs in
                if lhs.period != rhs.period { return lhs.period == .daily }
                return lhs.title < rhs.title
            }
    }

    // MARK: Quête vedette

    /// La quête à attaquer maintenant : la plus urgente, la plus rentable.
    private var focusTask: TaskItem? {
        let candidates = todayTasks.filter { !$0.isCompleted }
        return candidates.max { lhs, rhs in
            score(for: lhs) < score(for: rhs)
        }
    }

    private func score(for task: TaskItem) -> Double {
        var value = Double(task.priority.urgencyScore) * 10
        value += Double(task.difficulty.rawValue) * 3
        if task.isBoss { value += 25 }
        if task.isOverdue(now: Date(), calendar: calendar) { value += 30 }
        if task.isFlagged { value += 8 }
        return value
    }

    private func heroCard(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            sectionTitle("À attaquer maintenant", symbol: "target")

            Button {
                selectedTask = task
            } label: {
                GlassCard(tint: theme.accent) {
                    VStack(alignment: .leading, spacing: Metrics.spacingS) {
                        HStack {
                            if task.isBoss {
                                Label("BOSS", systemImage: "crown.fill")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Color(hex: "BF5AF2"))
                            }
                            DifficultyBadge(difficulty: task.difficulty)
                            if let area = task.lifeArea {
                                LifeAreaBadge(area: area)
                            }
                            Spacer()
                            XPPill(amount: task.previewXP, isPreview: true)
                        }

                        Text(task.title)
                            .font(.questHeadline)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.primary)

                        if task.isBoss {
                            BossHealthBar(
                                fraction: task.bossHealthFraction,
                                remainingMinutes: task.bossRemainingHP
                            )
                        }

                        HStack(spacing: Metrics.spacingS) {
                            Button {
                                let bundle = store.complete(task)
                                Haptics.play(bundle.comboCount > 1 ? .combo(bundle.comboCount) : .success)
                            } label: {
                                Label("Accomplir", systemImage: "checkmark")
                            }
                            .buttonStyle(SoftButtonStyle(tint: Color(hex: "30D158")))

                            Button {
                                selectedTask = task
                            } label: {
                                Label("Détails", systemImage: "chevron.right")
                            }
                            .buttonStyle(SoftButtonStyle(tint: theme.accent))
                        }
                    }
                }
            }
            .buttonStyle(PressableStyle(scale: 0.98))
        }
    }

    // MARK: Sections de quêtes

    private var overdueSection: some View {
        Group {
            if !overdueTasks.isEmpty {
                VStack(alignment: .leading, spacing: Metrics.spacingS) {
                    HStack {
                        sectionTitle("En retard", symbol: "exclamationmark.triangle.fill", color: Color(hex: "FF453A"))
                        Spacer()
                        Button("Tout reporter à aujourd'hui") {
                            withAnimation(Motion.gentle) {
                                store.rescheduleOverdueToToday()
                            }
                            Haptics.success()
                        }
                        .font(.questMicro)
                        .foregroundStyle(theme.accent)
                    }

                    GlassCard(tint: Color(hex: "FF453A")) {
                        VStack(spacing: 0) {
                            ForEach(overdueTasks.prefix(5)) { task in
                                TaskRow(task: task) { selectedTask = task }
                                if task.identifier != overdueTasks.prefix(5).last?.identifier {
                                    Divider().opacity(0.4)
                                }
                            }
                            if overdueTasks.count > 5 {
                                Text("+ \(overdueTasks.count - 5) autres")
                                    .font(.questMicro)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 6)
                            }
                        }
                    }
                }
            }
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            sectionTitle("Aujourd'hui", symbol: "sun.max.fill", color: Color(hex: "FF9F0A"))

            if todayTasks.isEmpty && completedToday.isEmpty {
                GlassCard {
                    EmptyStateView(
                        symbolName: "sparkles",
                        title: "Aucune quête pour aujourd'hui",
                        message: "Profite du calme, ou lance-toi un défi.",
                        actionTitle: "Ajouter une quête",
                        action: onQuickAdd
                    )
                }
            } else {
                GlassCard {
                    VStack(spacing: 0) {
                        ForEach(todayTasks) { task in
                            TaskRow(task: task) { selectedTask = task }
                            if task.identifier != todayTasks.last?.identifier {
                                Divider().opacity(0.4)
                            }
                        }

                        if !completedToday.isEmpty {
                            DisclosureGroup {
                                ForEach(completedToday) { task in
                                    TaskRow(task: task, isCompact: true) { selectedTask = task }
                                }
                            } label: {
                                Text("\(completedToday.count) accomplie\(completedToday.count > 1 ? "s" : "")")
                                    .font(.questCaption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, todayTasks.isEmpty ? 0 : Metrics.spacingS)
                        }
                    }
                }
            }
        }
    }

    private var habitsSection: some View {
        Group {
            if !habitTasks.isEmpty {
                VStack(alignment: .leading, spacing: Metrics.spacingS) {
                    sectionTitle("Rituels", symbol: "repeat.circle.fill", color: Color(hex: "30D158"))
                    GlassCard {
                        VStack(spacing: 0) {
                            ForEach(habitTasks) { task in
                                TaskRow(task: task, isCompact: true) { selectedTask = task }
                            }
                        }
                    }
                }
            }
        }
    }

    private var insightsSection: some View {
        let insights = InsightEngine.insights(
            stats: store.currentStats(days: 30),
            streak: store.streak,
            totalXP: player?.totalXP ?? 0,
            overdueCount: overdueTasks.count,
            calendar: calendar
        )

        return Group {
            if !insights.isEmpty {
                VStack(alignment: .leading, spacing: Metrics.spacingS) {
                    sectionTitle("Ce que disent tes chroniques", symbol: "sparkle.magnifyingglass")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Metrics.spacingS) {
                            ForEach(insights.prefix(4)) { insight in
                                InsightCard(insight: insight)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollClipDisabled()
                }
            }
        }
    }

    // MARK: Données dérivées

    private var openTasks: [TaskItem] {
        allTasks.filter(\.isOpen)
    }

    private var todayTasks: [TaskItem] {
        openTasks
            .filter { task in
                guard let due = task.dueDate else { return false }
                return calendar.startOfDay(for: due) <= calendar.startOfDay(for: Date())
                    && !task.isOverdue(now: Date(), calendar: calendar)
            }
            .sorted(by: TaskSorting.smart(calendar: calendar))
    }

    private var overdueTasks: [TaskItem] {
        openTasks
            .filter { $0.isOverdue(now: Date(), calendar: calendar) }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private var completedToday: [TaskItem] {
        allTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return calendar.isSameDay(completedAt, Date())
        }
        .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    private var habitTasks: [TaskItem] {
        openTasks.filter { $0.isRecurring && $0.isDueToday(now: Date(), calendar: calendar) }
    }

    // MARK: Utilitaires

    private func sectionTitle(_ title: String, symbol: String, color: Color? = nil) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color ?? theme.accent)
            Text(title)
                .font(.questCallout)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Carte de quête quotidienne

struct DailyQuestCard: View {
    let quest: QuestRecord
    let onClaim: () -> Void

    @Environment(\.questlyTheme) private var theme

    private var accent: Color { Color(hex: quest.rarity.hex) }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            HStack {
                Image(systemName: quest.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                Spacer()
                if quest.period == .weekly {
                    Text("SEMAINE")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Text(quest.title)
                .font(.questCallout)
                .lineLimit(1)

            Text(quest.detail)
                .font(.questMicro)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(height: 26, alignment: .top)

            ProgressView(value: quest.fraction)
                .progressViewStyle(.linear)
                .tint(accent)

            HStack(spacing: 6) {
                Text("\(min(quest.progress, quest.target))/\(quest.target)")
                    .font(.questMicro)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                if quest.isClaimed {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "30D158"))
                } else if quest.isComplete {
                    Button("Encaisser", action: onClaim)
                        .font(.questMicro)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background { Capsule().fill(accent) }
                        .buttonStyle(.plain)
                } else {
                    Text("+\(quest.xpReward) XP")
                        .font(.questMicro)
                        .foregroundStyle(accent)
                }
            }
        }
        .padding(Metrics.spacingS + 2)
        .frame(width: 190, height: 152)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .strokeBorder(accent.opacity(quest.isComplete ? 0.55 : 0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
        .applyIf(quest.isComplete && !quest.isClaimed) { view in
            view.overlay(alignment: .topTrailing) {
                PulsingHalo(color: accent, size: 26)
                    .offset(x: -6, y: 6)
            }
        }
    }
}

// MARK: - Carte d'observation

struct InsightCard: View {
    let insight: Insight

    private var accent: Color {
        switch insight.tone {
        case .positive: return Color(hex: "30D158")
        case .warning: return Color(hex: "FF9F0A")
        case .neutral: return Color(hex: "5E9BFF")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: insight.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)

            Text(insight.title)
                .font(.questCallout)
                .lineLimit(2)

            Text(insight.detail)
                .font(.questMicro)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Spacer(minLength: 0)
        }
        .padding(Metrics.spacingS + 2)
        .frame(width: 210, height: 128, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .strokeBorder(accent.opacity(0.2), lineWidth: 1)
        }
    }
}

// MARK: - Tri des quêtes

enum TaskSorting {

    /// Tri « intelligent » : retard, puis heure du jour, puis priorité,
    /// puis difficulté. C'est l'ordre par défaut partout dans l'app.
    static func smart(calendar: Calendar) -> (TaskItem, TaskItem) -> Bool {
        { lhs, rhs in
            let lhsOverdue = lhs.isOverdue(now: Date(), calendar: calendar)
            let rhsOverdue = rhs.isOverdue(now: Date(), calendar: calendar)
            if lhsOverdue != rhsOverdue { return lhsOverdue }

            switch (lhs.hasTime, rhs.hasTime) {
            case (true, false): return true
            case (false, true): return false
            case (true, true):
                let lhsDate = lhs.dueDate ?? .distantFuture
                let rhsDate = rhs.dueDate ?? .distantFuture
                if lhsDate != rhsDate { return lhsDate < rhsDate }
            case (false, false):
                break
            }

            if lhs.priority != rhs.priority {
                return lhs.priority.urgencyScore > rhs.priority.urgencyScore
            }
            if lhs.isBoss != rhs.isBoss { return lhs.isBoss }
            if lhs.difficulty != rhs.difficulty {
                return lhs.difficulty.rawValue > rhs.difficulty.rawValue
            }
            return lhs.sortIndex < rhs.sortIndex
        }
    }

    static func comparator(for order: TaskSortOrder, calendar: Calendar) -> (TaskItem, TaskItem) -> Bool {
        switch order {
        case .smart:
            return smart(calendar: calendar)
        case .dueDate:
            return { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .priority:
            return { $0.priority.urgencyScore > $1.priority.urgencyScore }
        case .difficulty:
            return { $0.difficulty.rawValue > $1.difficulty.rawValue }
        case .alphabetical:
            return { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .created:
            return { $0.createdAt > $1.createdAt }
        case .xpValue:
            return { $0.previewXP > $1.previewXP }
        }
    }
}
