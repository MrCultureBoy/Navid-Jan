import SwiftUI
import SwiftData
import QuestlyKit

/// Première ouverture : quatre écrans pour poser le décor, choisir son héros,
/// ses domaines de vie, et repartir avec des quêtes déjà prêtes.
struct OnboardingView: View {

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(ThemeManager.self) private var themeManager
    @Environment(NotificationService.self) private var notifications
    @Environment(\.dismiss) private var dismiss

    @State private var page = 0
    @State private var name = ""
    @State private var faceID = "face.explorer"
    @State private var selectedAreas: Set<LifeArea> = [.body, .mind, .craft]
    @State private var themeID = ThemeCatalog.default.id
    @State private var wantsNotifications = true

    private var theme: QuestlyTheme { ThemeCatalog.theme(id: themeID) }

    var body: some View {
        ZStack {
            AuroraBackground(theme: theme)

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcomePage.tag(0)
                    heroPage.tag(1)
                    areasPage.tag(2)
                    readyPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator
                actionButton
            }
            .padding(.bottom, Metrics.spacingL)
        }
        .environment(\.questlyTheme, theme)
        .interactiveDismissDisabled()
    }

    // MARK: Pages

    private var welcomePage: some View {
        VStack(spacing: Metrics.spacingL) {
            Spacer()

            ZStack {
                RadiantBurst(color: theme.accent)
                    .frame(width: 260, height: 260)
                Text("⚔️")
                    .font(.system(size: 84))
            }

            VStack(spacing: Metrics.spacingS) {
                Text("Questly")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .shimmer()

                Text("Ta liste de tâches devient une aventure.")
                    .font(.questHeadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: Metrics.spacingM) {
                featureRow("bolt.fill", "Chaque quête accomplie rapporte de l'XP", "Difficulté, priorité et ponctualité comptent.")
                featureRow("flame.fill", "Les séries récompensent la régularité", "Avec des gels pour les jours sans.")
                featureRow("calendar", "Un vrai calendrier", "Jour, semaine, mois, année, agenda et time-blocking.")
            }
            .padding(.horizontal, Metrics.spacingL)

            Spacer()
        }
        .padding(Metrics.spacingM)
    }

    private func featureRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Metrics.spacingM) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 30, height: 30)
                .background { Circle().fill(theme.accent.opacity(0.15)) }

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.questCallout)
                Text(detail).font(.questMicro).foregroundStyle(.secondary)
            }
        }
    }

    private var heroPage: some View {
        VStack(spacing: Metrics.spacingL) {
            Spacer()

            Text("Qui part à l'aventure ?")
                .font(.questTitle)
                .multilineTextAlignment(.center)

            Text(AvatarCatalog.part(id: faceID)?.emoji ?? "🧭")
                .font(.system(size: 76))
                .frame(width: 130, height: 130)
                .background {
                    Circle().fill(theme.softGradient)
                }
                .overlay {
                    Circle().strokeBorder(theme.accent.opacity(0.4), lineWidth: 2)
                }

            TextField("Ton nom d'aventurier", text: $name)
                .font(.questHeadline)
                .multilineTextAlignment(.center)
                .padding(Metrics.spacingS)
                .background {
                    RoundedRectangle(cornerRadius: Metrics.cornerRadiusSmall, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .padding(.horizontal, Metrics.spacingXL)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metrics.spacingS) {
                    ForEach(AvatarCatalog.parts(in: .face).filter { $0.requiredLevel <= 1 && $0.price.isFree }) { part in
                        Button {
                            faceID = part.id
                            Haptics.selection()
                        } label: {
                            Text(part.emoji ?? "🙂")
                                .font(.system(size: 30))
                                .frame(width: 58, height: 58)
                                .background {
                                    Circle().fill(faceID == part.id
                                                  ? theme.accent.opacity(0.25)
                                                  : Color.primary.opacity(0.05))
                                }
                                .overlay {
                                    Circle().strokeBorder(faceID == part.id ? theme.accent : .clear, lineWidth: 2)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Metrics.spacingL)
            }

            themePicker

            Spacer()
        }
        .padding(Metrics.spacingM)
    }

    private var themePicker: some View {
        VStack(spacing: Metrics.spacingS) {
            Text("Ambiance")
                .font(.questCaption)
                .foregroundStyle(.secondary)

            HStack(spacing: Metrics.spacingS) {
                ForEach(ThemeCatalog.all.filter { $0.unlockItemID == nil || $0.id == "aurora" || $0.id == "forest" }) { candidate in
                    Button {
                        withAnimation(Motion.gentle) { themeID = candidate.id }
                        Haptics.selection()
                    } label: {
                        Circle()
                            .fill(candidate.gradient)
                            .frame(width: 36, height: 36)
                            .overlay {
                                Circle().strokeBorder(themeID == candidate.id ? Color.primary : .clear, lineWidth: 2)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var areasPage: some View {
        VStack(spacing: Metrics.spacingL) {
            Spacer()

            VStack(spacing: Metrics.spacingS) {
                Text("Quels domaines veux-tu faire progresser ?")
                    .font(.questTitle)
                    .multilineTextAlignment(.center)
                Text("Chaque quête accomplie fera monter l'attribut correspondant.")
                    .font(.questCallout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Metrics.spacingS), count: 2),
                spacing: Metrics.spacingS
            ) {
                ForEach(LifeArea.allCases) { area in
                    areaCard(area)
                }
            }

            Spacer()
        }
        .padding(Metrics.spacingM)
    }

    private func areaCard(_ area: LifeArea) -> some View {
        let isSelected = selectedAreas.contains(area)
        let color = Color(hex: area.hex)

        return Button {
            withAnimation(Motion.snappy) {
                if isSelected { selectedAreas.remove(area) } else { selectedAreas.insert(area) }
            }
            Haptics.selection()
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: area.symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : color)
                Text(area.label)
                    .font(.questCallout)
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(area.subtitle)
                    .font(.questMicro)
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metrics.spacingS + 2)
            .frame(height: 96)
            .background {
                RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                    .fill(isSelected
                          ? AnyShapeStyle(LinearGradient(colors: [color, color.opacity(0.7)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                          : AnyShapeStyle(Color.primary.opacity(0.05)))
            }
        }
        .buttonStyle(PressableStyle())
    }

    private var readyPage: some View {
        VStack(spacing: Metrics.spacingL) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(theme.gradient)
                .glow(theme.accent, radius: 20, opacity: 0.6)

            VStack(spacing: Metrics.spacingS) {
                Text("Tout est prêt")
                    .font(.questTitle)
                Text("Quelques quêtes de départ t'attendent pour prendre le pli.")
                    .font(.questCallout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Toggle(isOn: $wantsNotifications) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rappels et revue du soir").font(.questCallout)
                    Text("Modifiable à tout moment dans les réglages.")
                        .font(.questMicro)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Metrics.spacingM)
            .background {
                RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .padding(.horizontal, Metrics.spacingM)

            VStack(alignment: .leading, spacing: 6) {
                Text("Astuce : écris naturellement")
                    .font(.questCaption)
                Text("« Appeler le dentiste demain 14h30 #santé p2 »")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metrics.spacingM)
            .background {
                RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                    .fill(theme.accent.opacity(0.08))
            }
            .padding(.horizontal, Metrics.spacingM)

            Spacer()
        }
        .padding(Metrics.spacingM)
    }

    // MARK: Navigation

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(page == index ? theme.accent : Color.primary.opacity(0.18))
                    .frame(width: page == index ? 20 : 7, height: 7)
                    .animation(Motion.snappy, value: page)
            }
        }
        .padding(.bottom, Metrics.spacingM)
    }

    private var actionButton: some View {
        Button(page == 3 ? "Commencer l'aventure" : "Continuer") {
            if page < 3 {
                withAnimation(Motion.snappy) { page += 1 }
                Haptics.light()
            } else {
                finish()
            }
        }
        .buttonStyle(PrimaryButtonStyle(theme: theme))
        .padding(.horizontal, Metrics.spacingL)
    }

    private func finish() {
        let player = store.profile()
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            player.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var loadout = player.avatarLoadout
        loadout[AvatarSlot.face.rawValue] = faceID
        player.avatarLoadout = loadout
        player.hasCompletedOnboarding = true

        settings.themeID = themeID
        themeManager.select(id: themeID)

        SampleData.seedStarterQuests(store: store, areas: Array(selectedAreas), calendar: settings.calendar)
        store.bootstrap()

        if wantsNotifications {
            Task {
                let granted = await notifications.requestAuthorization()
                if granted {
                    notifications.scheduleDailyReview(hour: settings.dailyReviewHour)
                }
            }
        }

        settings.hasSeenOnboarding = true
        Haptics.success()
        dismiss()
    }
}

// MARK: - Quêtes de départ

enum SampleData {

    /// Quelques quêtes concrètes pour que le premier écran ne soit pas vide —
    /// et pour montrer au passage ce que l'app sait faire.
    static func seedStarterQuests(store: QuestlyStore, areas: [LifeArea], calendar: Calendar) {
        let today = Date()

        struct Seed {
            let text: String
            let area: LifeArea?
        }

        var seeds: [Seed] = [
            Seed(text: "Découvrir Questly : accomplir cette quête *facile", area: nil),
            Seed(text: "Planifier ma semaine dimanche 18h #rituel", area: .craft),
            Seed(text: "Boire un grand verre d'eau tous les jours %corps", area: .body)
        ]

        if areas.contains(.body) {
            seeds.append(Seed(text: "Marcher 20min aujourd'hui %corps", area: .body))
        }
        if areas.contains(.mind) {
            seeds.append(Seed(text: "Lire 10 pages ce soir %esprit", area: .mind))
        }
        if areas.contains(.heart) {
            seeds.append(Seed(text: "Appeler quelqu'un qui compte demain %cœur", area: .heart))
        }
        if areas.contains(.home) {
            seeds.append(Seed(text: "Ranger une surface 15min %foyer", area: .home))
        }
        if areas.contains(.wealth) {
            seeds.append(Seed(text: "Vérifier mes comptes vendredi %fortune", area: .wealth))
        }
        if areas.contains(.craft) {
            seeds.append(Seed(text: "!boss Avancer mon projet principal pendant 1h *ardu", area: .craft))
        }

        for seed in seeds {
            var parsed = NaturalLanguageParser.parse(seed.text, reference: today, calendar: calendar)
            if parsed.lifeArea == nil { parsed.lifeArea = seed.area }
            store.createTask(from: parsed)
        }
    }
}
