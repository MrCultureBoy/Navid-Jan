import Foundation
import UserNotifications
import QuestlyKit

/// Rappels locaux : échéances, revue du soir, série en danger.
///
/// Le ton des notifications suit celui du jeu — jamais culpabilisant, toujours
/// une porte de sortie en un geste.
@MainActor
@Observable
final class NotificationService {

    enum Authorization {
        case unknown
        case granted
        case denied
    }

    private(set) var authorization: Authorization = .unknown

    private let center = UNUserNotificationCenter.current()

    static let taskCategory = "QUESTLY_TASK"
    static let reviewCategory = "QUESTLY_REVIEW"

    // MARK: Autorisation

    func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            authorization = .granted
        case .denied:
            authorization = .denied
        default:
            authorization = .unknown
        }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            authorization = granted ? .granted : .denied
            if granted { registerCategories() }
            return granted
        } catch {
            authorization = .denied
            return false
        }
    }

    func registerCategories() {
        let complete = UNNotificationAction(
            identifier: "COMPLETE",
            title: "Accomplir",
            options: [.authenticationRequired]
        )
        let snooze = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Repousser d'une heure",
            options: []
        )
        let taskCategory = UNNotificationCategory(
            identifier: Self.taskCategory,
            actions: [complete, snooze],
            intentIdentifiers: [],
            options: []
        )
        let reviewCategory = UNNotificationCategory(
            identifier: Self.reviewCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([taskCategory, reviewCategory])
    }

    // MARK: Échéances

    func identifier(for task: TaskItem) -> String {
        "task.\(task.identifier.uuidString)"
    }

    /// (Re)programme le rappel d'une quête. Sans échéance ou une fois accomplie,
    /// le rappel est simplement retiré.
    func schedule(for task: TaskItem, calendar: Calendar = .questly(), defaultHour: Int = 9) {
        let id = identifier(for: task)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard task.isOpen, let dueDate = task.dueDate else { return }

        var fireDate = task.hasTime
            ? dueDate
            : calendar.setting(hour: defaultHour, minute: 0, of: dueDate)

        if let offset = task.reminderMinutesBefore, offset > 0 {
            fireDate = fireDate.addingTimeInterval(TimeInterval(-offset * 60))
        }
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = task.isBoss ? "👑 Un boss t'attend" : "Une quête t'attend"
        content.body = task.title
        content.sound = .default
        content.categoryIdentifier = Self.taskCategory
        content.userInfo = ["taskID": task.identifier.uuidString]
        if task.previewXP > 0 {
            content.subtitle = "+\(task.previewXP) XP à la clé"
        }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancel(for task: TaskItem) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier(for: task)])
    }

    func rescheduleAll(tasks: [TaskItem], calendar: Calendar, defaultHour: Int) {
        for task in tasks {
            schedule(for: task, calendar: calendar, defaultHour: defaultHour)
        }
    }

    // MARK: Rendez-vous quotidiens

    /// Revue du soir : un rappel doux pour boucler la journée et préparer demain.
    func scheduleDailyReview(hour: Int, minute: Int = 0) {
        let id = "daily.review"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Revue du soir"
        content.body = "Deux minutes pour clore la journée et préparer demain."
        content.sound = .default
        content.categoryIdentifier = Self.reviewCategory

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Filet de sécurité : prévient en fin de journée si la série va tomber.
    func scheduleStreakReminder(hour: Int = 20, minute: Int = 30, streak: Int) {
        let id = "streak.risk"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard streak > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "🔥 Série de \(streak) jours"
        content.body = "Une seule quête suffit à la garder en vie."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancelStreakReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["streak.risk"])
    }

    /// Notification immédiate de fin de session de concentration.
    func notifyFocusFinished(taskTitle: String, minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Session terminée"
        content.body = taskTitle.isEmpty
            ? "\(minutes) minutes de concentration au compteur."
            : "\(minutes) min sur « \(taskTitle) ». Bien joué."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger))
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
