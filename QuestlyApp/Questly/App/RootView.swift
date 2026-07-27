import SwiftUI
import SwiftData
import Combine
import QuestlyKit

/// Coque de l'application : fond, navigation par onglets, saisie rapide et
/// file des célébrations.
struct RootView: View {

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(ThemeManager.self) private var themeManager
    @Environment(NotificationService.self) private var notifications
    @Environment(CalendarService.self) private var calendarService

    @State private var selectedTab: AppTab = .today
    @State private var isQuickAddPresented = false
    @State private var celebrationQueue: [Celebration] = []
    @State private var currentCelebration: Celebration?
    @State private var comboSnapshot: (count: Int, remaining: Int)?
    @State private var hasBootstrapped = false

    /// Rafraîchit le sablier du combo une fois par seconde.
    private let comboTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @Query private var tasks: [TaskItem]

    var body: some View {
        ZStack {
            AuroraBackground(theme: themeManager.current, animated: !settings.reduceMotion)

            content
                .safeAreaInset(edge: .bottom) {
                    QuestlyTabBar(selection: $selectedTab, badges: tabBadges)
                        .padding(.bottom, 4)
                }

            // Le bouton flottant vit dans la pile racine : posé dans l'encart
            // de la barre d'onglets, il déborderait et perdrait ses touches.
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    QuickAddButton { isQuickAddPresented = true }
                        .padding(.trailing, Metrics.spacingL)
                        .padding(.bottom, Metrics.tabBarHeight + 34)
                }
            }
            .zIndex(1)

            if let combo = comboSnapshot, combo.count > 1 {
                VStack {
                    ComboIndicator(count: combo.count, remainingSeconds: combo.remaining)
                        .padding(.top, 4)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(2)
            }

            if let celebration = currentCelebration {
                CelebrationOverlay(
                    celebration: celebration,
                    confettiEnabled: settings.confettiEnabled && !settings.reduceMotion
                ) {
                    advanceCelebrations()
                }
                .zIndex(3)
            }
        }
        .environment(\.questlyTheme, themeManager.current)
        .sheet(isPresented: $isQuickAddPresented) {
            QuickAddView()
                .presentationDetents([.height(340), .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
        }
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView()
        }
        .task { await bootstrap() }
        .onChange(of: store.pendingCelebrations) { _, _ in collectCelebrations() }
        .onChange(of: settings.themeID) { _, newValue in themeManager.select(id: newValue) }
        .onReceive(comboTimer) { _ in refreshCombo() }
    }

    // MARK: Contenu

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .today:
            TodayView(onQuickAdd: { isQuickAddPresented = true })
        case .quests:
            QuestBoardView()
        case .calendar:
            CalendarScreen()
        case .focus:
            FocusView()
        case .hero:
            HeroView()
        }
    }

    private var tabBadges: [AppTab: Int] {
        let overdue = tasks.filter { $0.isOverdue(now: Date(), calendar: settings.calendar) }.count
        return overdue > 0 ? [.quests: overdue] : [:]
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !settings.hasSeenOnboarding },
            set: { newValue in settings.hasSeenOnboarding = !newValue }
        )
    }

    // MARK: Démarrage

    private func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        store.calendar = settings.calendar
        store.bootstrap()

        await notifications.refreshAuthorization()
        notifications.registerCategories()
        notifications.scheduleDailyReview(hour: settings.dailyReviewHour)
        notifications.scheduleStreakReminder(streak: store.streak.current)

        calendarService.refreshAuthorization()
        if settings.calendarSyncEnabled {
            let start = settings.calendar.startOfMonth(Date())
            let end = settings.calendar.date(byAdding: .month, value: 2, to: start) ?? start
            calendarService.load(from: start, to: end)
        }
    }

    // MARK: Célébrations

    private func refreshCombo() {
        let now = Date()
        if store.combo.isActive(at: now) {
            comboSnapshot = (store.combo.count, store.combo.remainingSeconds(at: now))
        } else if comboSnapshot != nil {
            withAnimation(Motion.snappy) { comboSnapshot = nil }
        }
    }

    private func collectCelebrations() {
        while let bundle = store.consumeCelebration() {
            celebrationQueue.append(contentsOf: RootView.celebrations(from: bundle))
        }
        if currentCelebration == nil { advanceCelebrations() }
    }

    private func advanceCelebrations() {
        if celebrationQueue.isEmpty {
            currentCelebration = nil
        } else {
            currentCelebration = celebrationQueue.removeFirst()
        }
    }

    /// Traduit une récompense en une suite de fanfares, de la plus marquante à
    /// la plus anodine.
    static func celebrations(from bundle: RewardBundle) -> [Celebration] {
        var output: [Celebration] = []
        if bundle.leveledUp {
            output.append(.levelUp(level: bundle.newLevel, rank: bundle.newRank))
        }
        for achievement in bundle.unlockedAchievements {
            output.append(.achievement(achievement))
        }
        if let milestone = bundle.streakMilestone {
            output.append(.streakMilestone(days: milestone))
        }
        if let attribute = bundle.attributeLevelUp {
            output.append(.attributeLevelUp(area: attribute.area, level: attribute.level))
        }
        for quest in bundle.completedQuests {
            output.append(.questCompleted(title: quest))
        }
        return output
    }
}
