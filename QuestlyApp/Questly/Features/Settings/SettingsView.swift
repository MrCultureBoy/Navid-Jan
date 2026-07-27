import SwiftUI
import SwiftData
import UIKit
import QuestlyKit

/// Réglages. Chaque option existe parce qu'une personne réelle pourrait avoir
/// besoin de l'inverse du réglage par défaut.
struct SettingsView: View {

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(ThemeManager.self) private var themeManager
    @Environment(NotificationService.self) private var notifications
    @Environment(CalendarService.self) private var calendarService
    @Environment(\.questlyTheme) private var theme

    @Query private var profiles: [PlayerProfile]
    @Query private var tasks: [TaskItem]

    @State private var showsResetConfirmation = false
    @State private var exportURL: URL?
    @State private var exportError: String?

    private var player: PlayerProfile? { profiles.first }

    var body: some View {
        Form {
            appearanceSection
            notificationSection
            calendarSection
            focusSection
            planningSection
            dataSection
            aboutSection
        }
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Tout réinitialiser ?",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Réinitialiser les réglages", role: .destructive) {
                settings.resetToDefaults()
                themeManager.select(id: settings.themeID)
            }
        } message: {
            Text("Tes quêtes et ta progression ne sont pas touchées.")
        }
        .sheet(item: exportBinding) { wrapper in
            ShareSheet(url: wrapper.url)
        }
    }

    // MARK: Apparence

    private var appearanceSection: some View {
        Section("Ambiance") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metrics.spacingS) {
                    ForEach(ThemeCatalog.all) { candidate in
                        themeChip(candidate)
                    }
                }
                .padding(.vertical, 4)
            }

            Toggle(isOn: Binding(
                get: { settings.confettiEnabled },
                set: { settings.confettiEnabled = $0 }
            )) {
                Label("Confettis et fanfares", systemImage: "sparkles")
            }

            Toggle(isOn: Binding(
                get: { settings.hapticsEnabled },
                set: { settings.hapticsEnabled = $0 }
            )) {
                Label("Retour haptique", systemImage: "iphone.radiowaves.left.and.right")
            }

            Toggle(isOn: Binding(
                get: { settings.reduceMotion },
                set: { settings.reduceMotion = $0 }
            )) {
                Label("Réduire les animations", systemImage: "tortoise.fill")
            }
        }
    }

    private func themeChip(_ candidate: QuestlyTheme) -> some View {
        let owned = themeManager.isUnlocked(candidate, ownedItems: player?.unlockedItems ?? [])
        let isSelected = settings.themeID == candidate.id

        return Button {
            guard owned else {
                Haptics.warning()
                return
            }
            settings.themeID = candidate.id
            themeManager.select(id: candidate.id)
            Haptics.selection()
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(candidate.gradient)
                        .frame(width: 44, height: 44)
                    if !owned {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    } else if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay {
                    Circle().strokeBorder(isSelected ? Color.primary : .clear, lineWidth: 2)
                }

                Text(candidate.name)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(owned ? .primary : .secondary)
            }
            .frame(width: 62)
        }
        .buttonStyle(.plain)
    }

    // MARK: Notifications

    private var notificationSection: some View {
        Section {
            HStack {
                Label("Autorisation", systemImage: "bell.badge.fill")
                Spacer()
                switch notifications.authorization {
                case .granted:
                    Text("Accordée").foregroundStyle(Color(hex: "30D158")).font(.questCaption)
                case .denied:
                    Text("Refusée").foregroundStyle(Color(hex: "FF453A")).font(.questCaption)
                case .unknown:
                    Button("Autoriser") {
                        Task {
                            let granted = await notifications.requestAuthorization()
                            if granted { rescheduleAllReminders() }
                        }
                    }
                    .font(.questCaption)
                }
            }

            Picker(selection: Binding(
                get: { settings.dailyReviewHour },
                set: {
                    settings.dailyReviewHour = $0
                    notifications.scheduleDailyReview(hour: $0)
                }
            )) {
                ForEach(6...23, id: \.self) { hour in
                    Text("\(hour) h").tag(hour)
                }
            } label: {
                Label("Revue du soir", systemImage: "moon.stars.fill")
            }

            Picker(selection: Binding(
                get: { settings.defaultReminderMinutes },
                set: { settings.defaultReminderMinutes = $0 }
            )) {
                Text("À l'heure").tag(0)
                Text("5 min avant").tag(5)
                Text("15 min avant").tag(15)
                Text("30 min avant").tag(30)
                Text("1 h avant").tag(60)
            } label: {
                Label("Rappel par défaut", systemImage: "bell.fill")
            }

            Button {
                rescheduleAllReminders()
            } label: {
                Label("Reprogrammer tous les rappels", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Un rappel de série est envoyé en soirée uniquement si ta série est en danger.")
        }
    }

    private func rescheduleAllReminders() {
        notifications.rescheduleAll(
            tasks: tasks.filter(\.isOpen),
            calendar: settings.calendar,
            defaultHour: settings.defaultDueHour
        )
        notifications.scheduleDailyReview(hour: settings.dailyReviewHour)
        notifications.scheduleStreakReminder(streak: store.streak.current)
        Haptics.success()
    }

    // MARK: Calendrier

    private var calendarSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings.calendarSyncEnabled },
                set: { newValue in
                    settings.calendarSyncEnabled = newValue
                    if newValue {
                        Task { await calendarService.requestAccess() }
                    }
                }
            )) {
                Label("Afficher le calendrier iOS", systemImage: "calendar.badge.clock")
            }

            Picker(selection: Binding(
                get: { settings.firstWeekday },
                set: { settings.firstWeekday = $0 }
            )) {
                Text("Lundi").tag(2)
                Text("Dimanche").tag(1)
                Text("Samedi").tag(7)
            } label: {
                Label("Premier jour de la semaine", systemImage: "calendar")
            }

            Picker(selection: Binding(
                get: { settings.defaultDueHour },
                set: { settings.defaultDueHour = $0 }
            )) {
                ForEach(6...22, id: \.self) { hour in
                    Text("\(hour) h").tag(hour)
                }
            } label: {
                Label("Heure par défaut", systemImage: "clock")
            }
        } header: {
            Text("Calendrier")
        } footer: {
            Text("Les évènements du calendrier système restent en lecture seule : ils bloquent les créneaux sans jamais être modifiés.")
        }
    }

    // MARK: Concentration

    private var focusSection: some View {
        Section("Concentration") {
            Stepper(value: Binding(
                get: { settings.focusDuration },
                set: { settings.focusDuration = $0 }
            ), in: 5...120, step: 5) {
                Label("Session : \(settings.focusDuration) min", systemImage: "timer")
            }

            Stepper(value: Binding(
                get: { settings.breakDuration },
                set: { settings.breakDuration = $0 }
            ), in: 1...30) {
                Label("Pause : \(settings.breakDuration) min", systemImage: "cup.and.saucer.fill")
            }

            Stepper(value: Binding(
                get: { settings.longBreakDuration },
                set: { settings.longBreakDuration = $0 }
            ), in: 5...60, step: 5) {
                Label("Grande pause : \(settings.longBreakDuration) min", systemImage: "figure.walk")
            }

            Stepper(value: Binding(
                get: { settings.sessionsBeforeLongBreak },
                set: { settings.sessionsBeforeLongBreak = $0 }
            ), in: 2...8) {
                Label("Cycles avant grande pause : \(settings.sessionsBeforeLongBreak)", systemImage: "repeat")
            }
        }
    }

    // MARK: Planification

    private var planningSection: some View {
        Section {
            HStack {
                Label("Journée de travail", systemImage: "sun.max.fill")
                Spacer()
                Text("\(settings.workStartMinute / 60) h – \(settings.workEndMinute / 60) h")
                    .font(.questCaption)
                    .foregroundStyle(.secondary)
            }

            Stepper(value: Binding(
                get: { settings.workStartMinute / 60 },
                set: { settings.workStartMinute = $0 * 60 }
            ), in: 0...12) {
                Text("Début : \(settings.workStartMinute / 60) h").font(.questCaption)
            }

            Stepper(value: Binding(
                get: { settings.workEndMinute / 60 },
                set: { settings.workEndMinute = $0 * 60 }
            ), in: 13...23) {
                Text("Fin : \(settings.workEndMinute / 60) h").font(.questCaption)
            }

            HStack {
                Label("Pic d'énergie", systemImage: "bolt.fill")
                Spacer()
                Text("\(settings.peakStartMinute / 60) h – \(settings.peakEndMinute / 60) h")
                    .font(.questCaption)
                    .foregroundStyle(.secondary)
            }

            Stepper(value: Binding(
                get: { settings.peakStartMinute / 60 },
                set: {
                    settings.peakStartMinute = $0 * 60
                    if settings.peakEndMinute <= settings.peakStartMinute {
                        settings.peakEndMinute = min(23, $0 + 3) * 60
                    }
                }
            ), in: 0...20) {
                Text("Début du pic : \(settings.peakStartMinute / 60) h").font(.questCaption)
            }

            weekdaySelector
        } header: {
            Text("Planification")
        } footer: {
            Text("Le planificateur place les quêtes exigeantes dans ta fenêtre de pointe et laisse les petites boucher les trous.")
        }
    }

    private var weekdaySelector: some View {
        let names = ["D", "L", "M", "M", "J", "V", "S"]
        return HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { weekday in
                let isOn = settings.workingWeekdays.contains(weekday)
                Button {
                    var current = Set(settings.workingWeekdays)
                    if isOn { current.remove(weekday) } else { current.insert(weekday) }
                    settings.workingWeekdays = Array(current).sorted()
                    Haptics.selection()
                } label: {
                    Text(names[weekday - 1])
                        .font(.questCaption)
                        .foregroundStyle(isOn ? .white : .secondary)
                        .frame(width: 32, height: 32)
                        .background {
                            Circle().fill(isOn
                                          ? AnyShapeStyle(theme.gradient)
                                          : AnyShapeStyle(Color.primary.opacity(0.07)))
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Données

    private var dataSection: some View {
        Section {
            Button {
                exportData()
            } label: {
                Label("Exporter mes données (JSON)", systemImage: "square.and.arrow.up")
            }

            Button {
                store.rescheduleOverdueToToday()
                Haptics.success()
            } label: {
                Label("Reporter tout le retard à aujourd'hui", systemImage: "arrow.uturn.forward")
            }

            Button(role: .destructive) {
                showsResetConfirmation = true
            } label: {
                Label("Réinitialiser les réglages", systemImage: "arrow.counterclockwise")
            }
        } header: {
            Text("Données")
        } footer: {
            if let exportError {
                Text(exportError).foregroundStyle(Color(hex: "FF453A"))
            } else {
                Text("L'export contient tes quêtes, projets, sessions et progression, dans un format lisible.")
            }
        }
    }

    // MARK: À propos

    private var aboutSection: some View {
        Section("À propos") {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text(Bundle.main.appVersion).foregroundStyle(.secondary).font(.questCaption)
            }
            HStack {
                Label("Quêtes en base", systemImage: "tray.full")
                Spacer()
                Text("\(tasks.count)").foregroundStyle(.secondary).font(.questCaption)
            }
            HStack {
                Label("Aventure démarrée le", systemImage: "flag.fill")
                Spacer()
                Text(player.map { QuestlyFormat.longDate($0.createdAt) } ?? "—")
                    .foregroundStyle(.secondary)
                    .font(.questCaption)
            }
        }
    }

    // MARK: Export

    private struct ExportWrapper: Identifiable {
        let id = UUID()
        let url: URL
    }

    private var exportBinding: Binding<ExportWrapper?> {
        Binding(
            get: { exportURL.map { ExportWrapper(url: $0) } },
            set: { if $0 == nil { exportURL = nil } }
        )
    }

    private func exportData() {
        do {
            let url = try DataExporter.export(
                tasks: tasks,
                player: player,
                events: store.completionEvents(),
                calendar: settings.calendar
            )
            exportURL = url
            exportError = nil
            Haptics.success()
        } catch {
            exportError = "Export impossible : \(error.localizedDescription)"
            Haptics.warning()
        }
    }
}

// MARK: - Partage

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Export JSON

enum DataExporter {

    struct Payload: Encodable {
        struct ExportedTask: Encodable {
            let title: String
            let notes: String
            let dueDate: Date?
            let completedAt: Date?
            let priority: Int
            let difficulty: Int
            let lifeArea: String?
            let isBoss: Bool
            let estimatedMinutes: Int
            let focusedMinutes: Int
            let earnedXP: Int
            let tags: [String]
            let project: String?
            let subtasks: [String]
        }

        struct ExportedEvent: Encodable {
            let date: Date
            let title: String
            let xp: Int
            let onTime: Bool
        }

        let exportedAt: Date
        let level: Int
        let totalXP: Int
        let coins: Int
        let gems: Int
        let longestStreak: Int
        let tasks: [ExportedTask]
        let history: [ExportedEvent]
    }

    static func export(
        tasks: [TaskItem],
        player: PlayerProfile?,
        events: [CompletionEvent],
        calendar: Calendar
    ) throws -> URL {
        let payload = Payload(
            exportedAt: Date(),
            level: player?.level ?? 1,
            totalXP: player?.totalXP ?? 0,
            coins: player?.coins ?? 0,
            gems: player?.gems ?? 0,
            longestStreak: player?.longestStreak ?? 0,
            tasks: tasks.map { task in
                Payload.ExportedTask(
                    title: task.title,
                    notes: task.notes,
                    dueDate: task.dueDate,
                    completedAt: task.completedAt,
                    priority: task.priorityRaw,
                    difficulty: task.difficultyRaw,
                    lifeArea: task.lifeAreaRaw,
                    isBoss: task.isBoss,
                    estimatedMinutes: task.estimatedMinutes,
                    focusedMinutes: task.focusedMinutes,
                    earnedXP: task.earnedXP,
                    tags: task.sortedTags.map(\.name),
                    project: task.project?.name,
                    subtasks: task.orderedSubtasks.map(\.title)
                )
            },
            history: events.map {
                Payload.ExportedEvent(date: $0.date, title: $0.taskTitle, xp: $0.xp, onTime: $0.wasOnTime)
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "questly-\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
