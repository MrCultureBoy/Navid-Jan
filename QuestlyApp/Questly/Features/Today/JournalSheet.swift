import SwiftUI
import SwiftData
import QuestlyKit

/// Note de journal du soir. Deux gestes : une humeur, quelques mots.
/// C'est ce qui transforme une liste de tâches en trace de vie.
struct JournalSheet: View {

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(\.questlyTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]

    @State private var text = ""
    @State private var mood = 3

    private var calendar: Calendar { settings.calendar }

    private var todayEntry: JournalEntry? {
        entries.first { calendar.isSameDay($0.day, Date()) }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Metrics.spacingM) {
                moodPicker

                TextField("Qu'est-ce qui a marqué la journée ?", text: $text, axis: .vertical)
                    .font(.questBody)
                    .lineLimit(4...8)
                    .padding(Metrics.spacingS)
                    .background {
                        RoundedRectangle(cornerRadius: Metrics.cornerRadiusSmall, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    }

                dayRecap

                if !entries.isEmpty {
                    Text("Dernières notes")
                        .font(.questCaption)
                        .foregroundStyle(.secondary)

                    ScrollView {
                        VStack(spacing: Metrics.spacingS) {
                            ForEach(entries.prefix(5)) { entry in
                                HStack(alignment: .top, spacing: Metrics.spacingS) {
                                    Text(entry.moodEmoji).font(.system(size: 20))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(QuestlyFormat.mediumDate(entry.day, calendar: calendar))
                                            .font(.questMicro)
                                            .foregroundStyle(.secondary)
                                        Text(entry.text)
                                            .font(.questCaption)
                                            .lineLimit(3)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(Metrics.spacingM)
            .navigationTitle("Journal du jour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .fontWeight(.semibold)
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let entry = todayEntry {
                    text = entry.text
                    mood = entry.mood
                }
            }
        }
    }

    private var moodPicker: some View {
        HStack(spacing: Metrics.spacingS) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    withAnimation(Motion.bouncy) { mood = value }
                    Haptics.selection()
                } label: {
                    Text(emoji(for: value))
                        .font(.system(size: mood == value ? 34 : 26))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            RoundedRectangle(cornerRadius: Metrics.cornerRadiusSmall, style: .continuous)
                                .fill(mood == value ? theme.accent.opacity(0.16) : Color.clear)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func emoji(for value: Int) -> String {
        switch value {
        case 1: return "😞"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        default: return "🤩"
        }
    }

    private var dayRecap: some View {
        let count = store.completionCount(on: Date())
        let stats = store.currentStats(days: 1)

        return HStack(spacing: Metrics.spacingM) {
            recapItem("\(count)", "quêtes")
            recapItem("\(stats.totalXP)", "XP")
            recapItem(DurationFormatter.short(minutes: stats.totalFocusMinutes), "concentration")
        }
        .padding(Metrics.spacingS)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerRadiusSmall, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    private func recapItem(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.questNumber(17))
                .monospacedDigit()
            Text(label)
                .font(.questMicro)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let entry = todayEntry {
            entry.text = trimmed
            entry.mood = mood
            store.save()
        } else {
            store.writeJournal(text: trimmed, mood: mood)
        }
        Haptics.success()
        dismiss()
    }
}
