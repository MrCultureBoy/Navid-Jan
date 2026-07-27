import SwiftUI
import SwiftData
import QuestlyKit

/// La ligne de quête, réutilisée partout. C'est l'élément le plus vu de l'app :
/// dense en information mais lisible d'un coup d'œil, et validable d'un pouce.
struct TaskRow: View {

    let task: TaskItem
    var showsProject: Bool = true
    var showsDueDate: Bool = true
    var isCompact: Bool = false
    var onTap: (() -> Void)?

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(\.questlyTheme) private var theme

    @State private var showsBurst = false
    @State private var floatingXP: Int?

    private var accent: Color {
        if task.isBoss { return Color(hex: "BF5AF2") }
        if let area = task.lifeArea { return Color(hex: area.hex) }
        return Color(hex: task.priority.hex)
    }

    private var isOverdue: Bool {
        task.isOverdue(now: Date(), calendar: settings.calendar)
    }

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.spacingS) {
            checkbox
            details
            Spacer(minLength: 0)
            trailing
        }
        .padding(.vertical, isCompact ? 6 : 9)
        .padding(.horizontal, Metrics.spacingS)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerRadiusSmall, style: .continuous)
                .fill(task.isBoss ? accent.opacity(0.08) : Color.clear)
        }
        .overlay {
            if task.isBoss {
                RoundedRectangle(cornerRadius: Metrics.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(accent.opacity(0.28), lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .opacity(task.isCompleted ? 0.55 : 1)
        .animation(Motion.snappy, value: task.isCompleted)
    }

    // MARK: Sous-vues

    private var checkbox: some View {
        ZStack {
            QuestCheckbox(
                isCompleted: task.isCompleted,
                tint: accent,
                size: isCompact ? 22 : 26,
                isBoss: task.isBoss
            ) {
                toggle()
            }

            if showsBurst {
                CompletionBurst(color: accent)
                    .frame(width: 90, height: 90)
                    .allowsHitTesting(false)
            }

            if let floatingXP {
                FloatingXPText(amount: floatingXP)
                    .offset(x: 20)
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(task.title)
                .font(isCompact ? .questCallout : .questBody)
                .strikethrough(task.isCompleted, color: .secondary)
                .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                .lineLimit(2)

            if !metadataItems.isEmpty {
                HStack(spacing: 6) {
                    ForEach(metadataItems) { item in
                        metadataChip(item)
                    }
                }
            }

            if !task.orderedSubtasks.isEmpty && !isCompact {
                subtaskProgress
            }

            if !task.sortedTags.isEmpty && !isCompact {
                HStack(spacing: 4) {
                    ForEach(task.sortedTags.prefix(3)) { tag in
                        TagChip(name: tag.name, colorHex: tag.colorHex)
                    }
                    if task.sortedTags.count > 3 {
                        Text("+\(task.sortedTags.count - 3)")
                            .font(.questMicro)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var subtaskProgress: some View {
        HStack(spacing: 6) {
            ProgressView(value: task.progress)
                .progressViewStyle(.linear)
                .tint(accent)
                .frame(width: 62)
            Text("\(task.completedSubtaskCount)/\(task.orderedSubtasks.count)")
                .font(.questMicro)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var trailing: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if !task.isCompleted {
                XPPill(amount: task.previewXP, isPreview: true)
            } else if task.earnedXP > 0 {
                XPPill(amount: task.earnedXP)
            }

            if task.priority != .p4 {
                PriorityBadge(priority: task.priority, compact: true)
            }
        }
    }

    // MARK: Métadonnées

    private struct MetadataItem: Identifiable {
        let id: String
        let symbolName: String
        let text: String
        let color: Color
    }

    private var metadataItems: [MetadataItem] {
        var items: [MetadataItem] = []

        if showsDueDate, let due = task.dueDate {
            items.append(MetadataItem(
                id: "due",
                symbolName: isOverdue ? "exclamationmark.triangle.fill" : "calendar",
                text: isOverdue
                    ? QuestlyFormat.overdueLabel(for: due, calendar: settings.calendar)
                    : QuestlyFormat.dueLabel(for: due, hasTime: task.hasTime, calendar: settings.calendar),
                color: isOverdue ? Color(hex: "FF453A") : .secondary
            ))
        }

        if task.estimatedMinutes > 0 {
            items.append(MetadataItem(
                id: "duration",
                symbolName: "hourglass",
                text: DurationFormatter.short(minutes: task.estimatedMinutes),
                color: .secondary
            ))
        }

        if task.isRecurring {
            items.append(MetadataItem(
                id: "repeat",
                symbolName: "repeat",
                text: "",
                color: theme.accent
            ))
        }

        if showsProject, let project = task.project {
            items.append(MetadataItem(
                id: "project",
                symbolName: "folder.fill",
                text: project.name,
                color: Color(hex: project.colorHex)
            ))
        }

        if task.focusedMinutes > 0 {
            items.append(MetadataItem(
                id: "focus",
                symbolName: "timer",
                text: DurationFormatter.short(minutes: task.focusedMinutes),
                color: Color(hex: "30D158")
            ))
        }

        return items
    }

    private func metadataChip(_ item: MetadataItem) -> some View {
        HStack(spacing: 3) {
            Image(systemName: item.symbolName)
                .font(.system(size: 9, weight: .semibold))
            if !item.text.isEmpty {
                Text(item.text).font(.questMicro)
            }
        }
        .foregroundStyle(item.color)
    }

    // MARK: Actions

    private func toggle() {
        if task.isCompleted {
            store.uncomplete(task)
            return
        }

        let bundle = store.complete(task)
        floatingXP = bundle.award.totalXP
        showsBurst = true
        Haptics.play(bundle.comboCount > 1 ? .combo(bundle.comboCount) : .success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            showsBurst = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            floatingXP = nil
        }
    }
}

// MARK: - Actions de balayage

/// Actions de balayage communes à toutes les listes de quêtes.
struct TaskSwipeActions: ViewModifier {
    let task: TaskItem
    var onOpenDetail: (() -> Void)?

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if task.isOpen {
                    Button {
                        store.snooze(task, to: Date(), keepTime: task.hasTime)
                        Haptics.light()
                    } label: {
                        Label("Aujourd'hui", systemImage: "sun.max.fill")
                    }
                    .tint(Color(hex: "FF9F0A"))

                    Button {
                        store.snooze(task, to: Date().adding(days: 1, calendar: settings.calendar), keepTime: task.hasTime)
                        Haptics.light()
                    } label: {
                        Label("Demain", systemImage: "arrow.right.circle.fill")
                    }
                    .tint(Color(hex: "5E5CE6"))
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    store.delete(task)
                    Haptics.warning()
                } label: {
                    Label("Supprimer", systemImage: "trash.fill")
                }

                Button {
                    task.isFlagged.toggle()
                    task.touch()
                    store.save()
                    Haptics.light()
                } label: {
                    Label(task.isFlagged ? "Retirer" : "Épingler", systemImage: "flag.fill")
                }
                .tint(Color(hex: "FFD60A"))

                Button {
                    task.isBoss.toggle()
                    task.touch()
                    store.save()
                    Haptics.play(.medium)
                } label: {
                    Label("Boss", systemImage: "crown.fill")
                }
                .tint(Color(hex: "BF5AF2"))
            }
            .contextMenu {
                Button {
                    onOpenDetail?()
                } label: {
                    Label("Ouvrir", systemImage: "square.and.pencil")
                }
                Button {
                    store.snooze(task, to: Date().adding(days: 7, calendar: settings.calendar))
                } label: {
                    Label("Dans une semaine", systemImage: "calendar.badge.clock")
                }
                Button {
                    duplicate()
                } label: {
                    Label("Dupliquer", systemImage: "doc.on.doc")
                }
                Divider()
                Button(role: .destructive) {
                    store.delete(task)
                } label: {
                    Label("Supprimer", systemImage: "trash")
                }
            }
    }

    private func duplicate() {
        let copy = store.createTask(title: task.title, dueDate: task.dueDate, hasTime: task.hasTime)
        copy.notes = task.notes
        copy.priority = task.priority
        copy.difficulty = task.difficulty
        copy.energy = task.energy
        copy.estimatedMinutes = task.estimatedMinutes
        copy.lifeArea = task.lifeArea
        copy.isBoss = task.isBoss
        copy.project = task.project
        copy.tags = task.tags
        store.save()
    }
}

extension View {
    func taskSwipeActions(for task: TaskItem, onOpenDetail: (() -> Void)? = nil) -> some View {
        modifier(TaskSwipeActions(task: task, onOpenDetail: onOpenDetail))
    }
}
