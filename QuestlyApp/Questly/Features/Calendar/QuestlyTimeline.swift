import SwiftUI
import Combine
import SwiftData
import QuestlyKit

/// Timeline horaire, utilisée pour la vue Jour (une colonne) et la vue Semaine
/// (sept colonnes). On peut y déposer une quête, déplacer un bloc, en créer un
/// d'un appui long sur une plage libre.
struct QuestlyTimeline: View {

    let days: [Date]
    @Binding var selectedDate: Date
    var showsAllDayRow: Bool = true

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(CalendarService.self) private var calendarService
    @Environment(\.questlyTheme) private var theme

    @Query private var tasks: [TaskItem]
    @Query private var blocks: [TimeBlock]

    @State private var geometry = TimelineGeometry()
    @State private var draggingEntry: String?
    @State private var dragOffset: CGFloat = 0
    @State private var pendingSlot: PendingSlot?
    @State private var selectedTask: TaskItem?
    @State private var now = Date()

    private let gutterWidth: CGFloat = 52
    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var calendar: Calendar { settings.calendar }

    struct PendingSlot: Identifiable {
        let id = UUID()
        let start: Date
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsAllDayRow { allDayRow }
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    timelineBody
                        .padding(.bottom, 120)
                }
                .onAppear {
                    proxy.scrollTo(scrollAnchorHour, anchor: .top)
                }
            }
        }
        .onReceive(refreshTimer) { _ in now = Date() }
        .sheet(item: $pendingSlot) { slot in
            SlotComposerSheet(start: slot.start)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
    }

    private var scrollAnchorHour: Int {
        max(0, calendar.component(.hour, from: Date()) - 1)
    }

    // MARK: Ligne « toute la journée »

    /// Colonne de la bande « toute la journée » (un type nommé : les key-paths
    /// sur tuples ne sont pas disponibles en Swift).
    private struct AllDayColumn: Identifiable {
        let id: Date
        let tasks: [TaskItem]
    }

    private var allDayRow: some View {
        let columns = days.map { AllDayColumn(id: $0, tasks: allDayTasks(on: $0)) }
        let hasAny = columns.contains { !$0.tasks.isEmpty }

        return Group {
            if hasAny {
                HStack(alignment: .top, spacing: 1) {
                    Text("Journée")
                        .font(.questMicro)
                        .foregroundStyle(.secondary)
                        .frame(width: gutterWidth, alignment: .trailing)
                        .padding(.trailing, 4)

                    ForEach(columns) { column in
                        VStack(spacing: 3) {
                            ForEach(column.tasks.prefix(3)) { task in
                                Button {
                                    selectedTask = task
                                } label: {
                                    Text(task.title)
                                        .font(.questMicro)
                                        .lineLimit(1)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background {
                                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                .fill(Color(hex: task.lifeArea?.hex ?? task.priority.hex)
                                                    .opacity(task.isCompleted ? 0.4 : 0.9))
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                            if column.tasks.count > 3 {
                                Text("+\(column.tasks.count - 3)")
                                    .font(.questMicro)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 5)
                .padding(.trailing, 8)
                .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: Corps de la timeline

    private var timelineBody: some View {
        ZStack(alignment: .topLeading) {
            hourGrid
            HStack(spacing: 1) {
                ForEach(days, id: \.self) { day in
                    dayColumn(day)
                }
            }
            .padding(.leading, gutterWidth)
            .padding(.trailing, 8)

            nowIndicator
        }
    }

    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: 4) {
                    Text(String(format: "%02d:00", hour))
                        .font(.questMicro)
                        .foregroundStyle(.secondary)
                        .frame(width: gutterWidth - 6, alignment: .trailing)
                        .offset(y: -6)

                    Rectangle()
                        .fill(Color.primary.opacity(0.07))
                        .frame(height: 1)
                }
                .frame(height: geometry.hourHeight, alignment: .top)
                .id(hour)
            }
        }
    }

    private func dayColumn(_ day: Date) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let placements = TimelineLayout.place(entries(on: day))

            ZStack(alignment: .topLeading) {
                // Fond cliquable : appui long = nouveau bloc.
                Rectangle()
                    .fill(calendar.isSameDay(day, Date())
                          ? theme.accent.opacity(0.04)
                          : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let start = geometry.date(atOffset: location.y, in: day, calendar: calendar, snapMinutes: 30)
                        pendingSlot = PendingSlot(start: start)
                        Haptics.light()
                    }

                // Bande des heures non travaillées, pour situer la journée.
                nonWorkingOverlay(day: day)

                ForEach(placements) { placement in
                    entryView(placement, day: day, columnWidth: width)
                }
            }
            .frame(height: geometry.totalHeight)
            .dropDestination(for: String.self) { items, location in
                handleDrop(items: items, location: location, day: day)
            }
        }
        .frame(height: geometry.totalHeight)
    }

    private func nonWorkingOverlay(day: Date) -> some View {
        let hours = settings.workingHours
        let startOffset = CGFloat(hours.startMinute) / 60 * geometry.hourHeight
        let endOffset = CGFloat(hours.endMinute) / 60 * geometry.hourHeight

        return VStack(spacing: 0) {
            Rectangle()
                .fill(Color.primary.opacity(0.035))
                .frame(height: startOffset)
            Spacer(minLength: 0)
            Rectangle()
                .fill(Color.primary.opacity(0.035))
                .frame(height: max(0, geometry.totalHeight - endOffset))
        }
        .allowsHitTesting(false)
    }

    private func entryView(_ placement: TimelineLayout.Placement, day: Date, columnWidth: CGFloat) -> some View {
        let entry = placement.entry
        let slotWidth = max(24, (columnWidth - 4) / CGFloat(placement.columnCount))
        let isDragging = draggingEntry == entry.id
        let baseOffset = geometry.offset(for: entry.start, in: day, calendar: calendar)

        return TimelineEntryCard(entry: entry, compact: slotWidth < 90)
            .frame(width: slotWidth - 3, height: geometry.height(forMinutes: entry.durationMinutes))
            .offset(
                x: CGFloat(placement.column) * slotWidth + 2,
                y: baseOffset + (isDragging ? dragOffset : 0)
            )
            .opacity(isDragging ? 0.85 : 1)
            .scaleEffect(isDragging ? 1.03 : 1)
            .shadow(color: .black.opacity(isDragging ? 0.25 : 0), radius: 10, y: 6)
            .zIndex(isDragging ? 10 : 0)
            .onTapGesture { open(entry) }
            .applyIf(entry.isEditable) { view in
                view.gesture(moveGesture(for: entry, day: day))
            }
            .contextMenu { entryMenu(entry) }
    }

    private func moveGesture(for entry: TimedEntry, day: Date) -> some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .onEnded { _ in
                draggingEntry = entry.id
                Haptics.play(.medium)
            }
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                dragOffset = drag.translation.height
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value else {
                    draggingEntry = nil
                    dragOffset = 0
                    return
                }
                commitMove(entry: entry, day: day, translation: drag.translation.height)
                draggingEntry = nil
                dragOffset = 0
            }
    }

    private func commitMove(entry: TimedEntry, day: Date, translation: CGFloat) {
        let originalOffset = geometry.offset(for: entry.start, in: day, calendar: calendar)
        let newStart = geometry.date(
            atOffset: originalOffset + translation,
            in: day,
            calendar: calendar,
            snapMinutes: 15
        )

        if let blockID = entry.blockIdentifier,
           let block = blocks.first(where: { $0.identifier == blockID }) {
            store.move(block, to: newStart)
            Haptics.success()
        } else if let taskID = entry.taskIdentifier,
                  let task = tasks.first(where: { $0.identifier == taskID }) {
            task.dueDate = newStart
            task.hasTime = true
            task.touch()
            store.save()
            Haptics.success()
        }
    }

    @ViewBuilder
    private func entryMenu(_ entry: TimedEntry) -> some View {
        if let blockID = entry.blockIdentifier,
           let block = blocks.first(where: { $0.identifier == blockID }) {
            Button {
                store.resize(block, toMinutes: 30)
            } label: { Label("30 minutes", systemImage: "timer") }
            Button {
                store.resize(block, toMinutes: 60)
            } label: { Label("1 heure", systemImage: "timer") }
            Button {
                store.resize(block, toMinutes: 120)
            } label: { Label("2 heures", systemImage: "timer") }
            Divider()
            Button(role: .destructive) {
                store.delete(block)
                Haptics.warning()
            } label: { Label("Libérer le créneau", systemImage: "trash") }
        } else if entry.source == .task {
            Button {
                open(entry)
            } label: { Label("Ouvrir la quête", systemImage: "square.and.pencil") }
        }
    }

    private func open(_ entry: TimedEntry) {
        guard let taskID = entry.taskIdentifier,
              let task = tasks.first(where: { $0.identifier == taskID }) else { return }
        selectedTask = task
    }

    // MARK: Indicateur d'instant présent

    @ViewBuilder
    private var nowIndicator: some View {
        if let index = days.firstIndex(where: { calendar.isSameDay($0, now) }) {
            let offset = geometry.offset(for: now, in: days[index], calendar: calendar)
            HStack(spacing: 0) {
                Circle()
                    .fill(Color(hex: "FF453A"))
                    .frame(width: 7, height: 7)
                Rectangle()
                    .fill(Color(hex: "FF453A"))
                    .frame(height: 1.5)
            }
            .padding(.leading, gutterWidth - 3)
            .padding(.trailing, 8)
            .offset(y: offset)
            .allowsHitTesting(false)
            .zIndex(5)
        }
    }

    // MARK: Données

    private func entries(on day: Date) -> [TimedEntry] {
        var output: [TimedEntry] = []

        for block in blocks where calendar.isSameDay(block.start, day) && !block.isAllDay {
            output.append(TimedEntry.from(block: block))
        }

        // Les quêtes horodatées sans bloc réservé apparaissent quand même.
        let scheduledTaskIDs = Set(output.compactMap(\.taskIdentifier))
        for task in tasks where task.hasTime && task.isOpen {
            guard let due = task.dueDate, calendar.isSameDay(due, day) else { continue }
            guard !scheduledTaskIDs.contains(task.identifier) else { continue }
            output.append(TimedEntry.from(task: task))
        }

        for event in calendarService.events(on: day, calendar: calendar) where !event.isAllDay {
            output.append(TimedEntry.from(external: event))
        }

        return output
    }

    private func allDayTasks(on day: Date) -> [TaskItem] {
        tasks.filter { task in
            guard !task.hasTime, let due = task.dueDate else { return false }
            return calendar.isSameDay(due, day) && task.isOpen
        }
    }

    private func handleDrop(items: [String], location: CGPoint, day: Date) -> Bool {
        guard let identifier = items.first,
              let uuid = UUID(uuidString: identifier),
              let task = tasks.first(where: { $0.identifier == uuid }) else { return false }

        let start = geometry.date(atOffset: location.y, in: day, calendar: calendar, snapMinutes: 15)
        store.schedule(task, at: start)
        Haptics.success()
        return true
    }
}

// MARK: - Carte d'une entrée

struct TimelineEntryCard: View {
    let entry: TimedEntry
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                if entry.source == .external {
                    Image(systemName: "calendar")
                        .font(.system(size: 8, weight: .bold))
                } else if entry.symbolName == "crown.fill" {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 8, weight: .bold))
                }
                Text(entry.title)
                    .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .rounded))
                    .lineLimit(compact ? 1 : 2)
                    .strikethrough(entry.isCompleted)
            }

            if !compact && entry.durationMinutes >= 40 {
                Text(QuestlyFormat.time(entry.start))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .opacity(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(entry.source == .external ? entry.color : .white)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(entry.source == .external
                      ? AnyShapeStyle(entry.color.opacity(0.16))
                      : AnyShapeStyle(LinearGradient(
                          colors: [entry.color, entry.color.opacity(0.78)],
                          startPoint: .topLeading,
                          endPoint: .bottomTrailing
                      )))
                .opacity(entry.isCompleted ? 0.45 : 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(entry.color.opacity(entry.source == .external ? 0.5 : 0), lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            if entry.source == .external {
                Rectangle()
                    .fill(entry.color)
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
    }
}

// MARK: - Composition d'un créneau

/// Feuille ouverte en tapant une plage libre : on y crée un bloc, soit à partir
/// d'une quête existante, soit d'un intitulé libre.
struct SlotComposerSheet: View {

    let start: Date

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(\.questlyTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @Query private var tasks: [TaskItem]

    @State private var title = ""
    @State private var minutes = 60
    @State private var searchText = ""

    private var calendar: Calendar { settings.calendar }

    private var candidates: [TaskItem] {
        let open = tasks.filter(\.isOpen)
        guard !searchText.isEmpty else {
            return Array(open.sorted(by: TaskSorting.smart(calendar: calendar)).prefix(12))
        }
        let needle = searchText.lowercased()
        return open.filter { $0.title.lowercased().contains(needle) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("Début", systemImage: "clock")
                        Spacer()
                        Text("\(QuestlyFormat.fullDay(start, calendar: calendar)) · \(QuestlyFormat.time(start, calendar: calendar))")
                            .font(.questCaption)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Durée", selection: $minutes) {
                        ForEach([15, 30, 45, 60, 90, 120, 180], id: \.self) { value in
                            Text(DurationFormatter.short(minutes: value)).tag(value)
                        }
                    }
                }

                Section("Bloquer une quête") {
                    ForEach(candidates) { task in
                        Button {
                            store.schedule(task, at: start, minutes: minutes)
                            Haptics.success()
                            dismiss()
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(hex: task.lifeArea?.hex ?? task.priority.hex))
                                    .frame(width: 8, height: 8)
                                Text(task.title).font(.questBody)
                                Spacer()
                                if task.estimatedMinutes > 0 {
                                    Text(DurationFormatter.short(minutes: task.estimatedMinutes))
                                        .font(.questMicro)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Ou créer un bloc libre") {
                    TextField("Intitulé du créneau", text: $title)
                    Button {
                        createFreeBlock()
                    } label: {
                        Label("Réserver ce créneau", systemImage: "plus.rectangle.on.rectangle")
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .searchable(text: $searchText, prompt: "Chercher une quête")
            .navigationTitle("Nouveau créneau")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }

    private func createFreeBlock() {
        let block = TimeBlock(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            start: start,
            end: start.addingTimeInterval(TimeInterval(minutes * 60)),
            colorHex: theme.accentHex
        )
        store.modelContext.insert(block)
        store.save()
        Haptics.success()
        dismiss()
    }
}
