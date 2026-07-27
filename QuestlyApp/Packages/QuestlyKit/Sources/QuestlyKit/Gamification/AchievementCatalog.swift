import Foundation

/// Le catalogue complet des hauts faits. Purement déclaratif : ajouter une
/// ligne suffit à créer un nouveau badge, sa progression et ses récompenses.
public enum AchievementCatalog {

    public static let all: [AchievementDefinition] = beginnings + volume + consistency
        + focus + mastery + balance + collection + secrets

    public static func definition(id: String) -> AchievementDefinition? {
        lookup[id]
    }

    private static let lookup: [String: AchievementDefinition] = {
        Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }()

    public static func grouped() -> [(category: AchievementCategory, items: [AchievementDefinition])] {
        AchievementCategory.allCases.map { category in
            (category, all.filter { $0.category == category })
        }
    }

    // MARK: Premiers pas

    static let beginnings: [AchievementDefinition] = [
        AchievementDefinition(
            id: "first.blood", title: "Le grand départ",
            detail: "Accomplir sa toute première quête.",
            symbolName: "flag.checkered", rarity: .common,
            category: .beginnings, metric: .tasksCompleted, goal: 1
        ),
        AchievementDefinition(
            id: "first.plan", title: "Cartographe",
            detail: "Créer 10 quêtes.",
            symbolName: "map.fill", rarity: .common,
            category: .beginnings, metric: .tasksCreated, goal: 10
        ),
        AchievementDefinition(
            id: "first.focus", title: "Première transe",
            detail: "Terminer une session de concentration.",
            symbolName: "timer", rarity: .common,
            category: .beginnings, metric: .focusSessions, goal: 1
        ),
        AchievementDefinition(
            id: "first.boss", title: "Tombeur de géant",
            detail: "Vaincre un premier boss.",
            symbolName: "crown.fill", rarity: .uncommon,
            category: .beginnings, metric: .bossesDefeated, goal: 1
        ),
        AchievementDefinition(
            id: "first.block", title: "Maître du temps",
            detail: "Planifier 5 blocs dans le calendrier.",
            symbolName: "calendar.badge.clock", rarity: .common,
            category: .beginnings, metric: .calendarBlocks, goal: 5
        ),
        AchievementDefinition(
            id: "first.level5", title: "On prend ses marques",
            detail: "Atteindre le niveau 5.",
            symbolName: "arrow.up.circle.fill", rarity: .common,
            category: .beginnings, metric: .level, goal: 5
        )
    ]

    // MARK: Volume

    static let volume: [AchievementDefinition] = [
        AchievementDefinition(
            id: "vol.25", title: "Bon élève",
            detail: "Accomplir 25 quêtes.",
            symbolName: "checkmark.circle.fill", rarity: .common,
            category: .volume, metric: .tasksCompleted, goal: 25
        ),
        AchievementDefinition(
            id: "vol.100", title: "Centurion",
            detail: "Accomplir 100 quêtes.",
            symbolName: "100.circle.fill", rarity: .uncommon,
            category: .volume, metric: .tasksCompleted, goal: 100
        ),
        AchievementDefinition(
            id: "vol.500", title: "Infatigable",
            detail: "Accomplir 500 quêtes.",
            symbolName: "bolt.circle.fill", rarity: .rare,
            category: .volume, metric: .tasksCompleted, goal: 500
        ),
        AchievementDefinition(
            id: "vol.1000", title: "Millénaire",
            detail: "Accomplir 1 000 quêtes.",
            symbolName: "star.circle.fill", rarity: .epic,
            category: .volume, metric: .tasksCompleted, goal: 1000
        ),
        AchievementDefinition(
            id: "vol.5000", title: "Force de la nature",
            detail: "Accomplir 5 000 quêtes.",
            symbolName: "tornado", rarity: .legendary,
            category: .volume, metric: .tasksCompleted, goal: 5000
        ),
        AchievementDefinition(
            id: "vol.boss10", title: "Chasseur de boss",
            detail: "Vaincre 10 boss.",
            symbolName: "shield.lefthalf.filled.badge.checkmark", rarity: .rare,
            category: .volume, metric: .bossesDefeated, goal: 10
        ),
        AchievementDefinition(
            id: "vol.boss50", title: "Bourreau des colosses",
            detail: "Vaincre 50 boss.",
            symbolName: "crown.fill", rarity: .legendary,
            category: .volume, metric: .bossesDefeated, goal: 50
        ),
        AchievementDefinition(
            id: "vol.projects10", title: "Bâtisseur",
            detail: "Terminer 10 projets.",
            symbolName: "building.columns.fill", rarity: .rare,
            category: .volume, metric: .projectsCompleted, goal: 10
        ),
        AchievementDefinition(
            id: "vol.ontime100", title: "Montre suisse",
            detail: "100 quêtes livrées dans les temps.",
            symbolName: "clock.badge.checkmark.fill", rarity: .rare,
            category: .volume, metric: .onTimeCompletions, goal: 100
        )
    ]

    // MARK: Régularité

    static let consistency: [AchievementDefinition] = [
        AchievementDefinition(
            id: "streak.3", title: "Ça mord",
            detail: "3 jours d'affilée.",
            symbolName: "flame", rarity: .common,
            category: .consistency, metric: .currentStreak, goal: 3
        ),
        AchievementDefinition(
            id: "streak.7", title: "Semaine parfaite",
            detail: "7 jours d'affilée.",
            symbolName: "flame.fill", rarity: .uncommon,
            category: .consistency, metric: .currentStreak, goal: 7
        ),
        AchievementDefinition(
            id: "streak.30", title: "Un mois sans faillir",
            detail: "30 jours d'affilée.",
            symbolName: "flame.circle.fill", rarity: .rare,
            category: .consistency, metric: .longestStreak, goal: 30
        ),
        AchievementDefinition(
            id: "streak.100", title: "Cent jours de braise",
            detail: "100 jours d'affilée.",
            symbolName: "flame.circle.fill", rarity: .epic,
            category: .consistency, metric: .longestStreak, goal: 100
        ),
        AchievementDefinition(
            id: "streak.365", title: "Une année entière",
            detail: "365 jours d'affilée.",
            symbolName: "sun.max.trianglebadge.exclamationmark.fill", rarity: .mythic,
            category: .consistency, metric: .longestStreak, goal: 365
        ),
        AchievementDefinition(
            id: "perfect.10", title: "Journées sans faille",
            detail: "10 journées où tout le plan a été bouclé.",
            symbolName: "checkmark.seal.fill", rarity: .rare,
            category: .consistency, metric: .perfectDays, goal: 10
        ),
        AchievementDefinition(
            id: "perfect.50", title: "Perfectionniste",
            detail: "50 journées parfaites.",
            symbolName: "seal.fill", rarity: .legendary,
            category: .consistency, metric: .perfectDays, goal: 50
        ),
        AchievementDefinition(
            id: "habit.30", title: "Nouvelle nature",
            detail: "Tenir une habitude 30 jours de suite.",
            symbolName: "repeat.circle.fill", rarity: .epic,
            category: .consistency, metric: .habitChain, goal: 30
        ),
        AchievementDefinition(
            id: "habit.200", title: "Rituel gravé",
            detail: "200 validations d'habitudes.",
            symbolName: "arrow.triangle.2.circlepath", rarity: .rare,
            category: .consistency, metric: .habitsCompleted, goal: 200
        ),
        AchievementDefinition(
            id: "loyal.365", title: "Compagnon de route",
            detail: "Un an d'utilisation de Questly.",
            symbolName: "heart.circle.fill", rarity: .legendary,
            category: .consistency, metric: .loyaltyDays, goal: 365
        )
    ]

    // MARK: Concentration

    static let focus: [AchievementDefinition] = [
        AchievementDefinition(
            id: "focus.60", title: "Une heure au calme",
            detail: "60 minutes de concentration cumulées.",
            symbolName: "hourglass", rarity: .common,
            category: .focus, metric: .focusMinutes, goal: 60
        ),
        AchievementDefinition(
            id: "focus.600", title: "Dix heures d'apnée",
            detail: "600 minutes de concentration.",
            symbolName: "hourglass.bottomhalf.filled", rarity: .uncommon,
            category: .focus, metric: .focusMinutes, goal: 600
        ),
        AchievementDefinition(
            id: "focus.3000", title: "Moine du deep work",
            detail: "50 heures de concentration.",
            symbolName: "brain.head.profile", rarity: .epic,
            category: .focus, metric: .focusMinutes, goal: 3000
        ),
        AchievementDefinition(
            id: "focus.12000", title: "Le flux incarné",
            detail: "200 heures de concentration.",
            symbolName: "infinity.circle.fill", rarity: .mythic,
            category: .focus, metric: .focusMinutes, goal: 12000
        ),
        AchievementDefinition(
            id: "focus.sessions100", title: "Cent plongées",
            detail: "100 sessions de concentration.",
            symbolName: "target", rarity: .rare,
            category: .focus, metric: .focusSessions, goal: 100
        ),
        AchievementDefinition(
            id: "combo.5", title: "Enchaînement",
            detail: "Valider 5 quêtes en moins de 5 minutes.",
            symbolName: "bolt.fill", rarity: .uncommon,
            category: .focus, metric: .maxCombo, goal: 5
        ),
        AchievementDefinition(
            id: "combo.10", title: "Déferlante",
            detail: "Combo ×10.",
            symbolName: "bolt.trianglebadge.exclamationmark.fill", rarity: .epic,
            category: .focus, metric: .maxCombo, goal: 10
        )
    ]

    // MARK: Maîtrise

    static let mastery: [AchievementDefinition] = [
        AchievementDefinition(
            id: "level.10", title: "Aventurier confirmé",
            detail: "Atteindre le niveau 10.",
            symbolName: "figure.walk", rarity: .uncommon,
            category: .mastery, metric: .level, goal: 10
        ),
        AchievementDefinition(
            id: "level.25", title: "Chevalier",
            detail: "Atteindre le niveau 25.",
            symbolName: "shield.fill", rarity: .rare,
            category: .mastery, metric: .level, goal: 25
        ),
        AchievementDefinition(
            id: "level.50", title: "Champion du royaume",
            detail: "Atteindre le niveau 50.",
            symbolName: "trophy.fill", rarity: .epic,
            category: .mastery, metric: .level, goal: 50
        ),
        AchievementDefinition(
            id: "level.100", title: "Légende vivante",
            detail: "Atteindre le niveau 100.",
            symbolName: "sparkles", rarity: .mythic,
            category: .mastery, metric: .level, goal: 100
        ),
        AchievementDefinition(
            id: "xp.100k", title: "Cent mille",
            detail: "Cumuler 100 000 XP.",
            symbolName: "chart.line.uptrend.xyaxis", rarity: .legendary,
            category: .mastery, metric: .totalXP, goal: 100_000
        ),
        AchievementDefinition(
            id: "quests.100", title: "Fidèle au tableau",
            detail: "Terminer 100 quêtes quotidiennes.",
            symbolName: "scroll.fill", rarity: .rare,
            category: .mastery, metric: .questsCompleted, goal: 100
        ),
        AchievementDefinition(
            id: "inbox.30", title: "Boîte au clair",
            detail: "30 journées terminées avec une boîte de réception vide.",
            symbolName: "tray.full.fill", rarity: .epic,
            category: .mastery, metric: .inboxZeroDays, goal: 30
        )
    ]

    // MARK: Équilibre

    static let balance: [AchievementDefinition] = LifeArea.allCases.map { area in
        AchievementDefinition(
            id: "area.\(area.rawValue).50",
            title: "Gardien·ne du domaine \(area.label)",
            detail: "50 quêtes accomplies dans le domaine \(area.label).",
            symbolName: area.symbolName,
            rarity: .rare,
            category: .balance,
            metric: .areaCompletions(area),
            goal: 50
        )
    } + LifeArea.allCases.map { area in
        AchievementDefinition(
            id: "attr.\(area.rawValue).10",
            title: "\(area.label) niveau 10",
            detail: "Porter l'attribut \(area.label) au niveau 10.",
            symbolName: area.symbolName,
            rarity: .epic,
            category: .balance,
            metric: .attributeLevel(area),
            goal: 10
        )
    } + [
        AchievementDefinition(
            id: "balance.all", title: "Vie équilibrée",
            detail: "Au moins 10 quêtes dans chacun des 6 domaines.",
            symbolName: "circle.hexagongrid.fill", rarity: .legendary,
            category: .balance, metric: .balancedAreas, goal: LifeArea.allCases.count
        )
    ]

    // MARK: Collection

    static let collection: [AchievementDefinition] = [
        AchievementDefinition(
            id: "coins.1000", title: "Petite bourse",
            detail: "Gagner 1 000 pièces.",
            symbolName: "dollarsign.circle.fill", rarity: .common,
            category: .collection, metric: .coinsEarned, goal: 1000
        ),
        AchievementDefinition(
            id: "coins.25000", title: "Dragon sur son or",
            detail: "Gagner 25 000 pièces.",
            symbolName: "cube.transparent.fill", rarity: .epic,
            category: .collection, metric: .coinsEarned, goal: 25000
        ),
        AchievementDefinition(
            id: "spend.5000", title: "Dépensier assumé",
            detail: "Dépenser 5 000 pièces à l'échoppe.",
            symbolName: "bag.fill", rarity: .rare,
            category: .collection, metric: .coinsSpent, goal: 5000
        ),
        AchievementDefinition(
            id: "gems.100", title: "Collectionneur de gemmes",
            detail: "Obtenir 100 gemmes.",
            symbolName: "diamond.fill", rarity: .epic,
            category: .collection, metric: .gemsEarned, goal: 100
        ),
        AchievementDefinition(
            id: "notes.50", title: "Chroniqueur",
            detail: "Écrire 50 notes de journal.",
            symbolName: "book.pages.fill", rarity: .uncommon,
            category: .collection, metric: .notesWritten, goal: 50
        ),
        AchievementDefinition(
            id: "blocks.200", title: "Architecte des journées",
            detail: "Planifier 200 blocs de temps.",
            symbolName: "rectangle.3.group.fill", rarity: .rare,
            category: .collection, metric: .calendarBlocks, goal: 200
        )
    ]

    // MARK: Secrets

    static let secrets: [AchievementDefinition] = [
        AchievementDefinition(
            id: "secret.earlybird", title: "L'aube t'appartient",
            detail: "50 quêtes accomplies avant 7 h du matin.",
            symbolName: "sunrise.fill", rarity: .epic,
            category: .secret, metric: .earlyBird, goal: 50, isSecret: true
        ),
        AchievementDefinition(
            id: "secret.nightowl", title: "Créature de la nuit",
            detail: "50 quêtes accomplies après 23 h.",
            symbolName: "moon.stars.fill", rarity: .epic,
            category: .secret, metric: .nightOwl, goal: 50, isSecret: true
        ),
        AchievementDefinition(
            id: "secret.weekend", title: "Week-end productif",
            detail: "100 quêtes accomplies un samedi ou un dimanche.",
            symbolName: "beach.umbrella.fill", rarity: .rare,
            category: .secret, metric: .weekendWarrior, goal: 100, isSecret: true
        ),
        AchievementDefinition(
            id: "secret.marathon", title: "Marathonien",
            detail: "Une session de concentration de 4 heures cumulées dans la journée.",
            symbolName: "figure.run.circle.fill", rarity: .legendary,
            category: .secret, metric: .focusMinutes, goal: 240, isSecret: true
        )
    ]
}
