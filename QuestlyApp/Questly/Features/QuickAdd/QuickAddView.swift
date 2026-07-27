import SwiftUI
import SwiftData
import QuestlyKit

/// Saisie rapide. Une seule zone de texte : on écrit comme on parle, l'app
/// comprend la date, l'heure, la durée, la priorité, le projet et la répétition.
struct QuickAddView: View {

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(\.questlyTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @Query private var projects: [Project]

    @State private var text = ""
    @State private var parsed = ParsedInput()
    @State private var selectedProject: Project?
    @State private var difficulty: Difficulty = .medium
    @State private var showsHelp = false
    @State private var lastCreatedTitle: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingM) {
            handle
            field
            if parsed.hasMetadata { tokenStrip }
            quickChips
            footer
        }
        .padding(Metrics.spacingM)
        .background(Color.clear)
        .onAppear { isFocused = true }
        .onChange(of: text) { _, newValue in
            parsed = NaturalLanguageParser.parse(newValue, reference: Date(), calendar: settings.calendar)
        }
        .sheet(isPresented: $showsHelp) {
            QuickAddHelpView()
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: Sous-vues

    private var handle: some View {
        HStack {
            Text("Nouvelle quête")
                .font(.questHeadline)
            Spacer()
            Button {
                showsHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var field: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Ex. : Appeler le dentiste demain 14h30 #santé p2", text: $text, axis: .vertical)
                .font(.questBody)
                .lineLimit(1...4)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit { submit() }
                .padding(Metrics.spacingS + 2)
                .background {
                    RoundedRectangle(cornerRadius: Metrics.cornerRadiusSmall, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(theme.accent.opacity(isFocused ? 0.45 : 0.1), lineWidth: 1)
                }

            if !parsed.title.isEmpty && parsed.hasMetadata {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                    Text("Titre retenu : « \(parsed.title) »")
                        .font(.questMicro)
                }
                .foregroundStyle(theme.accent)
            }
        }
    }

    /// Pastilles de ce que l'analyseur a compris — le retour immédiat qui
    /// donne confiance dans la saisie naturelle.
    private var tokenStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(parsed.tokens) { token in
                    HStack(spacing: 4) {
                        Image(systemName: token.symbolName)
                            .font(.system(size: 9, weight: .semibold))
                        Text(token.display.isEmpty ? token.text : token.display)
                            .font(.questMicro)
                    }
                    .foregroundStyle(Color(hex: token.hex))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background {
                        Capsule().fill(Color(hex: token.hex).opacity(0.14))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 2)
        }
        .animation(Motion.snappy, value: parsed.tokens.count)
    }

    private var quickChips: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip("Aujourd'hui", symbol: "sun.max.fill") { append("aujourd'hui") }
                    chip("Demain", symbol: "arrow.right.circle.fill") { append("demain") }
                    chip("Ce soir", symbol: "moon.fill") { append("ce soir") }
                    chip("Lundi", symbol: "calendar") { append("lundi") }
                    chip("P1", symbol: "flame.fill") { append("p1") }
                    chip("30 min", symbol: "hourglass") { append("30min") }
                    chip("Chaque jour", symbol: "repeat") { append("tous les jours") }
                    chip("Boss", symbol: "crown.fill") { append("!boss") }
                }
            }

            HStack(spacing: Metrics.spacingS) {
                Menu {
                    Button("Aucun projet") { selectedProject = nil }
                    ForEach(projects.filter { !$0.isArchived }) { project in
                        Button("\(project.emoji) \(project.name)") { selectedProject = project }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill").font(.system(size: 10))
                        Text(selectedProject?.name ?? "Projet")
                            .font(.questMicro)
                    }
                    .foregroundStyle(selectedProject == nil ? .secondary : Color(hex: selectedProject?.colorHex ?? "5E5CE6"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background { Capsule().fill(Color.primary.opacity(0.06)) }
                }

                Menu {
                    ForEach(Difficulty.allCases) { level in
                        Button {
                            difficulty = level
                        } label: {
                            Label(level.label, systemImage: level.symbolName)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: difficulty.symbolName).font(.system(size: 10))
                        Text(difficulty.label).font(.questMicro)
                    }
                    .foregroundStyle(Color(hex: difficulty.hex))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background { Capsule().fill(Color(hex: difficulty.hex).opacity(0.14)) }
                }

                Spacer()

                XPPill(amount: previewXP, isPreview: true)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: Metrics.spacingS) {
            if let lastCreatedTitle {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: "30D158"))
                    Text("« \(lastCreatedTitle) » ajoutée")
                        .font(.questMicro)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }

            HStack(spacing: Metrics.spacingS) {
                Button {
                    submit(keepOpen: true)
                } label: {
                    Label("Ajouter et continuer", systemImage: "plus.circle")
                        .font(.questCaption)
                }
                .buttonStyle(SoftButtonStyle(tint: theme.accent))
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Ajouter") { submit() }
                    .buttonStyle(PrimaryButtonStyle(
                        theme: theme,
                        isEnabled: !text.trimmingCharacters(in: .whitespaces).isEmpty
                    ))
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func chip(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.selection()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 10))
                Text(title).font(.questMicro)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background { Capsule().fill(Color.primary.opacity(0.06)) }
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Logique

    private var previewXP: Int {
        let descriptor = XPTaskDescriptor(
            difficulty: parsed.difficulty ?? difficulty,
            priority: parsed.priority ?? .p4,
            estimatedMinutes: parsed.durationMinutes,
            dueDate: parsed.dueDate,
            hasTimeComponent: parsed.hasTime,
            isBoss: parsed.isBoss,
            lifeArea: parsed.lifeArea
        )
        return XPEngine.previewXP(for: descriptor)
    }

    private func append(_ fragment: String) {
        if text.isEmpty {
            text = fragment
        } else if text.hasSuffix(" ") {
            text += fragment
        } else {
            text += " " + fragment
        }
    }

    private func submit(keepOpen: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var input = parsed
        if input.difficulty == nil { input.difficulty = difficulty }

        let task = store.createTask(from: input, defaultProject: selectedProject)
        Haptics.success()

        withAnimation(Motion.snappy) {
            lastCreatedTitle = task.title
        }

        text = ""
        parsed = ParsedInput()

        if keepOpen {
            isFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { lastCreatedTitle = nil }
            }
        } else {
            dismiss()
        }
    }
}

// MARK: - Aide à la syntaxe

struct QuickAddHelpView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.questlyTheme) private var theme

    private struct Rule: Identifiable {
        let id = UUID()
        let syntax: String
        let meaning: String
        let example: String
    }

    private let rules: [Rule] = [
        Rule(syntax: "demain, lundi, 15/03…", meaning: "Date d'échéance", example: "Courses samedi"),
        Rule(syntax: "14h30, 9h, 2pm", meaning: "Heure précise", example: "Dentiste demain 14h30"),
        Rule(syntax: "30min, 2 heures, pendant 1h30", meaning: "Durée estimée", example: "Réviser pendant 2h"),
        Rule(syntax: "p1 … p4", meaning: "Priorité (p1 = critique)", example: "Payer le loyer p1"),
        Rule(syntax: "#étiquette", meaning: "Étiquette", example: "Lait #courses"),
        Rule(syntax: "@contexte", meaning: "Contexte, devient une étiquette", example: "Imprimer @bureau"),
        Rule(syntax: "+projet", meaning: "Projet", example: "Maquette +Refonte"),
        Rule(syntax: "*facile … *légendaire", meaning: "Difficulté, donc XP", example: "Thèse *légendaire"),
        Rule(syntax: "%corps, %esprit…", meaning: "Domaine de vie", example: "Squats %corps"),
        Rule(syntax: "!boss", meaning: "Marque un boss (XP ×2)", example: "!boss Refonte"),
        Rule(syntax: "tous les jours, chaque lundi", meaning: "Répétition", example: "Yoga chaque lundi 9h"),
        Rule(syntax: "rappel 30min avant", meaning: "Rappel", example: "Visio 15h rappel 30min avant")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Écris naturellement : l'app repère les informations et les retire du titre.")
                        .font(.questCallout)
                        .foregroundStyle(.secondary)
                }
                Section("Syntaxe reconnue") {
                    ForEach(rules) { rule in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(rule.syntax)
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundStyle(theme.accent)
                            Text(rule.meaning).font(.questCaption)
                            Text(rule.example)
                                .font(.questMicro)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Saisie rapide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
