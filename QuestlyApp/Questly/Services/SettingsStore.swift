import SwiftUI
import QuestlyKit

/// Préférences de l'utilisateur, persistées dans `UserDefaults`.
/// Tout est exposé en une seule classe observable pour éviter de disséminer
/// des `@AppStorage` dans toutes les vues.
@Observable
final class SettingsStore {

    // MARK: Clés

    private enum Key {
        static let themeID = "settings.themeID"
        static let hapticsEnabled = "settings.haptics"
        static let soundEnabled = "settings.sound"
        static let firstWeekday = "settings.firstWeekday"
        static let workStartMinute = "settings.workStart"
        static let workEndMinute = "settings.workEnd"
        static let peakStartMinute = "settings.peakStart"
        static let peakEndMinute = "settings.peakEnd"
        static let workingWeekdays = "settings.workingWeekdays"
        static let defaultDueHour = "settings.defaultDueHour"
        static let defaultReminderMinutes = "settings.defaultReminder"
        static let showCompletedTasks = "settings.showCompleted"
        static let confettiEnabled = "settings.confetti"
        static let calendarSyncEnabled = "settings.calendarSync"
        static let dailyReviewHour = "settings.dailyReviewHour"
        static let focusDuration = "settings.focusDuration"
        static let breakDuration = "settings.breakDuration"
        static let longBreakDuration = "settings.longBreakDuration"
        static let sessionsBeforeLongBreak = "settings.sessionsBeforeLongBreak"
        static let reduceMotion = "settings.reduceMotion"
        static let hasSeenOnboarding = "settings.onboarding"
    }

    private let defaults: UserDefaults

    // MARK: Propriétés

    var themeID: String { didSet { defaults.set(themeID, forKey: Key.themeID) } }
    var hapticsEnabled: Bool {
        didSet {
            defaults.set(hapticsEnabled, forKey: Key.hapticsEnabled)
            Haptics.isEnabled = hapticsEnabled
        }
    }
    var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Key.soundEnabled) } }
    var confettiEnabled: Bool { didSet { defaults.set(confettiEnabled, forKey: Key.confettiEnabled) } }
    var reduceMotion: Bool { didSet { defaults.set(reduceMotion, forKey: Key.reduceMotion) } }

    var firstWeekday: Int { didSet { defaults.set(firstWeekday, forKey: Key.firstWeekday) } }
    var workStartMinute: Int { didSet { defaults.set(workStartMinute, forKey: Key.workStartMinute) } }
    var workEndMinute: Int { didSet { defaults.set(workEndMinute, forKey: Key.workEndMinute) } }
    var peakStartMinute: Int { didSet { defaults.set(peakStartMinute, forKey: Key.peakStartMinute) } }
    var peakEndMinute: Int { didSet { defaults.set(peakEndMinute, forKey: Key.peakEndMinute) } }
    var workingWeekdays: [Int] { didSet { defaults.set(workingWeekdays, forKey: Key.workingWeekdays) } }

    var defaultDueHour: Int { didSet { defaults.set(defaultDueHour, forKey: Key.defaultDueHour) } }
    var defaultReminderMinutes: Int { didSet { defaults.set(defaultReminderMinutes, forKey: Key.defaultReminderMinutes) } }
    var showCompletedTasks: Bool { didSet { defaults.set(showCompletedTasks, forKey: Key.showCompletedTasks) } }
    var calendarSyncEnabled: Bool { didSet { defaults.set(calendarSyncEnabled, forKey: Key.calendarSyncEnabled) } }
    var dailyReviewHour: Int { didSet { defaults.set(dailyReviewHour, forKey: Key.dailyReviewHour) } }

    var focusDuration: Int { didSet { defaults.set(focusDuration, forKey: Key.focusDuration) } }
    var breakDuration: Int { didSet { defaults.set(breakDuration, forKey: Key.breakDuration) } }
    var longBreakDuration: Int { didSet { defaults.set(longBreakDuration, forKey: Key.longBreakDuration) } }
    var sessionsBeforeLongBreak: Int { didSet { defaults.set(sessionsBeforeLongBreak, forKey: Key.sessionsBeforeLongBreak) } }

    var hasSeenOnboarding: Bool { didSet { defaults.set(hasSeenOnboarding, forKey: Key.hasSeenOnboarding) } }

    // MARK: Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        func int(_ key: String, _ fallback: Int) -> Int {
            defaults.object(forKey: key) as? Int ?? fallback
        }
        func bool(_ key: String, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key) as? Bool ?? fallback
        }

        self.themeID = defaults.string(forKey: Key.themeID) ?? ThemeCatalog.default.id
        self.hapticsEnabled = bool(Key.hapticsEnabled, true)
        self.soundEnabled = bool(Key.soundEnabled, true)
        self.confettiEnabled = bool(Key.confettiEnabled, true)
        self.reduceMotion = bool(Key.reduceMotion, false)
        self.firstWeekday = int(Key.firstWeekday, 2)
        self.workStartMinute = int(Key.workStartMinute, 9 * 60)
        self.workEndMinute = int(Key.workEndMinute, 18 * 60)
        self.peakStartMinute = int(Key.peakStartMinute, 9 * 60)
        self.peakEndMinute = int(Key.peakEndMinute, 12 * 60)
        self.workingWeekdays = defaults.array(forKey: Key.workingWeekdays) as? [Int] ?? [2, 3, 4, 5, 6]
        self.defaultDueHour = int(Key.defaultDueHour, 9)
        self.defaultReminderMinutes = int(Key.defaultReminderMinutes, 15)
        self.showCompletedTasks = bool(Key.showCompletedTasks, false)
        self.calendarSyncEnabled = bool(Key.calendarSyncEnabled, false)
        self.dailyReviewHour = int(Key.dailyReviewHour, 20)
        self.focusDuration = int(Key.focusDuration, 25)
        self.breakDuration = int(Key.breakDuration, 5)
        self.longBreakDuration = int(Key.longBreakDuration, 15)
        self.sessionsBeforeLongBreak = int(Key.sessionsBeforeLongBreak, 4)
        self.hasSeenOnboarding = bool(Key.hasSeenOnboarding, false)

        Haptics.isEnabled = self.hapticsEnabled
    }

    // MARK: Dérivés

    var calendar: Calendar {
        .questly(timeZone: .current, firstWeekday: firstWeekday)
    }

    var workingHours: WorkingHours {
        WorkingHours(
            startMinute: workStartMinute,
            endMinute: workEndMinute,
            weekdays: Set(workingWeekdays),
            peakStartMinute: peakStartMinute,
            peakEndMinute: peakEndMinute
        )
    }

    /// Animation à utiliser : neutralisée si l'utilisateur préfère la sobriété.
    func animation(_ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }

    func resetToDefaults() {
        themeID = ThemeCatalog.default.id
        hapticsEnabled = true
        soundEnabled = true
        confettiEnabled = true
        reduceMotion = false
        firstWeekday = 2
        workStartMinute = 9 * 60
        workEndMinute = 18 * 60
        peakStartMinute = 9 * 60
        peakEndMinute = 12 * 60
        workingWeekdays = [2, 3, 4, 5, 6]
        defaultDueHour = 9
        defaultReminderMinutes = 15
        showCompletedTasks = false
        dailyReviewHour = 20
        focusDuration = 25
        breakDuration = 5
        longBreakDuration = 15
        sessionsBeforeLongBreak = 4
    }
}
