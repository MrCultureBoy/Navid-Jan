import AppIntents
import SwiftData
import QuestlyKit

// MARK: - Ajouter une quête

/// « Dis Siri, ajoute une quête dans Questly. »
/// L'intention passe par le même analyseur que la saisie rapide : dicter
/// « courses demain 18h » crée une quête correctement datée.
struct AddQuestIntent: AppIntent {

    static var title: LocalizedStringResource = "Ajouter une quête"
    static var description = IntentDescription(
        "Crée une quête dans Questly. La date, l'heure, la priorité et les étiquettes sont comprises automatiquement."
    )
    static var openAppWhenRun = false

    @Parameter(title: "Quête", requestValueDialog: "Que veux-tu accomplir ?")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AppContainer.shared.mainContext
        let store = QuestlyStore(modelContext: context)
        let parsed = NaturalLanguageParser.parse(text)
        let task = store.createTask(from: parsed)

        let dialog: IntentDialog
        if let due = task.dueDate {
            let label = QuestlyFormat.dueLabel(for: due, hasTime: task.hasTime)
            dialog = IntentDialog("« \(task.title) » ajoutée pour \(label).")
        } else {
            dialog = IntentDialog("« \(task.title) » ajoutée à ta boîte de réception.")
        }
        return .result(dialog: dialog)
    }
}

// MARK: - Résumé du jour

/// Un point rapide sans ouvrir l'app.
struct DailyBriefIntent: AppIntent {

    static var title: LocalizedStringResource = "Résumé de ma journée"
    static var description = IntentDescription(
        "Donne le nombre de quêtes du jour, la série en cours et le niveau atteint."
    )
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = AppContainer.shared.mainContext
        let store = QuestlyStore(modelContext: context)
        store.refreshStreak()

        let calendar = Calendar.questly()
        let open = store.openTasks()
        let today = open.filter { task in
            guard let due = task.dueDate else { return false }
            return calendar.startOfDay(for: due) <= calendar.startOfDay(for: Date())
        }
        let overdue = open.filter { $0.isOverdue(now: Date(), calendar: calendar) }
        let player = store.profile()

        var parts: [String] = []
        parts.append(today.isEmpty
                     ? "Aucune quête prévue aujourd'hui."
                     : "\(today.count) quête\(today.count > 1 ? "s" : "") au programme.")
        if !overdue.isEmpty {
            parts.append("\(overdue.count) en retard.")
        }
        parts.append("Niveau \(player.level), série de \(store.streak.current) jour\(store.streak.current > 1 ? "s" : "").")

        return .result(dialog: IntentDialog(stringLiteral: parts.joined(separator: " ")))
    }
}

// MARK: - Démarrer une session

/// Ouvre l'app directement sur le Donjon.
struct StartFocusIntent: AppIntent {

    static var title: LocalizedStringResource = "Démarrer une session de concentration"
    static var description = IntentDescription("Ouvre Questly sur le minuteur de concentration.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}

// MARK: - Raccourcis proposés

struct QuestlyShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddQuestIntent(),
            phrases: [
                "Ajouter une quête dans \(.applicationName)",
                "Nouvelle quête \(.applicationName)",
                "Note dans \(.applicationName)"
            ],
            shortTitle: "Nouvelle quête",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: DailyBriefIntent(),
            phrases: [
                "Résumé de ma journée dans \(.applicationName)",
                "Où j'en suis dans \(.applicationName)"
            ],
            shortTitle: "Résumé du jour",
            systemImageName: "sun.max.fill"
        )

        AppShortcut(
            intent: StartFocusIntent(),
            phrases: [
                "Démarrer une session dans \(.applicationName)",
                "Concentration \(.applicationName)"
            ],
            shortTitle: "Concentration",
            systemImageName: "timer"
        )
    }
}
