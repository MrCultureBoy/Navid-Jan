import SwiftUI
import SwiftData
import QuestlyKit

/// Le tableau des quêtes : listes intelligentes, projets, étiquettes,
/// recherche, tri et regroupement. C'est la vue « gestionnaire » de l'app.
struct QuestBoardView: View {

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(\.questlyTheme) private var theme

    @Query private var tasks: [TaskItem]
    @Query(sort: \Project.sortIndex) private var projects: [Project]
    @Query(sort: \Tag.name) private var tags: [Tag]

    @State private var smartList: SmartList = .today
    @State private var searchText = ""
    @State private var sortOrder: TaskSortOrder = .smart
    @State private var grouping: TaskGrouping = .date
    @State private var selectedTask: TaskItem?
    @State private var selectedTag: Tag?
    @State private var showsNewProject = false

    private var calendar: Calendar { settings.calendar }

    var body: some View {
        NavigationStack {
            List {
                smartListSection
                if !projects.isEmpty { projectSection }
                if !tags.isEmpty { tagSection }
                taskSection
                Section { Color.clear.frame(height: 90).listRowBackground(Color.clear) }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .searchable(text: $searchText, prompt: "Rechercher une quête")
            .navigationTitle("Quêtes")
            .toolbar { toolbarContent }
            .sheet(item: $selectedTask) { task in
                TaskDetailView(task: task)
            }
            .sheet(isPresented: $showsNewProject) {
                ProjectEditorView()
                    .presentationDetents([.height(420)])
            }
        }
    }

    // MARK: Barre d'outils

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Trier par", selection: $sortOrder) {
                    ForEach(TaskSortOrder.allCases) { order in
                        Text(order.label).tag(order)
                    }
                }
                Picker("Grouper par", selection: $grouping) {
                    ForEach(TaskGrouping.allCases) { group in
                        Text(group.label).tag(group)
                    }
                }
                Divider()
                Button {
                    showsNewProject = true
                } label: {
                    Label("Nouveau projet", systemImage: "folder.badge.plus")
                }
                Toggle("Afficher les accomplies", isOn: Binding(
                    get: { settings.showCompletedTasks },
                    set: { settings.showCompletedTasks = $0 }
                ))
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }
    }

    // MARK: Listes intelligentes

    private var smartListSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metrics.spacingS) {
                    ForEach(SmartList.allCases) { list in
                        SmartListChip(
                            list: list,
                            count: count(for: list),
                            isSelected: smartList == list && selectedTag == nil
                        ) {
                            withAnimation(Motion.snappy) {
                                smartList = list
                                selectedTag = nil
                            }
                            Haptics.selection()
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            .listRowBackground(Color.clear)
        }
    }

    private func count(for list: SmartList) -> Int {
        items(in: list).count
    }

    // MARK: Projets

    private var projectSection: some View {
        Section("Campagnes") {
            ForEach(projects.filter { !$0.isArchived }) { project in
                NavigationLink {
                    ProjectDetailView(project: project)
                } label: {
                    ProjectRow(project: project)
                }
            }
        }
    }

    // MARK: Étiquettes

    private var tagSection: some View {
        Section("Étiquettes") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tags) { tag in
                        Button {
                            withAnimation(Motion.snappy) {
                                selectedTag = selectedTag?.identifier == tag.identifier ? nil : tag
                            }
                            Haptics.selection()
                        } label: {
                            TagChip(
                                name: "\(tag.name) · \(tag.openTaskCount)",
                                colorHex: tag.colorHex,
                                isSelected: selectedTag?.identifier == tag.identifier
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
        }
    }

    // MARK: Quêtes

    private var taskSection: some View {
        ForEach(groupedTasks, id: \.title) { group in
            Section(group.title) {
                if group.tasks.isEmpty {
                    Text("Rien ici.")
                        .font(.questCaption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(group.tasks) { task in
                        TaskRow(task: task) { selectedTask = task }
                            .taskSwipeActions(for: task) { selectedTask = task }
                            .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 12))
                    }
                }
            }
        }
    }

    // MARK: Filtrage

    private func items(in list: SmartList) -> [TaskItem] {
        let now = Date()
        switch list {
        case .inbox:
            return tasks.filter { $0.status == .inbox }
        case .today:
            return tasks.filter { task in
                guard task.isOpen, let due = task.dueDate else { return false }
                return calendar.startOfDay(for: due) <= calendar.startOfDay(for: now)
            }
        case .upcoming:
            return tasks.filter { task in
                guard task.isOpen, let due = task.dueDate else { return false }
                return calendar.startOfDay(for: due) > calendar.startOfDay(for: now)
            }
        case .overdue:
            return tasks.filter { $0.isOverdue(now: now, calendar: calendar) }
        case .anytime:
            return tasks.filter { $0.isOpen && $0.dueDate == nil && $0.status == .active }
        case .someday:
            return tasks.filter { $0.status == .archived }
        case .flagged:
            return tasks.filter { $0.isFlagged && $0.isOpen }
        case .bosses:
            return tasks.filter { $0.isBoss && $0.isOpen }
        case .completed:
            return tasks.filter(\.isCompleted)
        }
    }

    private var filteredTasks: [TaskItem] {
        var result = selectedTag == nil
            ? items(in: smartList)
            : tasks.filter { task in
                task.isOpen && (task.tags ?? []).contains { $0.identifier == selectedTag?.identifier }
            }

        if !searchText.isEmpty {
            let needle = searchText.folding(options: .diacriticInsensitive, locale: QuestlyFormat.locale).lowercased()
            result = tasks.filter { task in
                let haystack = (task.title + " " + task.notes + " " + task.sortedTags.map(\.name).joined(separator: " "))
                    .folding(options: .diacriticInsensitive, locale: QuestlyFormat.locale)
                    .lowercased()
                return haystack.contains(needle)
            }
        }

        if !settings.showCompletedTasks && smartList != .completed {
            result = result.filter { !$0.isCompleted }
        }

        return result.sorted(by: TaskSorting.comparator(for: sortOrder, calendar: calendar))
    }

    private struct TaskGroup {
        let title: String
        let tasks: [TaskItem]
    }

    private var groupedTasks: [TaskGroup] {
        let items = filteredTasks
        guard !items.isEmpty else {
            return [TaskGroup(title: smartList.label, tasks: [])]
        }

        switch grouping {
        case .none:
            return [TaskGroup(title: "\(items.count) quête\(items.count > 1 ? "s" : "")", tasks: items)]

        case .date:
            var buckets: [(String, [TaskItem])] = []
            let now = Date()
            let overdue = items.filter { $0.isOverdue(now: now, calendar: calendar) }
            let today = items.filter { !$0.isOverdue(now: now, calendar: calendar) && $0.isDueToday(now: now, calendar: calendar) }
            let upcoming = items.filter { task in
                guard let due = task.dueDate else { return false }
                return calendar.startOfDay(for: due) > calendar.startOfDay(for: now)
            }
            let undated = items.filter { $0.dueDate == nil }

            if !overdue.isEmpty { buckets.append(("En retard", overdue)) }
            if !today.isEmpty { buckets.append(("Aujourd'hui", today)) }
            if !upcoming.isEmpty { buckets.append(("À venir", upcoming)) }
            if !undated.isEmpty { buckets.append(("Sans date", undated)) }
            return buckets.map { TaskGroup(title: $0.0, tasks: $0.1) }

        case .priority:
            return Priority.allCases.compactMap { priority in
                let matching = items.filter { $0.priority == priority }
                return matching.isEmpty ? nil : TaskGroup(title: priority.label, tasks: matching)
            }

        case .project:
            var groups: [TaskGroup] = []
            for project in projects {
                let matching = items.filter { $0.project?.identifier == project.identifier }
                if !matching.isEmpty {
                    groups.append(TaskGroup(title: "\(project.emoji) \(project.name)", tasks: matching))
                }
            }
            let orphans = items.filter { $0.project == nil }
            if !orphans.isEmpty { groups.append(TaskGroup(title: "Sans projet", tasks: orphans)) }
            return groups

        case .lifeArea:
            var groups = LifeArea.allCases.compactMap { area -> TaskGroup? in
                let matching = items.filter { $0.lifeArea == area }
                return matching.isEmpty ? nil : TaskGroup(title: area.label, tasks: matching)
            }
            let none = items.filter { $0.lifeArea == nil }
            if !none.isEmpty { groups.append(TaskGroup(title: "Sans domaine", tasks: none)) }
            return groups

        case .difficulty:
            return Difficulty.allCases.reversed().compactMap { difficulty in
                let matching = items.filter { $0.difficulty == difficulty }
                return matching.isEmpty ? nil : TaskGroup(title: difficulty.label, tasks: matching)
            }
        }
    }
}

// MARK: - Pastille de liste intelligente

struct SmartListChip: View {
    let list: SmartList
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let color = Color(hex: list.hex)

        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: list.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : color)
                    Spacer()
                    Text("\(count)")
                        .font(.questNumber(16))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                Text(list.label)
                    .font(.questMicro)
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(width: 108, height: 66, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Metrics.cornerRadiusSmall, style: .continuous)
                    .fill(isSelected
                          ? AnyShapeStyle(LinearGradient(colors: [color, color.opacity(0.75)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                          : AnyShapeStyle(Color.primary.opacity(0.05)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(color.opacity(isSelected ? 0 : 0.2), lineWidth: 1)
            }
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Ligne de projet

struct ProjectRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: Metrics.spacingS) {
            ProgressRing(
                fraction: project.progress,
                size: 34,
                lineWidth: 4,
                color: Color(hex: project.colorHex),
                content: AnyView(Text(project.emoji).font(.system(size: 13)))
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(project.name).font(.questBody)
                Text("\(project.completedTasks.count)/\(project.allTasks.count) quêtes")
                    .font(.questMicro)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let target = project.targetDate {
                Text(QuestlyFormat.mediumDate(target))
                    .font(.questMicro)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Détail d'un projet

struct ProjectDetailView: View {
    @Bindable var project: Project

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(\.questlyTheme) private var theme

    @State private var selectedTask: TaskItem?
    @State private var showsEditor = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Metrics.spacingS) {
                    HStack(spacing: Metrics.spacingM) {
                        ProgressRing(
                            fraction: project.progress,
                            size: 64,
                            lineWidth: 7,
                            color: Color(hex: project.colorHex),
                            content: AnyView(Text(project.emoji).font(.system(size: 24)))
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            Text(QuestlyFormat.percent(project.progress))
                                .font(.questTitle)
                            Text("\(project.openTasks.count) quête\(project.openTasks.count > 1 ? "s" : "") restante\(project.openTasks.count > 1 ? "s" : "")")
                                .font(.questCaption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !project.notes.isEmpty {
                        Text(project.notes)
                            .font(.questCallout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("À faire") {
                ForEach(project.openTasks.sorted(by: TaskSorting.smart(calendar: settings.calendar))) { task in
                    TaskRow(task: task, showsProject: false) { selectedTask = task }
                        .taskSwipeActions(for: task) { selectedTask = task }
                }
                if project.openTasks.isEmpty {
                    Text("Campagne terminée. Beau travail.")
                        .font(.questCaption)
                        .foregroundStyle(.secondary)
                }
            }

            if !project.completedTasks.isEmpty {
                Section("Accomplies") {
                    ForEach(project.completedTasks.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }) { task in
                        TaskRow(task: task, showsProject: false, isCompact: true) { selectedTask = task }
                    }
                }
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsEditor = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
        .sheet(isPresented: $showsEditor) {
            ProjectEditorView(project: project)
                .presentationDetents([.height(420)])
        }
    }
}

// MARK: - Éditeur de projet

struct ProjectEditorView: View {
    var project: Project?

    @Environment(QuestlyStore.self) private var store
    @Environment(\.questlyTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "📁"
    @State private var colorHex = "5E5CE6"
    @State private var notes = ""
    @State private var hasTarget = false
    @State private var targetDate = Date().addingTimeInterval(60 * 60 * 24 * 14)
    @State private var area: LifeArea?

    private let emojiChoices = ["📁", "🚀", "🏔️", "🎯", "🏗️", "📚", "💪", "🎨", "💼", "🏡", "💰", "❤️"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom de la campagne", text: $name)
                        .font(.questHeadline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(emojiChoices, id: \.self) { choice in
                                Button {
                                    emoji = choice
                                    Haptics.selection()
                                } label: {
                                    Text(choice)
                                        .font(.system(size: 22))
                                        .frame(width: 40, height: 40)
                                        .background {
                                            Circle().fill(emoji == choice
                                                          ? Color(hex: colorHex).opacity(0.25)
                                                          : Color.primary.opacity(0.05))
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Palette.projectHexes, id: \.self) { hex in
                                Button {
                                    colorHex = hex
                                    Haptics.selection()
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 28, height: 28)
                                        .overlay {
                                            if colorHex == hex {
                                                Circle().strokeBorder(.white, lineWidth: 2)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("Options") {
                    Picker(selection: $area) {
                        Text("Aucun domaine").tag(LifeArea?.none)
                        ForEach(LifeArea.allCases) { value in
                            Label(value.label, systemImage: value.symbolName).tag(LifeArea?.some(value))
                        }
                    } label: {
                        Label("Domaine", systemImage: "circle.hexagongrid.fill")
                    }

                    Toggle("Date cible", isOn: $hasTarget)
                    if hasTarget {
                        DatePicker("Échéance", selection: $targetDate, displayedComponents: [.date])
                    }

                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(project == nil ? "Nouvelle campagne" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let project else { return }
        name = project.name
        emoji = project.emoji
        colorHex = project.colorHex
        notes = project.notes
        area = project.lifeArea
        if let target = project.targetDate {
            hasTarget = true
            targetDate = target
        }
    }

    private func save() {
        let target: Project
        if let project {
            target = project
        } else {
            let created = Project(name: name, emoji: emoji, colorHex: colorHex)
            store.modelContext.insert(created)
            target = created
        }
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.emoji = emoji
        target.colorHex = colorHex
        target.notes = notes
        target.lifeArea = area
        target.targetDate = hasTarget ? targetDate : nil
        store.save()
        Haptics.success()
        dismiss()
    }
}
