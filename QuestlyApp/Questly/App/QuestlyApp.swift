import SwiftUI
import SwiftData
import QuestlyKit

@main
struct QuestlyApp: App {

    let container: ModelContainer

    @State private var store: QuestlyStore
    @State private var settings: SettingsStore
    @State private var themeManager: ThemeManager
    @State private var notifications = NotificationService()
    @State private var calendarService = CalendarService()

    init() {
        let container = AppContainer.shared
        self.container = container

        let settings = SettingsStore()
        _settings = State(initialValue: settings)
        _themeManager = State(initialValue: ThemeManager(id: settings.themeID))
        _store = State(initialValue: QuestlyStore(
            modelContext: container.mainContext,
            calendar: settings.calendar
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(settings)
                .environment(themeManager)
                .environment(notifications)
                .environment(calendarService)
                .environment(\.questlyTheme, themeManager.current)
                .tint(themeManager.current.accent)
        }
        .modelContainer(container)
    }
}
