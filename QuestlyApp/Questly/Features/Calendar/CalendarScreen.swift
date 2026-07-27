import SwiftUI
import SwiftData
import QuestlyKit

/// Le calendrier complet : jour, semaine, mois, année, agenda — avec les
/// évènements du calendrier système, le time-blocking par glisser-déposer et
/// la planification automatique de la journée.
struct CalendarScreen: View {

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(CalendarService.self) private var calendarService
    @Environment(\.questlyTheme) private var theme

    @Query private var tasks: [TaskItem]
    @Query private var blocks: [TimeBlock]

    @State private var mode: CalendarMode = .month
    @State private var selectedDate = Date()
    @State private var monthPage = 0
    @State private var weekPage = 0
    @State private var showsTray = false
    @State private var showsDatePicker = false
    @State private var selectedTask: TaskItem?
    @State private var planProposal: PlanProposal?

    /// Enveloppe identifiable pour présenter un plan dans une feuille.
    struct PlanProposal: Identifiable {
        let id = UUID()
        let result: PlanResult
    }

    private var calendar: Calendar { settings.calendar }
    private let monthRange = -60...60
    private let weekRange = -104...104

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                modePicker
                Divider().opacity(0.4)
                modeContent
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) {
                if showsTray && mode != .year {
                    UnscheduledTray(selectedDate: selectedDate)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showsDatePicker) {
                datePickerSheet
                    .presentationDetents([.height(420)])
            }
            .sheet(item: $selectedTask) { task in
                TaskDetailView(task: task)
            }
            .sheet(item: $planProposal) { proposal in
                AutoPlanSheet(result: proposal.result) {
                    store.applyPlan(proposal.result)
                    planProposal = nil
                }
                .presentationDetents([.medium, .large])
            }
            .onChange(of: monthPage) { _, newValue in
                guard mode == .month else { return }
                syncSelection(monthOffset: newValue)
            }
            .onChange(of: weekPage) { _, newValue in
                guard mode == .week else { return }
                syncSelection(weekOffset: newValue)
            }
            .onChange(of: mode) { _, _ in loadExternalEvents() }
            .onChange(of: selectedDate) { _, _ in loadExternalEvents() }
            .task { loadExternalEvents() }
        }
    }

    // MARK: En-tête

    private var header: some View {
        HStack(spacing: Metrics.spacingS) {
            Button {
                step(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(SoftButtonStyle(tint: theme.accent))

            Button {
                showsDatePicker = true
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text(headerTitle)
                        .font(.questHeadline)
                        .foregroundStyle(.primary)
                    Text(headerSubtitle)
                        .font(.questMicro)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if !calendar.isSameDay(selectedDate, Date()) {
                Button("Aujourd'hui") { goToToday() }
                    .font(.questMicro)
                    .buttonStyle(SoftButtonStyle(tint: theme.accent))
            }

            Button {
                step(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(SoftButtonStyle(tint: theme.accent))
        }
        .padding(.horizontal, Metrics.spacingM)
        .padding(.vertical, Metrics.spacingS)
    }

    private var headerTitle: String {
        switch mode {
        case .day: return QuestlyFormat.fullDay(selectedDate, calendar: calendar)
        case .week:
            let days = calendar.weekDays(for: selectedDate)
            let first = days.first ?? selectedDate
            let last = days.last ?? selectedDate
            return "\(QuestlyFormat.dayNumber(first, calendar: calendar)) – \(QuestlyFormat.dayNumber(last, calendar: calendar)) \(QuestlyFormat.month(last, calendar: calendar))"
        case .month, .agenda: return QuestlyFormat.monthYear(selectedDate, calendar: calendar)
        case .year: return String(calendar.component(.year, from: selectedDate))
        }
    }

    private var headerSubtitle: String {
        let dayTasks = tasksDue(on: selectedDate)
        let minutes = blocks.filter { calendar.isSameDay($0.start, selectedDate) }
            .reduce(0) { $0 + $1.durationMinutes }
        if dayTasks.isEmpty && minutes == 0 { return "Journée libre" }
        var parts: [String] = []
        if !dayTasks.isEmpty { parts.append("\(dayTasks.count) quête\(dayTasks.count > 1 ? "s" : "")") }
        if minutes > 0 { parts.append(DurationFormatter.short(minutes: minutes) + " planifiées") }
        return parts.joined(separator: " · ")
    }

    private var modePicker: some View {
        QuestlySegmentedPicker(
            items: CalendarMode.allCases,
            label: { $0.label },
            selection: $mode
        )
        .padding(.horizontal, Metrics.spacingM)
        .padding(.bottom, Metrics.spacingS)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    withAnimation(Motion.snappy) { showsTray.toggle() }
                } label: {
                    Label(
                        showsTray ? "Masquer les quêtes à placer" : "Afficher les quêtes à placer",
                        systemImage: "tray.full"
                    )
                }

                Button {
                    planProposal = PlanProposal(
                        result: store.autoPlanToday(workingHours: settings.workingHours)
                    )
                } label: {
                    Label("Planifier ma journée", systemImage: "wand.and.stars")
                }

                Divider()

                Button {
                    Task { await enableCalendarSync() }
                } label: {
                    Label(
                        calendarService.access == .granted ? "Recharger le calendrier système" : "Connecter le calendrier iOS",
                        systemImage: "calendar.badge.plus"
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: Contenus

    @ViewBuilder
    private var modeContent: some View {
        switch mode {
        case .day:
            dayContent
        case .week:
            weekPager
        case .month:
            monthContent
        case .year:
            YearGridView(selectedDate: $selectedDate) { date in
                selectedDate = date
                withAnimation(Motion.snappy) { mode = .month }
                monthPage = monthOffset(for: date)
            }
        case .agenda:
            AgendaListView(startDate: selectedDate) { task in
                selectedTask = task
            }
        }
    }

    private var dayContent: some View {
        QuestlyTimeline(days: [selectedDate], selectedDate: $selectedDate)
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        step(value.translation.width < 0 ? 1 : -1)
                    }
            )
    }

    private var weekPager: some View {
        TabView(selection: $weekPage) {
            ForEach(weekRange, id: \.self) { offset in
                let reference = calendar.date(byAdding: .weekOfYear, value: offset, to: Date()) ?? Date()
                VStack(spacing: 0) {
                    weekdayHeader(for: calendar.weekDays(for: reference))
                    QuestlyTimeline(
                        days: calendar.weekDays(for: reference),
                        selectedDate: $selectedDate
                    )
                }
                .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private func weekdayHeader(for days: [Date]) -> some View {
        HStack(spacing: 1) {
            Color.clear.frame(width: 52)
            ForEach(days, id: \.self) { day in
                let isToday = calendar.isSameDay(day, Date())
                VStack(spacing: 1) {
                    Text(QuestlyFormat.weekdayInitial(day, calendar: calendar))
                        .font(.questMicro)
                        .foregroundStyle(.secondary)
                    Text(QuestlyFormat.dayNumber(day, calendar: calendar))
                        .font(.questCaption)
                        .foregroundStyle(isToday ? .white : .primary)
                        .frame(width: 24, height: 24)
                        .background {
                            if isToday {
                                Circle().fill(theme.gradient)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedDate = day
                    withAnimation(Motion.snappy) { mode = .day }
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.trailing, 8)
        .background(.ultraThinMaterial)
    }

    private var monthContent: some View {
        VStack(spacing: 0) {
            TabView(selection: $monthPage) {
                ForEach(monthRange, id: \.self) { offset in
                    let reference = calendar.date(byAdding: .month, value: offset, to: Date()) ?? Date()
                    MonthGridView(
                        month: reference,
                        selectedDate: $selectedDate,
                        summaries: summaries(forMonth: reference)
                    )
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 320)

            Divider().opacity(0.4)

            DayAgendaPanel(date: selectedDate) { task in
                selectedTask = task
            }
        }
    }

    // MARK: Sélecteur de date

    private var datePickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Aller à",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .navigationTitle("Aller à une date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        monthPage = monthOffset(for: selectedDate)
                        weekPage = weekOffset(for: selectedDate)
                        showsDatePicker = false
                    }
                }
            }
        }
    }

    // MARK: Navigation

    private func step(_ direction: Int) {
        withAnimation(Motion.snappy) {
            switch mode {
            case .day:
                selectedDate = selectedDate.adding(days: direction, calendar: calendar)
            case .week:
                weekPage += direction
                selectedDate = calendar.date(byAdding: .weekOfYear, value: direction, to: selectedDate) ?? selectedDate
            case .month, .agenda:
                monthPage += direction
                selectedDate = calendar.date(byAdding: .month, value: direction, to: selectedDate) ?? selectedDate
            case .year:
                selectedDate = calendar.date(byAdding: .year, value: direction, to: selectedDate) ?? selectedDate
            }
        }
        Haptics.selection()
    }

    private func goToToday() {
        withAnimation(Motion.gentle) {
            selectedDate = Date()
            monthPage = 0
            weekPage = 0
        }
        Haptics.light()
    }

    private func monthOffset(for date: Date) -> Int {
        let from = calendar.startOfMonth(Date())
        let to = calendar.startOfMonth(date)
        return calendar.dateComponents([.month], from: from, to: to).month ?? 0
    }

    private func weekOffset(for date: Date) -> Int {
        let from = calendar.startOfWeek(Date())
        let to = calendar.startOfWeek(date)
        return (calendar.daysBetween(from, to)) / 7
    }

    private func syncSelection(monthOffset: Int) {
        guard let target = calendar.date(byAdding: .month, value: monthOffset, to: Date()) else { return }
        if !calendar.isDate(selectedDate, equalTo: target, toGranularity: .month) {
            let day = min(calendar.component(.day, from: selectedDate), calendar.numberOfDaysInMonth(target))
            var comps = calendar.dateComponents([.year, .month], from: target)
            comps.day = day
            selectedDate = calendar.date(from: comps) ?? target
        }
    }

    private func syncSelection(weekOffset: Int) {
        guard let target = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: Date()) else { return }
        if calendar.startOfWeek(selectedDate) != calendar.startOfWeek(target) {
            selectedDate = target
        }
    }

    // MARK: Données

    private func tasksDue(on day: Date) -> [TaskItem] {
        tasks.filter { $0.isDue(on: day, calendar: calendar) }
    }

    private func summaries(forMonth month: Date) -> [Date: DaySummary] {
        var output: [Date: DaySummary] = [:]
        let grid = calendar.monthGrid(for: month)
        guard let first = grid.first, let last = grid.last else { return output }

        for task in tasks {
            guard let due = task.dueDate else { continue }
            let day = calendar.startOfDay(for: due)
            guard day >= first && day <= last else { continue }
            var summary = output[day] ?? DaySummary()
            summary.taskCount += 1
            if task.isCompleted { summary.completedCount += 1 }
            if task.isBoss { summary.hasBoss = true }
            if task.isOverdue(now: Date(), calendar: calendar) { summary.hasOverdue = true }
            let hex = task.lifeArea?.hex ?? task.priority.hex
            if !summary.areaHexes.contains(hex) && summary.areaHexes.count < 3 {
                summary.areaHexes.append(hex)
            }
            output[day] = summary
        }

        for block in blocks {
            let day = calendar.startOfDay(for: block.start)
            guard day >= first && day <= last else { continue }
            var summary = output[day] ?? DaySummary()
            summary.blockMinutes += block.durationMinutes
            output[day] = summary
        }

        return output
    }

    private func loadExternalEvents() {
        guard settings.calendarSyncEnabled, calendarService.access == .granted else { return }
        let start = calendar.startOfMonth(selectedDate).adding(days: -7, calendar: calendar)
        let end = calendar.endOfMonth(selectedDate).adding(days: 7, calendar: calendar)
        calendarService.load(from: start, to: end)
    }

    private func enableCalendarSync() async {
        if calendarService.access != .granted {
            let granted = await calendarService.requestAccess()
            settings.calendarSyncEnabled = granted
        }
        loadExternalEvents()
    }
}

// MARK: - Grille du mois

struct MonthGridView: View {

    let month: Date
    @Binding var selectedDate: Date
    let summaries: [Date: DaySummary]

    @Environment(SettingsStore.self) private var settings
    @Environment(\.questlyTheme) private var theme

    private var calendar: Calendar { settings.calendar }

    var body: some View {
        VStack(spacing: 4) {
            weekdayHeader

            let grid = calendar.monthGrid(for: month)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                ForEach(grid, id: \.self) { day in
                    MonthDayCell(
                        day: day,
                        isInMonth: calendar.isDate(day, equalTo: month, toGranularity: .month),
                        isToday: calendar.isSameDay(day, Date()),
                        isSelected: calendar.isSameDay(day, selectedDate),
                        summary: summaries[calendar.startOfDay(for: day)] ?? DaySummary(),
                        capacityMinutes: settings.workEndMinute - settings.workStartMinute
                    )
                    .onTapGesture {
                        withAnimation(Motion.snappy) { selectedDate = day }
                        Haptics.selection()
                    }
                }
            }
        }
        .padding(.horizontal, Metrics.spacingS)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 2) {
            ForEach(calendar.weekDays(for: Date()), id: \.self) { day in
                Text(QuestlyFormat.weekdayInitial(day, calendar: calendar))
                    .font(.questMicro)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Case du mois

struct MonthDayCell: View {

    let day: Date
    let isInMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let summary: DaySummary
    let capacityMinutes: Int

    @Environment(SettingsStore.self) private var settings
    @Environment(\.questlyTheme) private var theme

    private var calendar: Calendar { settings.calendar }

    var body: some View {
        VStack(spacing: 3) {
            Text(QuestlyFormat.dayNumber(day, calendar: calendar))
                .font(.system(size: 14, weight: isToday ? .bold : .medium, design: .rounded))
                .foregroundStyle(numberColor)
                .frame(width: 28, height: 28)
                .background {
                    if isSelected {
                        Circle().fill(theme.gradient)
                    } else if isToday {
                        Circle().strokeBorder(theme.accent, lineWidth: 1.5)
                    }
                }

            dots
        }
        .frame(height: 46)
        .frame(maxWidth: .infinity)
        .background {
            if summary.blockMinutes > 0 {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.accent.opacity(0.06 + summary.load(capacityMinutes: capacityMinutes) * 0.14))
            }
        }
        .overlay(alignment: .topTrailing) {
            if summary.hasBoss {
                Image(systemName: "crown.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(Color(hex: "BF5AF2"))
                    .padding(2)
            }
        }
        .opacity(isInMonth ? 1 : 0.32)
        .contentShape(Rectangle())
    }

    private var numberColor: Color {
        if isSelected { return .white }
        if isToday { return theme.accent }
        if summary.hasOverdue { return Color(hex: "FF453A") }
        return .primary
    }

    private var dots: some View {
        HStack(spacing: 2) {
            if summary.taskCount == 0 {
                Circle().fill(Color.clear).frame(width: 5, height: 5)
            } else {
                ForEach(Array(summary.areaHexes.prefix(3).enumerated()), id: \.offset) { _, hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 5, height: 5)
                        .opacity(summary.completionFraction >= 1 ? 0.35 : 1)
                }
                if summary.taskCount > 3 {
                    Text("+")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 6)
    }
}
