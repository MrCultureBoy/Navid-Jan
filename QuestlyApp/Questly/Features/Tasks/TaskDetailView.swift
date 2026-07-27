import SwiftUI
import SwiftData
import QuestlyKit

/// Fiche complète d'une quête. Tout y est modifiable, et chaque réglage montre
/// son effet sur la récompense — c'est ce qui rend la gamification honnête.
struct TaskDetailView: View {

    @Bindable var task: TaskItem

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(NotificationService.self) private var notifications
    @Environment(\.questlyTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @Query private var projects: [Project]

    @State private var newSubtask = ""
    @State private var showsRecurrenceEditor = false
    @State private var showsScheduler = false
    @State private var showsDeleteConfirmation = false
    @State private var showsXPBreakdown = false

    private var calendar: Calendar { settings.calendar }

    var body: some View {
        NavigationStack {
            Form {
                headerSection
                scheduleSection
                gameSection
                subtaskSection
                organizationSection
                blocksSection
                notesSection
                dangerSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(task.isCompleted ? "Quête accomplie" : "Quête")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { save(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    completeButton
                }
            }
            .sheet(isPresented: $showsRecurrenceEditor) {
                RecurrenceEditorView(task: task)
            }
            .sheet(isPresented: $showsScheduler) {
                SchedulerSheet(task: task)
                    .presentationDetents([.medium])
            }
            .confirmationDialog("Supprimer cette quête ?", isPresented: $showsDeleteConfirmation) {
                Button("Supprimer", role: .destructive) {
                    notifications.cancel(for: task)
                    store.delete(task)
                    dismiss()
                }
            }
            .onDisappear { save() }
        }
    }

    // MARK: En-tête

    private var headerSection: some View {
        Section {
            TextField("Titre de la quête", text: $task.title, axis: .vertical)
                .font(.questHeadline)
                .lineLimit(1...3)

            Button {
                withAnimation(Motion.snappy) { showsXPBreakdown.toggle() }
            } label: {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(Color(hex: "FFD60A"))
                    Text("Récompense estimée")
                        .font(.questCallout)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(task.previewXP) XP")
                        .font(.questCallout)
                        .foregroundStyle(theme.accent)
                        .monospacedDigit()
                    Image(systemName: showsXPBreakdown ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if showsXPBreakdown {
                XPBreakdownList(task: task, streakDays: store.streak.current)
            }
        }
    }

    private var completeButton: some View {
        Button {
            if task.isCompleted {
                store.uncomplete(task)
            } else {
                let bundle = store.complete(task)
                Haptics.play(bundle.comboCount > 1 ? .combo(bundle.comboCount) : .success)
                dismiss()
            }
        } label: {
            Label(
                task.isCompleted ? "Rouvrir" : "Accomplir",
                systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark.circle.fill"
            )
        }
        .fontWeight(.semibold)
    }

    // MARK: Planification

    private var scheduleSection: some View {
        Section("Échéance") {
            Toggle(isOn: dueDateBinding) {
                Label("Date d'échéance", systemImage: "calendar")
            }

            if task.dueDate != nil {
                DatePicker(
                    "Jour",
                    selection: Binding(
                        get: { task.dueDate ?? Date() },
                        set: { task.dueDate = $0; task.touch() }
                    ),
                    displayedComponents: task.hasTime ? [.date, .hourAndMinute] : [.date]
                )

                Toggle(isOn: $task.hasTime) {
                    Label("Heure précise", systemImage: "clock")
                }

                Picker(selection: reminderBinding) {
                    Text("Aucun").tag(0)
                    Text("À l'heure").tag(1)
                    Text("5 minutes avant").tag(5)
                    Text("15 minutes avant").tag(15)
                    Text("30 minutes avant").tag(30)
                    Text("1 heure avant").tag(60)
                    Text("1 jour avant").tag(1440)
                } label: {
                    Label("Rappel", systemImage: "bell.fill")
                }
            }

            Button {
                showsRecurrenceEditor = true
            } label: {
                HStack {
                    Label("Répétition", systemImage: "repeat")
                    Spacer()
                    Text(task.recurrence?.humanDescription(calendar: calendar) ?? "Jamais")
                        .font(.questCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            durationPicker
        }
    }

    private var dueDateBinding: Binding<Bool> {
        Binding(
            get: { task.dueDate != nil },
            set: { isOn in
                task.dueDate = isOn ? calendar.setting(hour: settings.defaultDueHour, minute: 0, of: Date()) : nil
                if !isOn { task.hasTime = false }
                task.status = isOn ? .active : .inbox
                task.touch()
            }
        )
    }

    private var reminderBinding: Binding<Int> {
        Binding(
            get: { task.reminderMinutesBefore ?? 0 },
            set: { task.reminderMinutesBefore = $0 == 0 ? nil : $0; task.touch() }
        )
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Durée estimée", systemImage: "hourglass")
                Spacer()
                Text(task.estimatedMinutes > 0
                     ? DurationFormatter.short(minutes: task.estimatedMinutes)
                     : "Non estimée")
                    .font(.questCaption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach([0, 15, 25, 30, 45, 60, 90, 120, 180], id: \.self) { minutes in
                        Button {
                            task.estimatedMinutes = minutes
                            task.touch()
                            Haptics.selection()
                        } label: {
                            Text(minutes == 0 ? "—" : DurationFormatter.short(minutes: minutes))
                                .font(.questMicro)
                                .foregroundStyle(task.estimatedMinutes == minutes ? .white : .primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background {
                                    Capsule().fill(task.estimatedMinutes == minutes
                                                   ? AnyShapeStyle(theme.gradient)
                                                   : AnyShapeStyle(Color.primary.opacity(0.07)))
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Paramètres de jeu

    private var gameSection: some View {
        Section("Paramètres de quête") {
            Picker(selection: $task.priority) {
                ForEach(Priority.allCases) { priority in
                    Label(priority.label, systemImage: priority.symbolName).tag(priority)
                }
            } label: {
                Label("Priorité", systemImage: "flag.fill")
            }

            Picker(selection: $task.difficulty) {
                ForEach(Difficulty.allCases) { difficulty in
                    Label("\(difficulty.label) · \(difficulty.baseXP) XP", systemImage: difficulty.symbolName)
                        .tag(difficulty)
                }
            } label: {
                Label("Difficulté", systemImage: "bolt.shield.fill")
            }

            Picker(selection: $task.energy) {
                ForEach(EnergyLevel.allCases) { energy in
                    Label(energy.label, systemImage: energy.symbolName).tag(energy)
                }
            } label: {
                Label("Énergie requise", systemImage: "battery.100.bolt")
            }

            Picker(selection: areaBinding) {
                Text("Aucun").tag(String?.none)
                ForEach(LifeArea.allCases) { area in
                    Label(area.label, systemImage: area.symbolName).tag(String?.some(area.rawValue))
                }
            } label: {
                Label("Domaine", systemImage: "circle.hexagongrid.fill")
            }

            Toggle(isOn: $task.isBoss) {
                Label {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Boss")
                        Text("XP doublé, barre de PV, session de concentration")
                            .font(.questMicro)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(Color(hex: "BF5AF2"))
                }
            }

            Toggle(isOn: $task.isFlagged) {
                Label("Épinglée", systemImage: "flag.fill")
            }
        }
    }

    private var areaBinding: Binding<String?> {
        Binding(
            get: { task.lifeAreaRaw },
            set: { task.lifeAreaRaw = $0; task.touch() }
        )
    }

    // MARK: Sous-quêtes

    private var subtaskSection: some View {
        Section {
            ForEach(task.orderedSubtasks) { subtask in
                SubtaskRow(subtask: subtask) {
                    subtask.isDone.toggle()
                    subtask.completedAt = subtask.isDone ? Date() : nil
                    task.touch()
                    store.save()
                    Haptics.light()
                }
            }
            .onDelete(perform: deleteSubtasks)

            HStack {
                Image(systemName: "plus.circle")
                    .foregroundStyle(theme.accent)
                TextField("Ajouter une sous-quête", text: $newSubtask)
                    .onSubmit(addSubtask)
            }
        } header: {
            HStack {
                Text("Sous-quêtes")
                Spacer()
                if !task.orderedSubtasks.isEmpty {
                    Text("\(task.completedSubtaskCount)/\(task.orderedSubtasks.count)")
                        .font(.questMicro)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            if !task.orderedSubtasks.isEmpty {
                Text("Chaque sous-quête accomplie ajoute 2 XP, jusqu'à 20.")
            }
        }
    }

    private func addSubtask() {
        let trimmed = newSubtask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let subtask = Subtask(title: trimmed, sortIndex: Double(task.orderedSubtasks.count))
        subtask.task = task
        store.modelContext.insert(subtask)
        newSubtask = ""
        task.touch()
        store.save()
        Haptics.light()
    }

    private func deleteSubtasks(at offsets: IndexSet) {
        let items = task.orderedSubtasks
        for index in offsets where index < items.count {
            store.modelContext.delete(items[index])
        }
        task.touch()
        store.save()
    }

    // MARK: Organisation

    private var organizationSection: some View {
        Section("Organisation") {
            Picker(selection: projectBinding) {
                Text("Aucun projet").tag(UUID?.none)
                ForEach(projects.filter { !$0.isArchived }) { project in
                    Text("\(project.emoji) \(project.name)").tag(UUID?.some(project.identifier))
                }
            } label: {
                Label("Projet", systemImage: "folder.fill")
            }

            NavigationLink {
                TagPickerView(task: task)
            } label: {
                HStack {
                    Label("Étiquettes", systemImage: "number")
                    Spacer()
                    if task.sortedTags.isEmpty {
                        Text("Aucune").font(.questCaption).foregroundStyle(.secondary)
                    } else {
                        Text(task.sortedTags.map(\.name).joined(separator: ", "))
                            .font(.questCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var projectBinding: Binding<UUID?> {
        Binding(
            get: { task.project?.identifier },
            set: { newValue in
                task.project = projects.first { $0.identifier == newValue }
                task.touch()
            }
        )
    }

    // MARK: Blocs de temps

    private var blocksSection: some View {
        Section("Créneaux réservés") {
            ForEach(task.scheduledBlocks) { block in
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(Color(hex: block.colorHex))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(QuestlyFormat.mediumDate(block.start, calendar: calendar))
                            .font(.questCallout)
                        Text("\(QuestlyFormat.time(block.start, calendar: calendar)) – \(QuestlyFormat.time(block.end, calendar: calendar))")
                            .font(.questMicro)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        store.delete(block)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                showsScheduler = true
            } label: {
                Label("Trouver un créneau", systemImage: "wand.and.stars")
            }
        }
    }

    // MARK: Notes

    private var notesSection: some View {
        Section("Notes") {
            TextField("Détails, liens, contexte…", text: $task.notes, axis: .vertical)
                .lineLimit(3...10)
                .font(.questBody)
        }
    }

    // MARK: Zone sensible

    private var dangerSection: some View {
        Section {
            if let completedAt = task.completedAt {
                HStack {
                    Label("Accomplie", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Color(hex: "30D158"))
                    Spacer()
                    Text(QuestlyFormat.dueLabel(for: completedAt, hasTime: true, calendar: calendar))
                        .font(.questCaption)
                        .foregroundStyle(.secondary)
                }
            }

            if task.focusedMinutes > 0 {
                HStack {
                    Label("Concentration cumulée", systemImage: "timer")
                    Spacer()
                    Text(DurationFormatter.short(minutes: task.focusedMinutes))
                        .font(.questCaption)
                        .foregroundStyle(.secondary)
                }
            }

            Button(role: .destructive) {
                showsDeleteConfirmation = true
            } label: {
                Label("Supprimer la quête", systemImage: "trash")
            }
        }
    }

    // MARK: Sauvegarde

    private func save() {
        task.touch()
        store.save()
        notifications.schedule(
            for: task,
            calendar: calendar,
            defaultHour: settings.defaultDueHour
        )
    }
}

// MARK: - Ligne de sous-quête

struct SubtaskRow: View {
    @Bindable var subtask: Subtask
    let onToggle: () -> Void

    @Environment(\.questlyTheme) private var theme

    var body: some View {
        HStack(spacing: Metrics.spacingS) {
            Button(action: onToggle) {
                Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(subtask.isDone ? theme.accent : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            TextField("Sous-quête", text: $subtask.title)
                .strikethrough(subtask.isDone, color: .secondary)
                .foregroundStyle(subtask.isDone ? .secondary : .primary)
        }
    }
}

// MARK: - Détail des XP

struct XPBreakdownList: View {
    let task: TaskItem
    let streakDays: Int

    private var award: XPAward {
        XPEngine.award(
            for: task.xpDescriptor(),
            context: XPContext(
                streakDays: streakDays,
                comboCount: 1,
                completionDate: task.dueDate ?? Date()
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(award.breakdown) { line in
                HStack(spacing: 8) {
                    Image(systemName: line.symbolName)
                        .font(.system(size: 11))
                        .foregroundStyle(line.isPositive ? Color(hex: "30D158") : Color(hex: "FF9F0A"))
                        .frame(width: 16)
                    Text(line.label)
                        .font(.questMicro)
                    Spacer()
                    Text(line.detail)
                        .font(.questMicro)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Text("Total")
                    .font(.questCaption)
                Spacer()
                Text("\(award.totalXP) XP · \(award.coins) pièces")
                    .font(.questCaption)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Choix des étiquettes

struct TagPickerView: View {
    @Bindable var task: TaskItem

    @Environment(QuestlyStore.self) private var store
    @Environment(\.questlyTheme) private var theme
    @Query(sort: \Tag.name) private var tags: [Tag]

    @State private var newTag = ""

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "number")
                        .foregroundStyle(theme.accent)
                    TextField("Nouvelle étiquette", text: $newTag)
                        .onSubmit(addTag)
                }
            }

            Section("Étiquettes") {
                ForEach(tags) { tag in
                    Button {
                        toggle(tag)
                    } label: {
                        HStack {
                            TagChip(name: tag.name, colorHex: tag.colorHex, isSelected: isSelected(tag))
                            Spacer()
                            if isSelected(tag) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Étiquettes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func isSelected(_ tag: Tag) -> Bool {
        (task.tags ?? []).contains { $0.identifier == tag.identifier }
    }

    private func toggle(_ tag: Tag) {
        var current = task.tags ?? []
        if let index = current.firstIndex(where: { $0.identifier == tag.identifier }) {
            current.remove(at: index)
        } else {
            current.append(tag)
        }
        task.tags = current
        task.touch()
        store.save()
        Haptics.selection()
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let tag = store.findOrCreateTag(named: trimmed)
        var current = task.tags ?? []
        if !current.contains(where: { $0.identifier == tag.identifier }) {
            current.append(tag)
            task.tags = current
        }
        newTag = ""
        store.save()
    }
}
