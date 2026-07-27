import Foundation
import SwiftData

/// Conteneur SwiftData unique, partagé par l'application et par les intentions
/// Siri / Raccourcis. Deux conteneurs sur le même fichier finiraient par se
/// marcher dessus : on n'en crée donc qu'un seul.
enum AppContainer {

    static let schema = Schema([
        TaskItem.self,
        Subtask.self,
        Project.self,
        Tag.self,
        TimeBlock.self,
        PlayerProfile.self,
        CompletionEvent.self,
        QuestRecord.self,
        FocusSession.self,
        JournalEntry.self
    ])

    @MainActor
    static let shared: ModelContainer = make()

    /// Crée le conteneur, avec repli en mémoire si le disque refuse : mieux
    /// vaut une session éphémère qu'un écran noir au lancement.
    static func make() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        }

        let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(for: schema, configurations: [fallback]) {
            return container
        }

        // Ce cas ne peut survenir que si le schéma lui-même est invalide,
        // ce qui serait détecté dès le premier lancement en développement.
        fatalError("Questly : schéma SwiftData invalide.")
    }
}
