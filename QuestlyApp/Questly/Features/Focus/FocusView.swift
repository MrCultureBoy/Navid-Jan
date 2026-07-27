import SwiftUI
import SwiftData
import Combine
import QuestlyKit

/// Le Donjon : minuteur de concentration façon Pomodoro, transformé en combat.
/// Chaque minute de concentration retire des points de vie au boss choisi.
struct FocusView: View {

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(NotificationService.self) private var notifications
    @Environment(\.questlyTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    @Query private var tasks: [TaskItem]
    @Query private var sessions: [FocusSession]

    @State private var phase: Phase = .idle
    @State private var kind: SessionKind = .focus
    @State private var startedAt: Date?
    @State private var elapsedBeforePause = 0
    @State private var tick = Date()
    @State private var selectedTaskID: UUID?
    @State private var distractions = 0
    @State private var completedRounds = 0
    @State private var showsTaskPicker = false
    @State private var showsCelebration = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum Phase: Equatable {
        case idle
        case running
        case paused
        case finished
    }

    enum SessionKind: Equatable {
        case focus
        case shortBreak
        case longBreak

        var label: String {
            switch self {
            case .focus: return "Concentration"
            case .shortBreak: return "Pause"
            case .longBreak: return "Grande pause"
            }
        }

        var symbolName: String {
            switch self {
            case .focus: return "target"
            case .shortBreak: return "cup.and.saucer.fill"
            case .longBreak: return "figure.walk"
            }
        }
    }

    private var calendar: Calendar { settings.calendar }

    private var selectedTask: TaskItem? {
        guard let selectedTaskID else { return nil }
        return tasks.first { $0.identifier == selectedTaskID }
    }

    private var plannedMinutes: Int {
        switch kind {
        case .focus: return settings.focusDuration
        case .shortBreak: return settings.breakDuration
        case .longBreak: return settings.longBreakDuration
        }
    }

    private var elapsedSeconds: Int {
        guard let startedAt, phase == .running else { return elapsedBeforePause }
        return elapsedBeforePause + Int(tick.timeIntervalSince(startedAt))
    }

    private var remainingSeconds: Int {
        max(0, plannedMinutes * 60 - elapsedSeconds)
    }

    private var progress: Double {
        let total = Double(plannedMinutes * 60)
        guard total > 0 else { return 0 }
        return min(1, Double(elapsedSeconds) / total)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Metrics.spacingL) {
                kindPicker
                timerDial
                targetCard
                controls
                if kind == .focus { distractionCard }
                todaySummary
                Color.clear.frame(height: 110)
            }
            .padding(.horizontal, Metrics.spacingM)
            .padding(.top, Metrics.spacingM)
        }
        .scrollIndicators(.hidden)
        .onReceive(timer) { date in
            tick = date
            if phase == .running && remainingSeconds == 0 {
                finish()
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            // Le temps continue de couler en arrière-plan : on recalcule à partir
            // des dates plutôt que de compter les tics.
            if newValue == .active { tick = Date() }
        }
        .sheet(isPresented: $showsTaskPicker) {
            FocusTaskPicker(selectedTaskID: $selectedTaskID)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: Type de session

    private var kindPicker: some View {
        HStack(spacing: Metrics.spacingS) {
            ForEach([SessionKind.focus, .shortBreak, .longBreak], id: \.self) { value in
                Button {
                    guard phase == .idle else { return }
                    withAnimation(Motion.snappy) { kind = value }
                    Haptics.selection()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: value.symbolName)
                            .font(.system(size: 14, weight: .semibold))
                        Text(value.label)
                            .font(.questMicro)
                    }
                    .foregroundStyle(kind == value ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: Metrics.cornerRadiusSmall, style: .continuous)
                            .fill(kind == value
                                  ? AnyShapeStyle(theme.gradient)
                                  : AnyShapeStyle(Color.primary.opacity(0.05)))
                    }
                }
                .buttonStyle(.plain)
                .disabled(phase != .idle)
            }
        }
    }

    // MARK: Cadran

    private var timerDial: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.07), lineWidth: 16)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(theme.ringGradient, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .glow(theme.accent, radius: 14, opacity: phase == .running ? 0.6 : 0.2)
                .animation(.linear(duration: 1), value: progress)

            VStack(spacing: 4) {
                Text(DurationFormatter.clock(seconds: remainingSeconds))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text(phaseLabel)
                    .font(.questCaption)
                    .foregroundStyle(.secondary)

                if kind == .focus, completedRounds > 0 {
                    HStack(spacing: 3) {
                        ForEach(0..<min(completedRounds, settings.sessionsBeforeLongBreak), id: \.self) { _ in
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 5, height: 5)
                        }
                    }
                }
            }
        }
        .frame(width: 250, height: 250)
        .padding(.vertical, Metrics.spacingS)
    }

    private var phaseLabel: String {
        switch phase {
        case .idle: return "Prêt à plonger"
        case .running: return kind.label + " en cours"
        case .paused: return "En pause"
        case .finished: return "Session terminée"
        }
    }

    // MARK: Cible

    private var targetCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Metrics.spacingS) {
                HStack {
                    Label(selectedTask == nil ? "Aucune quête ciblée" : "Cible", systemImage: "scope")
                        .font(.questCaption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(selectedTask == nil ? "Choisir" : "Changer") {
                        showsTaskPicker = true
                    }
                    .font(.questMicro)
                    .foregroundStyle(theme.accent)
                }

                if let task = selectedTask {
                    Text(task.title)
                        .font(.questHeadline)

                    if task.isBoss {
                        BossHealthBar(
                            fraction: bossFraction(for: task),
                            remainingMinutes: max(0, task.bossRemainingHP - liveMinutes)
                        )
                        Text("Chaque minute de concentration retire 1 PV.")
                            .font(.questMicro)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: Metrics.spacingS) {
                            DifficultyBadge(difficulty: task.difficulty)
                            if task.focusedMinutes > 0 {
                                Label(
                                    DurationFormatter.short(minutes: task.focusedMinutes),
                                    systemImage: "timer"
                                )
                                .font(.questMicro)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text("Une session sans cible compte quand même dans tes statistiques.")
                        .font(.questCaption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var liveMinutes: Int {
        kind == .focus ? elapsedSeconds / 60 : 0
    }

    private func bossFraction(for task: TaskItem) -> Double {
        let total = Double(task.difficulty.bossHitPoints)
        guard total > 0 else { return 0 }
        let remaining = Double(max(0, task.bossRemainingHP - liveMinutes))
        return max(0, min(1, remaining / total))
    }

    // MARK: Commandes

    private var controls: some View {
        HStack(spacing: Metrics.spacingM) {
            if phase == .running || phase == .paused {
                Button {
                    stop(save: true)
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 54, height: 54)
                        .background { Circle().fill(Color.primary.opacity(0.08)) }
                }
                .buttonStyle(PressableStyle())
            }

            Button {
                toggleRun()
            } label: {
                Image(systemName: phase == .running ? "pause.fill" : "play.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background {
                        Circle()
                            .fill(theme.gradient)
                            .shadow(color: theme.accent.opacity(0.45), radius: 18, y: 8)
                    }
            }
            .buttonStyle(PressableStyle(scale: 0.92))

            if phase == .idle {
                Menu {
                    ForEach([15, 25, 30, 45, 50, 60, 90], id: \.self) { minutes in
                        Button("\(minutes) minutes") {
                            settings.focusDuration = minutes
                        }
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 54, height: 54)
                        .background { Circle().fill(Color.primary.opacity(0.08)) }
                }
            }
        }
    }

    private var distractionCard: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Distractions")
                        .font(.questCallout)
                    Text("Note-les au lieu d'y céder.")
                        .font(.questMicro)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(distractions)")
                    .font(.questNumber(22))
                    .monospacedDigit()
                Button {
                    distractions += 1
                    Haptics.light()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background { Circle().fill(Color.primary.opacity(0.08)) }
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    // MARK: Récapitulatif

    private var todaySummary: some View {
        let todaySessions = sessions.filter {
            calendar.isSameDay($0.start, Date()) && !$0.isBreak
        }
        let minutes = todaySessions.reduce(0) { $0 + $1.actualMinutes }

        return VStack(alignment: .leading, spacing: Metrics.spacingS) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.accent)
                Text("Aujourd'hui")
                    .font(.questCallout)
                    .foregroundStyle(.secondary)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: Metrics.spacingS) {
                    HStack {
                        statBlock(value: "\(todaySessions.count)", label: "sessions")
                        Divider().frame(height: 30)
                        statBlock(value: DurationFormatter.short(minutes: minutes), label: "concentration")
                        Divider().frame(height: 30)
                        statBlock(
                            value: "\(todaySessions.reduce(0) { $0 + $1.distractions })",
                            label: "distractions"
                        )
                    }

                    if !todaySessions.isEmpty {
                        Divider().opacity(0.4)
                        ForEach(todaySessions.sorted { $0.start > $1.start }.prefix(4)) { session in
                            HStack {
                                Image(systemName: session.wasCompleted ? "checkmark.circle.fill" : "xmark.circle")
                                    .font(.system(size: 12))
                                    .foregroundStyle(session.wasCompleted ? Color(hex: "30D158") : .secondary)
                                Text(session.taskTitle.isEmpty ? "Session libre" : session.taskTitle)
                                    .font(.questCaption)
                                    .lineLimit(1)
                                Spacer()
                                Text(DurationFormatter.short(minutes: session.actualMinutes))
                                    .font(.questMicro)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.questNumber(18))
                .monospacedDigit()
            Text(label)
                .font(.questMicro)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Machine à états

    private func toggleRun() {
        switch phase {
        case .idle, .finished:
            start()
        case .running:
            pause()
        case .paused:
            resume()
        }
    }

    private func start() {
        elapsedBeforePause = 0
        distractions = 0
        startedAt = Date()
        tick = Date()
        withAnimation(Motion.snappy) { phase = .running }
        Haptics.play(.medium)
    }

    private func pause() {
        elapsedBeforePause = elapsedSeconds
        startedAt = nil
        withAnimation(Motion.snappy) { phase = .paused }
        Haptics.light()
    }

    private func resume() {
        startedAt = Date()
        tick = Date()
        withAnimation(Motion.snappy) { phase = .running }
        Haptics.light()
    }

    /// Arrêt manuel : on enregistre quand même le temps déjà passé.
    private func stop(save: Bool) {
        let minutes = elapsedSeconds / 60
        if save && minutes >= 1 && kind == .focus {
            store.recordFocus(
                minutes: minutes,
                on: selectedTask,
                completed: false,
                distractions: distractions
            )
        }
        reset()
        Haptics.warning()
    }

    private func finish() {
        let minutes = max(1, plannedMinutes)
        if kind == .focus {
            store.recordFocus(
                minutes: minutes,
                on: selectedTask,
                completed: true,
                distractions: distractions
            )
            completedRounds += 1
            notifications.notifyFocusFinished(
                taskTitle: selectedTask?.title ?? "",
                minutes: minutes
            )
            Haptics.play(.levelUp)

            // Boss vaincu : la quête se termine d'elle-même.
            if let task = selectedTask, task.isBoss, task.bossRemainingHP == 0, task.isOpen {
                _ = store.complete(task)
            }

            // Enchaînement automatique vers la pause qui convient.
            kind = completedRounds % settings.sessionsBeforeLongBreak == 0 ? .longBreak : .shortBreak
        } else {
            kind = .focus
            Haptics.success()
        }

        reset()
        withAnimation(Motion.celebration) { phase = .finished }
    }

    private func reset() {
        startedAt = nil
        elapsedBeforePause = 0
        distractions = 0
        withAnimation(Motion.snappy) { phase = .idle }
    }
}

// MARK: - Choix de la cible

struct FocusTaskPicker: View {

    @Binding var selectedTaskID: UUID?

    @Environment(SettingsStore.self) private var settings
    @Environment(\.questlyTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @Query private var tasks: [TaskItem]
    @State private var searchText = ""

    private var calendar: Calendar { settings.calendar }

    private var candidates: [TaskItem] {
        let open = tasks.filter(\.isOpen)
        guard !searchText.isEmpty else {
            return open.sorted(by: TaskSorting.smart(calendar: calendar))
        }
        let needle = searchText.lowercased()
        return open.filter { $0.title.lowercased().contains(needle) }
    }

    private var bosses: [TaskItem] {
        candidates.filter(\.isBoss)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedTaskID = nil
                        dismiss()
                    } label: {
                        Label("Session libre", systemImage: "wind")
                    }
                }

                if !bosses.isEmpty {
                    Section("Boss") {
                        ForEach(bosses) { task in
                            row(task)
                        }
                    }
                }

                Section("Quêtes ouvertes") {
                    ForEach(candidates.filter { !$0.isBoss }) { task in
                        row(task)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Chercher")
            .navigationTitle("Cibler une quête")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func row(_ task: TaskItem) -> some View {
        Button {
            selectedTaskID = task.identifier
            Haptics.selection()
            dismiss()
        } label: {
            HStack {
                if task.isBoss {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(Color(hex: "BF5AF2"))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(task.title).font(.questBody)
                    if task.isBoss {
                        Text("\(task.bossRemainingHP) PV restants")
                            .font(.questMicro)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if selectedTaskID == task.identifier {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
