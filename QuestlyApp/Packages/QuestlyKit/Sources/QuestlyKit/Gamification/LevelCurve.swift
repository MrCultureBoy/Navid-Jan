import Foundation

/// Courbe de progression du héros.
///
/// Le coût d'un niveau suit `100 · n^1.32`, ce qui donne une montée rapide au
/// début (niveau 2 en une journée motivée) puis un palier de plus en plus long,
/// sans jamais devenir décourageant.
public enum LevelCurve {
    public static let minLevel = 1
    public static let maxLevel = 999

    /// XP nécessaire pour passer de `level` à `level + 1`.
    public static func xpToAdvance(from level: Int) -> Int {
        guard level >= minLevel else { return 0 }
        guard level < maxLevel else { return 0 }
        return Int((100.0 * pow(Double(level), 1.32)).rounded())
    }

    /// XP cumulé nécessaire pour atteindre `level`. Le niveau 1 démarre à 0.
    public static func totalXP(toReach level: Int) -> Int {
        let clamped = min(max(level, minLevel), maxLevel)
        return cumulativeTable[clamped - 1]
    }

    /// Niveau correspondant à un total d'XP donné.
    public static func level(forTotalXP xp: Int) -> Int {
        guard xp > 0 else { return minLevel }
        // Recherche dichotomique dans la table cumulée.
        var low = 0
        var high = cumulativeTable.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if cumulativeTable[mid] <= xp { low = mid } else { high = mid - 1 }
        }
        return low + 1
    }

    /// Détail de la progression : utile pour la barre d'XP et l'anneau de niveau.
    public static func progress(forTotalXP xp: Int) -> LevelProgress {
        let level = level(forTotalXP: xp)
        let floorXP = totalXP(toReach: level)
        let needed = xpToAdvance(from: level)
        let into = max(0, xp - floorXP)
        let fraction: Double
        if needed <= 0 {
            fraction = 1
        } else {
            fraction = min(1, max(0, Double(into) / Double(needed)))
        }
        return LevelProgress(
            level: level,
            totalXP: xp,
            xpIntoLevel: into,
            xpRequiredForLevel: needed,
            fraction: fraction,
            rank: Rank.forLevel(level)
        )
    }

    /// Table cumulée pré-calculée : `cumulativeTable[i]` = XP total du niveau `i + 1`.
    private static let cumulativeTable: [Int] = {
        var table = [Int]()
        table.reserveCapacity(maxLevel)
        var running = 0
        for level in minLevel...maxLevel {
            table.append(running)
            running += Int((100.0 * pow(Double(level), 1.32)).rounded())
        }
        return table
    }()
}

// MARK: - Level progress

public struct LevelProgress: Equatable, Sendable {
    public let level: Int
    public let totalXP: Int
    public let xpIntoLevel: Int
    public let xpRequiredForLevel: Int
    public let fraction: Double
    public let rank: Rank

    public init(
        level: Int,
        totalXP: Int,
        xpIntoLevel: Int,
        xpRequiredForLevel: Int,
        fraction: Double,
        rank: Rank
    ) {
        self.level = level
        self.totalXP = totalXP
        self.xpIntoLevel = xpIntoLevel
        self.xpRequiredForLevel = xpRequiredForLevel
        self.fraction = fraction
        self.rank = rank
    }

    public var xpRemaining: Int { max(0, xpRequiredForLevel - xpIntoLevel) }

    public static let zero = LevelProgress(
        level: 1, totalXP: 0, xpIntoLevel: 0,
        xpRequiredForLevel: LevelCurve.xpToAdvance(from: 1),
        fraction: 0, rank: .novice
    )
}

// MARK: - Ranks

/// Titres honorifiques débloqués tous les 5 niveaux.
public enum Rank: Int, CaseIterable, Codable, Sendable, Identifiable, Comparable {
    case novice = 0
    case apprentice
    case squire
    case adventurer
    case knight
    case veteran
    case champion
    case master
    case grandMaster
    case hero
    case legend
    case myth
    case ascendant
    case eternal

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .novice: return "Novice"
        case .apprentice: return "Apprenti·e"
        case .squire: return "Écuyer·ère"
        case .adventurer: return "Aventurier·ère"
        case .knight: return "Chevalier·ère"
        case .veteran: return "Vétéran·e"
        case .champion: return "Champion·ne"
        case .master: return "Maître"
        case .grandMaster: return "Grand Maître"
        case .hero: return "Héros"
        case .legend: return "Légende"
        case .myth: return "Mythe"
        case .ascendant: return "Ascendant·e"
        case .eternal: return "Éternel·le"
        }
    }

    public var symbolName: String {
        switch self {
        case .novice: return "leaf"
        case .apprentice: return "book.closed.fill"
        case .squire: return "shield.fill"
        case .adventurer: return "map.fill"
        case .knight: return "shield.lefthalf.filled.badge.checkmark"
        case .veteran: return "medal.fill"
        case .champion: return "trophy.fill"
        case .master: return "crown.fill"
        case .grandMaster: return "seal.fill"
        case .hero: return "star.circle.fill"
        case .legend: return "flame.fill"
        case .myth: return "sparkles"
        case .ascendant: return "moon.stars.fill"
        case .eternal: return "infinity"
        }
    }

    public var hex: String {
        switch self {
        case .novice: return "9CA3AF"
        case .apprentice: return "7DD3FC"
        case .squire: return "38BDF8"
        case .adventurer: return "34D399"
        case .knight: return "22C55E"
        case .veteran: return "FACC15"
        case .champion: return "FB923C"
        case .master: return "F97316"
        case .grandMaster: return "EF4444"
        case .hero: return "EC4899"
        case .legend: return "A855F7"
        case .myth: return "8B5CF6"
        case .ascendant: return "6366F1"
        case .eternal: return "F5D0FE"
        }
    }

    /// Niveau minimum requis pour ce rang.
    public var minimumLevel: Int { rawValue * 5 + 1 }

    public static func forLevel(_ level: Int) -> Rank {
        let index = max(0, (level - 1) / 5)
        let clamped = min(index, Rank.allCases.count - 1)
        return Rank(rawValue: clamped) ?? .novice
    }

    public static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }
}

// MARK: - Attribute levels

/// Progression d'un attribut (domaine de vie). Courbe plus douce que la
/// progression globale : on veut voir les attributs bouger souvent.
public enum AttributeCurve {
    public static let maxLevel = 100

    public static func xpToAdvance(from level: Int) -> Int {
        guard level >= 1, level < maxLevel else { return 0 }
        return 60 + (level - 1) * 40
    }

    public static func totalXP(toReach level: Int) -> Int {
        let clamped = min(max(level, 1), maxLevel)
        var total = 0
        for l in 1..<clamped { total += xpToAdvance(from: l) }
        return total
    }

    public static func level(forTotalXP xp: Int) -> Int {
        var level = 1
        var remaining = xp
        while level < maxLevel {
            let cost = xpToAdvance(from: level)
            if remaining < cost { break }
            remaining -= cost
            level += 1
        }
        return level
    }

    public static func progress(forTotalXP xp: Int) -> (level: Int, into: Int, required: Int, fraction: Double) {
        let level = level(forTotalXP: xp)
        let floorXP = totalXP(toReach: level)
        let required = xpToAdvance(from: level)
        let into = max(0, xp - floorXP)
        let fraction = required > 0 ? min(1, Double(into) / Double(required)) : 1
        return (level, into, required, fraction)
    }
}
