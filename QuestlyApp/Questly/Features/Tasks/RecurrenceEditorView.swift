import SwiftUI
import SwiftData
import QuestlyKit

/// Éditeur de répétition. Il couvre les cas courants en deux gestes et laisse
/// accessibles les cas rares (tous les 3 mois, le dernier jour, 12 fois).
struct RecurrenceEditorView: View {

    @Bindable var task: TaskItem

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(\.questlyTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var isEnabled = false
    @State private var frequency: RecurrenceRule.Frequency = .daily
    @State private var interval = 1
    @State private var weekdays: Set<Int> = []
    @State private var daysOfMonth: Set<Int> = []
    @State private var usesLastDay = false
    @State private var mode: RecurrenceRule.Mode = .fixed
    @State private var skipWeekends = false
    @State private var endKind: EndKind = .never
    @State private var occurrenceCount = 10
    @State private var endDate = Date().addingTimeInterval(60 * 60 * 24 * 30)

    private enum EndKind: String, CaseIterable, Identifiable {
        case never, afterCount, onDate
        var id: String { rawValue }
        var label: String {
            switch self {
            case .never: return "Jamais"
            case .afterCount: return "Après N fois"
            case .onDate: return "À une date"
            }
        }
    }

    private var calendar: Calendar { settings.calendar }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $isEnabled.animation(Motion.snappy)) {
                        Label("Répéter cette quête", systemImage: "repeat")
                    }
                    if isEnabled {
                        Text(previewRule.humanDescription(calendar: calendar))
                            .font(.questCallout)
                            .foregroundStyle(theme.accent)
                    }
                }

                if isEnabled {
                    presetSection
                    frequencySection
                    if frequency == .weekly { weekdaySection }
                    if frequency == .monthly { monthDaySection }
                    modeSection
                    endSection
                    previewSection
                }
            }
            .navigationTitle("Répétition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { apply(); dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: load)
        }
    }

    // MARK: Sections

    private var presetSection: some View {
        Section("Raccourcis") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    presetChip("Chaque jour", rule: .daily)
                    presetChip("Jours ouvrés", rule: .weekdaysOnly)
                    presetChip("Chaque semaine", rule: .weekly)
                    presetChip("Week-ends", rule: .weekendsOnly)
                    presetChip("Chaque mois", rule: .monthly)
                    presetChip("Chaque année", rule: .yearly)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func presetChip(_ title: String, rule: RecurrenceRule) -> some View {
        Button {
            adopt(rule)
            Haptics.selection()
        } label: {
            Text(title)
                .font(.questMicro)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background { Capsule().fill(Color.primary.opacity(0.07)) }
        }
        .buttonStyle(.plain)
    }

    private var frequencySection: some View {
        Section("Rythme") {
            Picker("Unité", selection: $frequency) {
                ForEach(RecurrenceRule.Frequency.allCases) { value in
                    Text(value.label).tag(value)
                }
            }
            .pickerStyle(.segmented)

            Stepper(value: $interval, in: 1...99) {
                Text(interval == 1
                     ? "Chaque \(frequency.label.lowercased())"
                     : "Tous les \(interval) \(frequency.pluralLabel)")
            }

            if frequency == .daily {
                Toggle("Sauter les week-ends", isOn: $skipWeekends)
            }
        }
    }

    private var weekdaySection: some View {
        Section("Jours de la semaine") {
            HStack(spacing: 6) {
                ForEach(orderedWeekdays, id: \.self) { weekday in
                    Button {
                        toggleWeekday(weekday)
                    } label: {
                        Text(weekdayInitial(weekday))
                            .font(.questCaption)
                            .foregroundStyle(weekdays.contains(weekday) ? .white : .primary)
                            .frame(width: 36, height: 36)
                            .background {
                                Circle().fill(weekdays.contains(weekday)
                                              ? AnyShapeStyle(theme.gradient)
                                              : AnyShapeStyle(Color.primary.opacity(0.07)))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var monthDaySection: some View {
        Section("Jour du mois") {
            Toggle("Dernier jour du mois", isOn: $usesLastDay.animation(Motion.quick))

            if !usesLastDay {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                    ForEach(1...31, id: \.self) { day in
                        Button {
                            toggleDayOfMonth(day)
                        } label: {
                            Text("\(day)")
                                .font(.questMicro)
                                .foregroundStyle(daysOfMonth.contains(day) ? .white : .primary)
                                .frame(width: 32, height: 32)
                                .background {
                                    Circle().fill(daysOfMonth.contains(day)
                                                  ? AnyShapeStyle(theme.gradient)
                                                  : AnyShapeStyle(Color.primary.opacity(0.07)))
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        } footer: {
            Text("Si le mois est trop court, l'occurrence tombe sur le dernier jour disponible.")
        }
    }

    private var modeSection: some View {
        Section {
            Picker("Point de départ", selection: $mode) {
                ForEach(RecurrenceRule.Mode.allCases, id: \.self) { value in
                    Text(value.label).tag(value)
                }
            }
        } footer: {
            Text(mode == .fixed
                 ? "Le calendrier commande : rater une occurrence ne décale pas les suivantes."
                 : "La prochaine échéance part du jour où tu accomplis la quête. Idéal pour « arroser les plantes tous les 3 jours ».")
        }
    }

    private var endSection: some View {
        Section("Fin de la série") {
            Picker("Se termine", selection: $endKind) {
                ForEach(EndKind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }

            if endKind == .afterCount {
                Stepper("Après \(occurrenceCount) occurrences", value: $occurrenceCount, in: 1...365)
            }
            if endKind == .onDate {
                DatePicker("Jusqu'au", selection: $endDate, displayedComponents: [.date])
            }
        }
    }

    private var previewSection: some View {
        Section("Prochaines occurrences") {
            ForEach(previewDates, id: \.self) { date in
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(theme.accent)
                    Text(QuestlyFormat.fullDay(date, calendar: calendar))
                        .font(.questCaption)
                    Spacer()
                    if task.hasTime {
                        Text(QuestlyFormat.time(date, calendar: calendar))
                            .font(.questMicro)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if previewDates.isEmpty {
                Text("Aucune occurrence à venir avec ces réglages.")
                    .font(.questCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Données

    private var orderedWeekdays: [Int] {
        let first = calendar.firstWeekday
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    private func weekdayInitial(_ weekday: Int) -> String {
        let initials = ["D", "L", "M", "M", "J", "V", "S"]
        return initials[(weekday - 1) % 7]
    }

    private var previewRule: RecurrenceRule {
        var days = daysOfMonth
        if usesLastDay { days = [-1] }

        let ending: RecurrenceRule.Ending
        switch endKind {
        case .never: ending = .never
        case .afterCount: ending = .afterOccurrences(occurrenceCount)
        case .onDate: ending = .onDate(endDate)
        }

        return RecurrenceRule(
            frequency: frequency,
            interval: interval,
            weekdays: frequency == .weekly ? weekdays : [],
            daysOfMonth: frequency == .monthly ? days : [],
            monthsOfYear: [],
            ending: ending,
            mode: mode,
            skipWeekends: skipWeekends
        )
    }

    private var previewDates: [Date] {
        let anchor = task.dueDate ?? Date()
        return RecurrenceEngine.occurrences(
            rule: previewRule,
            anchor: anchor,
            from: anchor,
            to: calendar.date(byAdding: .month, value: 6, to: anchor) ?? anchor,
            calendar: calendar,
            limit: 5
        )
    }

    // MARK: Chargement / enregistrement

    private func load() {
        guard let rule = task.recurrence else {
            isEnabled = false
            weekdays = [calendar.component(.weekday, from: task.dueDate ?? Date())]
            return
        }
        isEnabled = true
        frequency = rule.frequency
        interval = rule.interval
        weekdays = rule.weekdays.isEmpty
            ? [calendar.component(.weekday, from: task.dueDate ?? Date())]
            : rule.weekdays
        usesLastDay = rule.daysOfMonth == [-1]
        daysOfMonth = usesLastDay ? [] : rule.daysOfMonth
        mode = rule.mode
        skipWeekends = rule.skipWeekends

        switch rule.ending {
        case .never:
            endKind = .never
        case .afterOccurrences(let count):
            endKind = .afterCount
            occurrenceCount = count
        case .onDate(let date):
            endKind = .onDate
            endDate = date
        }
    }

    private func adopt(_ rule: RecurrenceRule) {
        frequency = rule.frequency
        interval = rule.interval
        weekdays = rule.weekdays.isEmpty
            ? [calendar.component(.weekday, from: task.dueDate ?? Date())]
            : rule.weekdays
        daysOfMonth = rule.daysOfMonth
        usesLastDay = rule.daysOfMonth == [-1]
        skipWeekends = rule.skipWeekends
        mode = rule.mode
    }

    private func apply() {
        if isEnabled {
            if task.dueDate == nil {
                task.dueDate = calendar.setting(hour: settings.defaultDueHour, minute: 0, of: Date())
                task.status = .active
            }
            task.recurrenceAnchor = task.dueDate
            task.recurrence = previewRule
        } else {
            task.recurrence = nil
        }
        task.touch()
        store.save()
    }

    private func toggleWeekday(_ weekday: Int) {
        if weekdays.contains(weekday) {
            if weekdays.count > 1 { weekdays.remove(weekday) }
        } else {
            weekdays.insert(weekday)
        }
        Haptics.selection()
    }

    private func toggleDayOfMonth(_ day: Int) {
        if daysOfMonth.contains(day) {
            daysOfMonth.remove(day)
        } else {
            daysOfMonth.insert(day)
        }
        Haptics.selection()
    }
}

// MARK: - Recherche de créneau

/// Propose les prochains créneaux libres pour une quête et les réserve d'un tap.
struct SchedulerSheet: View {

    let task: TaskItem

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(CalendarService.self) private var calendarService
    @Environment(\.questlyTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var suggestions: [TimeSlot] = []

    private var calendar: Calendar { settings.calendar }
    private var duration: Int { task.estimatedMinutes > 0 ? task.estimatedMinutes : 30 }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("Durée réservée", systemImage: "hourglass")
                        Spacer()
                        Text(DurationFormatter.short(minutes: duration))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Créneaux libres") {
                    if suggestions.isEmpty {
                        Text("Aucun créneau libre trouvé dans les 7 prochains jours ouvrés.")
                            .font(.questCaption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(suggestions) { slot in
                        Button {
                            store.schedule(task, at: slot.start, minutes: duration)
                            Haptics.success()
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(QuestlyFormat.fullDay(slot.start, calendar: calendar))
                                        .font(.questCallout)
                                    Text("\(QuestlyFormat.time(slot.start, calendar: calendar)) – \(QuestlyFormat.time(slot.end, calendar: calendar))")
                                        .font(.questMicro)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(theme.accent)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Trouver un créneau")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onAppear(perform: computeSuggestions)
        }
    }

    private func computeSuggestions() {
        var busyByDay: [Date: [BusyInterval]] = [:]
        for offset in 0..<7 {
            let day = calendar.startOfDay(for: Date().adding(days: offset, calendar: calendar))
            var intervals = store.blocks(on: day).map {
                BusyInterval(id: $0.identifier.uuidString, start: $0.start, end: $0.end, title: $0.title)
            }
            intervals.append(contentsOf: calendarService.busyIntervals(on: day, calendar: calendar))
            busyByDay[day] = intervals
        }

        suggestions = ScheduleEngine.suggestSlots(
            forMinutes: duration,
            startingFrom: Date(),
            days: 7,
            busyByDay: busyByDay,
            workingHours: settings.workingHours,
            limit: 6,
            calendar: calendar
        )
    }
}
