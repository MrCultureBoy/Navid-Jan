import Foundation

// MARK: - Priority

/// Priorité d'une quête, façon Todoist : `p1` est la plus urgente.
public enum Priority: Int, Codable, CaseIterable, Sendable, Identifiable {
    case p1 = 1
    case p2 = 2
    case p3 = 3
    case p4 = 4

    public var id: Int { rawValue }

    /// Priorité par défaut d'une nouvelle tâche.
    public static let `default`: Priority = .p4

    /// Plus le score est haut, plus la tâche est urgente. Pratique pour trier.
    public var urgencyScore: Int { 5 - rawValue }

    public var label: String {
        switch self {
        case .p1: return "Critique"
        case .p2: return "Élevée"
        case .p3: return "Moyenne"
        case .p4: return "Normale"
        }
    }

    public var shortLabel: String { "P\(rawValue)" }

    public var symbolName: String {
        switch self {
        case .p1: return "flame.fill"
        case .p2: return "exclamationmark.2"
        case .p3: return "exclamationmark"
        case .p4: return "circle"
        }
    }

    /// Teinte hexadécimale associée (le layer UI la convertit en `Color`).
    public var hex: String {
        switch self {
        case .p1: return "FF453A"
        case .p2: return "FF9F0A"
        case .p3: return "0A84FF"
        case .p4: return "8E8E93"
        }
    }

    /// Multiplicateur d'XP : viser les tâches critiques rapporte plus.
    public var xpMultiplier: Double {
        switch self {
        case .p1: return 1.50
        case .p2: return 1.25
        case .p3: return 1.10
        case .p4: return 1.00
        }
    }
}

extension Priority: Comparable {
    /// `p4 < p1` : l'ordre naturel va du moins urgent au plus urgent.
    public static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.urgencyScore < rhs.urgencyScore
    }
}

// MARK: - Difficulty

/// Difficulté estimée : c'est le principal levier de récompense.
public enum Difficulty: Int, Codable, CaseIterable, Sendable, Identifiable {
    case trivial = 0
    case easy = 1
    case medium = 2
    case hard = 3
    case epic = 4
    case legendary = 5

    public var id: Int { rawValue }

    public static let `default`: Difficulty = .medium

    public var label: String {
        switch self {
        case .trivial: return "Broutille"
        case .easy: return "Facile"
        case .medium: return "Normale"
        case .hard: return "Ardue"
        case .epic: return "Épique"
        case .legendary: return "Légendaire"
        }
    }

    /// XP de base rapporté par la tâche avant tout bonus.
    public var baseXP: Int {
        switch self {
        case .trivial: return 5
        case .easy: return 10
        case .medium: return 20
        case .hard: return 35
        case .epic: return 60
        case .legendary: return 100
        }
    }

    /// Points de vie du « boss » associé, en minutes de concentration.
    public var bossHitPoints: Int {
        switch self {
        case .trivial: return 10
        case .easy: return 25
        case .medium: return 50
        case .hard: return 90
        case .epic: return 150
        case .legendary: return 240
        }
    }

    public var symbolName: String {
        switch self {
        case .trivial: return "leaf.fill"
        case .easy: return "circle.hexagongrid.fill"
        case .medium: return "shield.lefthalf.filled"
        case .hard: return "bolt.shield.fill"
        case .epic: return "crown.fill"
        case .legendary: return "sparkles"
        }
    }

    public var hex: String {
        switch self {
        case .trivial: return "9CA3AF"
        case .easy: return "34D399"
        case .medium: return "60A5FA"
        case .hard: return "F59E0B"
        case .epic: return "A78BFA"
        case .legendary: return "F472B6"
        }
    }
}

// MARK: - Energy

/// Énergie requise. Sert au planificateur intelligent pour placer les tâches
/// exigeantes dans les créneaux où l'utilisateur est au top.
public enum EnergyLevel: Int, Codable, CaseIterable, Sendable, Identifiable {
    case low = 0
    case medium = 1
    case high = 2

    public var id: Int { rawValue }

    public static let `default`: EnergyLevel = .medium

    public var label: String {
        switch self {
        case .low: return "Basse"
        case .medium: return "Moyenne"
        case .high: return "Haute"
        }
    }

    public var symbolName: String {
        switch self {
        case .low: return "battery.25"
        case .medium: return "battery.50"
        case .high: return "battery.100.bolt"
        }
    }
}

// MARK: - Life areas (les « attributs » du héros)

/// Domaines de vie : ce sont les statistiques du personnage. Chaque tâche
/// terminée fait progresser l'attribut correspondant.
public enum LifeArea: String, Codable, CaseIterable, Sendable, Identifiable {
    case body
    case mind
    case heart
    case craft
    case wealth
    case home

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .body: return "Corps"
        case .mind: return "Esprit"
        case .heart: return "Cœur"
        case .craft: return "Œuvre"
        case .wealth: return "Fortune"
        case .home: return "Foyer"
        }
    }

    public var subtitle: String {
        switch self {
        case .body: return "Sport, sommeil, santé"
        case .mind: return "Lecture, études, focus"
        case .heart: return "Proches, liens, soi"
        case .craft: return "Travail, création, projets"
        case .wealth: return "Argent, admin, avenir"
        case .home: return "Maison, courses, ordre"
        }
    }

    public var symbolName: String {
        switch self {
        case .body: return "figure.run"
        case .mind: return "brain.head.profile"
        case .heart: return "heart.fill"
        case .craft: return "hammer.fill"
        case .wealth: return "banknote.fill"
        case .home: return "house.fill"
        }
    }

    public var hex: String {
        switch self {
        case .body: return "FF6B6B"
        case .mind: return "5E9BFF"
        case .heart: return "FF7AC6"
        case .craft: return "FFB020"
        case .wealth: return "34D399"
        case .home: return "A78BFA"
        }
    }
}

// MARK: - Rarity

/// Rareté d'un butin, d'un haut fait ou d'un objet de la boutique.
public enum Rarity: Int, Codable, CaseIterable, Sendable, Identifiable, Comparable {
    case common = 0
    case uncommon = 1
    case rare = 2
    case epic = 3
    case legendary = 4
    case mythic = 5

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .common: return "Commun"
        case .uncommon: return "Peu commun"
        case .rare: return "Rare"
        case .epic: return "Épique"
        case .legendary: return "Légendaire"
        case .mythic: return "Mythique"
        }
    }

    public var hex: String {
        switch self {
        case .common: return "9CA3AF"
        case .uncommon: return "34D399"
        case .rare: return "3B82F6"
        case .epic: return "A855F7"
        case .legendary: return "F59E0B"
        case .mythic: return "FF2D95"
        }
    }

    /// Poids du tirage au sort d'un coffre standard.
    public var lootWeight: Double {
        switch self {
        case .common: return 52
        case .uncommon: return 26
        case .rare: return 13
        case .epic: return 6
        case .legendary: return 2.5
        case .mythic: return 0.5
        }
    }

    public static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.rawValue < rhs.rawValue }
}

// MARK: - Task status

public enum TaskStatus: Int, Codable, CaseIterable, Sendable {
    case inbox = 0
    case active = 1
    case completed = 2
    case archived = 3
    case abandoned = 4

    public var isOpen: Bool { self == .inbox || self == .active }
}

// MARK: - Smart lists

/// Listes intelligentes proposées dans l'onglet Quêtes.
public enum SmartList: String, Codable, CaseIterable, Sendable, Identifiable {
    case inbox
    case today
    case upcoming
    case overdue
    case anytime
    case someday
    case flagged
    case bosses
    case completed

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .inbox: return "Boîte de réception"
        case .today: return "Aujourd'hui"
        case .upcoming: return "À venir"
        case .overdue: return "En retard"
        case .anytime: return "N'importe quand"
        case .someday: return "Un jour"
        case .flagged: return "Épinglées"
        case .bosses: return "Boss"
        case .completed: return "Accomplies"
        }
    }

    public var symbolName: String {
        switch self {
        case .inbox: return "tray.fill"
        case .today: return "sun.max.fill"
        case .upcoming: return "calendar"
        case .overdue: return "exclamationmark.triangle.fill"
        case .anytime: return "shuffle"
        case .someday: return "archivebox.fill"
        case .flagged: return "flag.fill"
        case .bosses: return "crown.fill"
        case .completed: return "checkmark.seal.fill"
        }
    }

    public var hex: String {
        switch self {
        case .inbox: return "8E8E93"
        case .today: return "FF9F0A"
        case .upcoming: return "5E5CE6"
        case .overdue: return "FF453A"
        case .anytime: return "30D158"
        case .someday: return "64D2FF"
        case .flagged: return "FFD60A"
        case .bosses: return "BF5AF2"
        case .completed: return "34D399"
        }
    }
}

// MARK: - Sorting

public enum TaskSortOrder: String, Codable, CaseIterable, Sendable, Identifiable {
    case smart
    case dueDate
    case priority
    case difficulty
    case alphabetical
    case created
    case xpValue

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .smart: return "Intelligent"
        case .dueDate: return "Échéance"
        case .priority: return "Priorité"
        case .difficulty: return "Difficulté"
        case .alphabetical: return "Alphabétique"
        case .created: return "Création"
        case .xpValue: return "XP"
        }
    }
}

public enum TaskGrouping: String, Codable, CaseIterable, Sendable, Identifiable {
    case none
    case date
    case priority
    case project
    case lifeArea
    case difficulty

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .none: return "Aucun"
        case .date: return "Date"
        case .priority: return "Priorité"
        case .project: return "Projet"
        case .lifeArea: return "Domaine"
        case .difficulty: return "Difficulté"
        }
    }
}
