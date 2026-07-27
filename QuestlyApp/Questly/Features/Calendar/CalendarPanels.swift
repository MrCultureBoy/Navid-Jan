import SwiftUI
import SwiftData
import QuestlyKit

// MARK: - Journée détaillée sous la grille du mois

/// Ce qui rend la vue Mois réellement exploitable : la journée sélectionnée
/// s'ouvre juste en dessous, avec ses créneaux et ses quêtes.
struct DayAgendaPanel: View {

    let date: Date
    var onSelectTask: (TaskItem) -> Void

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(CalendarService.self) private var calendarService
    @Environment(\.questlyTheme) private var theme

    @Query private var tasks: [TaskItem]
    @Query private var blocks: [TimeBlock]

    @State private var showsComposer = false

    private var calendar: Calendar { settings.calendar }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacingS) {
                header

                if entries.isEmpty && dayTasks.isEmpty {
                    EmptyStateView(
                        symbolName: "calendar.badge.plus",
                        title: "Journée libre",
                        message: "Rien de prévu le \(QuestlyFormat.fullDay(date, calendar: calendar)).",
                        actionTitle: "Réserver un créneau",
                        action: { showsComposer = true }
                    )
                } else {
                    ForEach(entries) { entry in
                        entryRow(entry)
                    }

                    if !untimedTasks.isEmpty {
                        Text("Sans heure")
                            .font(.questMicro)
                            .foregroundStyle(.secondary)
                            .padding(.top, Metrics.spacingXS)

                        ForEach(untimedTasks) { task in
                            TaskRow(task: task, isCompact: true) { onSelectTask(task) }
                        }
                    }
                }
            }
            .padding(Metrics.spacingM)
            .padding(.bottom, 100)
        }
        .sheet(isPresented: $showsComposer) {
            SlotComposerSheet(start: calendar.setting(hour: settings.defaultDueHour, minute: 0, of: date))
                .presentationDetents([.medium, .large])
        }
    }

    private var header: some View {
        HStack {
            Text(QuestlyFormat.fullDay(date, calendar: calendar))
                .font(.questCallout)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                showsComposer = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(theme.accent)
            }
        }
    }

    private func entryRow(_ entry: TimedEntry) -> some View {
        HStack(alignment: .top, spacing: Metrics.spacingS) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(QuestlyFormat.time(entry.start, calendar: calendar))
                    .font(.questCaption)
                    .monospacedDigit()
                Text(DurationFormatter.short(minutes: entry.durationMinutes))
                    .font(.questMicro)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 54, alignment: .trailing)

            RoundedRectangle(cornerRadius: 2)
                .fill(entry.color)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.questBody)
                    .strikethrough(entry.isCompleted)
                if entry.source == .external {
                    Label("Calendrier iOS", systemImage: "calendar")
                        .font(.questMicro)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if entry.source != .external {
                Button {
                    open(entry)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func open(_ entry: TimedEntry) {
        guard let id = entry.taskIdentifier,
              let task = tasks.first(where: { $0.identifier == id }) else { return }
        onSelectTask(task)
    }

    private var dayTasks: [TaskItem] {
        tasks.filter { $0.isDue(on: date, calendar: calendar) }
    }

    private var untimedTasks: [TaskItem] {
        dayTasks.filter { !$0.hasTime }
            .sorted(by: TaskSorting.smart(calendar: calendar))
    }

    private var entries: [TimedEntry] {
        var output: [TimedEntry] = []
        for block in blocks where calendar.isSameDay(block.start, date) {
            output.append(TimedEntry.from(block: block))
        }
        let scheduled = Set(output.compactMap(\.taskIdentifier))
        for task in dayTasks where task.hasTime && !scheduled.contains(task.identifier) {
            output.append(TimedEntry.from(task: task))
        }
        for event in calendarService.events(on: date, calendar: calendar) where !event.isAllDay {
            output.append(TimedEntry.from(external: event))
        }
        return output.sorted { $0.start < $1.start }
    }
}

// MARK: - Vue année

/// Douze mini-mois teintés par l'activité : la vue d'ensemble d'une année.
struct YearGridView: View {

    @Binding var selectedDate: Date
    var onSelectMonth: (Date) -> Void

    @Environment(SettingsStore.self) private var settings
    @Environment(\.questlyTheme) private var theme

    @Query private var tasks: [TaskItem]

    private var calendar: Calendar { settings.calendar }

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Metrics.spacingS), count: 3),
                spacing: Metrics.spacingM
            ) {
                ForEach(months, id: \.self) { month in
                    MiniMonthView(
                        month: month,
                        activeDays: activeDays(in: month),
                        isCurrentMonth: calendar.isDate(month, equalTo: Date(), toGranularity: .month)
                    )
                    .onTapGesture {
                        onSelectMonth(month)
                        Haptics.selection()
                    }
                }
            }
            .padding(Metrics.spacingM)
            .padding(.bottom, 100)
        }
    }

    private var months: [Date] {
        let year = calendar.component(.year, from: selectedDate)
        return (1...12).compactMap { month in
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = 1
            return calendar.date(from: comps)
        }
    }

    private func activeDays(in month: Date) -> [Date: Int] {
        var output: [Date: Int] = [:]
        let start = calendar.startOfMonth(month)
        let end = calendar.endOfMonth(month)
        for task in tasks {
            guard let due = task.dueDate, due >= start, due <= end else { continue }
            let day = calendar.startOfDay(for: due)
            output[day, default: 0] += 1
        }
        return output
    }
}

struct MiniMonthView: View {

    let month: Date
    let activeDays: [Date: Int]
    let isCurrentMonth: Bool

    @Environment(SettingsStore.self) private var settings
    @Environment(\.questlyTheme) private var theme

    private var calendar: Calendar { settings.calendar }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(QuestlyFormat.month(month, calendar: calendar))
                .font(.questCaption)
                .foregroundStyle(isCurrentMonth ? theme.accent : .primary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 2) {
                ForEach(calendar.monthGrid(for: month), id: \.self) { day in
                    let inMonth = calendar.isDate(day, equalTo: month, toGranularity: .month)
                    let count = activeDays[calendar.startOfDay(for: day)] ?? 0
                    Circle()
                        .fill(fill(count: count, inMonth: inMonth))
                        .frame(width: 6, height: 6)
                        .overlay {
                            if calendar.isSameDay(day, Date()) {
                                Circle().strokeBorder(theme.accent, lineWidth: 1)
                            }
                        }
                }
            }
        }
        .padding(Metrics.spacingS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerRadiusSmall, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cornerRadiusSmall, style: .continuous)
                .strokeBorder(isCurrentMonth ? theme.accent.opacity(0.4) : .clear, lineWidth: 1)
        }
    }

    private func fill(count: Int, inMonth: Bool) -> Color {
        guard inMonth else { return Color.primary.opacity(0.04) }
        switch count {
        case 0: return Color.primary.opacity(0.08)
        case 1: return theme.accent.opacity(0.35)
        case 2...3: return theme.accent.opacity(0.6)
        default: return theme.accent
        }
    }
}

// MARK: - Agenda

/// Liste continue des jours à venir : la vue la plus rapide pour « et après ? ».
struct AgendaListView: View {

    let startDate: Date
    var onSelectTask: (TaskItem) -> Void

    @Environment(SettingsStore.self) private var settings
    @Environment(CalendarService.self) private var calendarService
    @Environment(\.questlyTheme) private var theme

    @Query private var tasks: [TaskItem]
    @Query private var blocks: [TimeBlock]

    @State private var horizon = 45

    private var calendar: Calendar { settings.calendar }

    var body: some View {
        List {
            ForEach(days, id: \.self) { day in
                let dayTasks = openTasks(on: day)
                let dayBlocks = blocks.filter { calendar.isSameDay($0.start, day) }
                let events = calendarService.events(on: day, calendar: calendar)

                if !dayTasks.isEmpty || !dayBlocks.isEmpty || !events.isEmpty {
                    Section {
                        ForEach(dayBlocks.sorted { $0.start < $1.start }) { block in
                            blockRow(block)
                        }
                        ForEach(events) { event in
                            externalRow(event)
                        }
                        ForEach(dayTasks) { task in
                            TaskRow(task: task, isCompact: true) { onSelectTask(task) }
                                .taskSwipeActions(for: task) { onSelectTask(task) }
                        }
                    } header: {
                        HStack {
                            Text(QuestlyFormat.fullDay(day, calendar: calendar))
                            if calendar.isSameDay(day, Date()) {
                                Text("AUJOURD'HUI")
                                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                                    .foregroundStyle(theme.accent)
                            }
                        }
                    }
                }
            }

            Section {
                Button("Charger 45 jours de plus") {
                    withAnimation { horizon += 45 }
                }
                .font(.questCaption)
                Color.clear.frame(height: 80).listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var days: [Date] {
        let start = calendar.startOfDay(for: startDate)
        return (0..<horizon).map { start.adding(days: $0, calendar: calendar) }
    }

    private func openTasks(on day: Date) -> [TaskItem] {
        tasks.filter { $0.isDue(on: day, calendar: calendar) && $0.isOpen }
            .sorted(by: TaskSorting.smart(calendar: calendar))
    }

    private func blockRow(_ block: TimeBlock) -> some View {
        HStack(spacing: Metrics.spacingS) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: block.colorHex))
                .frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(block.title).font(.questCallout)
                Text("\(QuestlyFormat.time(block.start, calendar: calendar)) – \(QuestlyFormat.time(block.end, calendar: calendar))")
                    .font(.questMicro)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "rectangle.fill.badge.checkmark")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func externalRow(_ event: CalendarService.ExternalEvent) -> some View {
        HStack(spacing: Metrics.spacingS) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: event.colorHex))
                .frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title).font(.questCallout)
                Text(event.isAllDay
                     ? "Toute la journée · \(event.calendarName)"
                     : "\(QuestlyFormat.time(event.start, calendar: calendar)) · \(event.calendarName)")
                    .font(.questMicro)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Tiroir des quêtes à placer

/// Bande de quêtes sans créneau, que l'on fait glisser sur la timeline.
struct UnscheduledTray: View {

    let selectedDate: Date

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(\.questlyTheme) private var theme

    @Query private var tasks: [TaskItem]

    private var calendar: Calendar { settings.calendar }

    private var candidates: [TaskItem] {
        tasks
            .filter { $0.isOpen && $0.scheduledBlocks.isEmpty }
            .filter { task in
                guard let due = task.dueDate else { return true }
                return calendar.startOfDay(for: due) <= calendar.startOfDay(for: selectedDate)
            }
            .sorted(by: TaskSorting.smart(calendar: calendar))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("À placer", systemImage: "tray.full.fill")
                    .font(.questMicro)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Glisse une quête sur la timeline")
                    .font(.questMicro)
                    .foregroundStyle(.secondary)
            }

            if candidates.isEmpty {
                Text("Tout est planifié. Impressionnant.")
                    .font(.questCaption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(candidates.prefix(12)) { task in
                            trayChip(task)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.horizontal, Metrics.spacingM)
        .padding(.vertical, Metrics.spacingS)
        .background(.regularMaterial)
    }

    private func trayChip(_ task: TaskItem) -> some View {
        let color = Color(hex: task.lifeArea?.hex ?? task.priority.hex)

        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(task.title)
                .font(.questMicro)
                .lineLimit(1)
            if task.estimatedMinutes > 0 {
                Text(DurationFormatter.short(minutes: task.estimatedMinutes))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background {
            Capsule().fill(color.opacity(0.12))
        }
        .overlay {
            Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1)
        }
        .frame(maxWidth: 190)
        .draggable(task.identifier.uuidString) {
            // Aperçu affiché sous le doigt pendant le glissement.
            Text(task.title)
                .font(.questMicro)
                .padding(8)
                .background { Capsule().fill(color.opacity(0.9)) }
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Plan automatique

/// Résultat de la planification automatique, à valider avant application.
struct AutoPlanSheet: View {

    let result: PlanResult
    let onApply: () -> Void

    @Environment(SettingsStore.self) private var settings
    @Environment(\.questlyTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    private var calendar: Calendar { settings.calendar }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("Temps planifié", systemImage: "clock.fill")
                        Spacer()
                        Text(DurationFormatter.short(minutes: result.usedMinutes))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Temps libre restant", systemImage: "wind")
                        Spacer()
                        Text(DurationFormatter.short(minutes: result.freeMinutes))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Programme proposé") {
                    if result.blocks.isEmpty {
                        Text("Aucun créneau libre trouvé aujourd'hui.")
                            .font(.questCaption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(result.blocks) { block in
                        HStack(alignment: .top, spacing: Metrics.spacingS) {
                            Text(QuestlyFormat.time(block.start, calendar: calendar))
                                .font(.questCaption)
                                .monospacedDigit()
                                .frame(width: 46, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(block.title).font(.questBody)
                                Text(block.rationale)
                                    .font(.questMicro)
                                    .foregroundStyle(theme.accent)
                            }
                        }
                    }
                }

                if !result.unplaced.isEmpty {
                    Section("Ne rentre pas aujourd'hui") {
                        ForEach(result.unplaced) { task in
                            HStack {
                                Text(task.title).font(.questCallout)
                                Spacer()
                                Text(DurationFormatter.short(minutes: task.estimatedMinutes))
                                    .font(.questMicro)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Planifier ma journée")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Appliquer") {
                        onApply()
                        Haptics.success()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(result.blocks.isEmpty)
                }
            }
        }
    }
}
