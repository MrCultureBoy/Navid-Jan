import Foundation

// MARK: - Quest model

public enum QuestKind: String, Codable, CaseIterable, Sendable {
    case completeTasks
    case completeHighPriority
    case focusMinutes
    case completeInArea
    case completeBeforeNoon
    case clearOverdue
    case defeatBoss
    case completeHabit
    case scheduleBlocks
    case planTomorrow
    case completeDifficult
    case noSnooze
    case writeNote
    case comboChain

    public var symbolName: String {
        switch self {
        case .completeTasks: return "checkmark.circle.fill"
        case .completeHighPriority: return "flame.fill"
        case .focusMinutes: return "timer"
        case .completeInArea: return "circle.hexagongrid.fill"
        case .completeBeforeNoon: return "sunrise.fill"
        case .clearOverdue: return "exclamationmark.triangle.fill"
        case .defeatBoss: return "crown.fill"
        case .completeHabit: return "repeat.circle.fill"
        case .scheduleBlocks: return "calendar.badge.plus"
        case .planTomorrow: return "moon.stars.fill"
        case .completeDifficult: return "bolt.shield.fill"
        case .noSnooze: return "hand.raised.fill"
        case .writeNote: return "square.and.pencil"
        case .comboChain: return "bolt.fill"
        }
    }
}

public enum QuestPeriod: String, Codable, CaseIterable, Sendable {
    case daily
    case weekly

    public var label: String {
        switch self {
        case .daily: return "Quêtes du jour"
        case .weekly: return "Défi de la semaine"
        }
    }
}

public struct QuestTemplate: Sendable, Equatable {
    public let kind: QuestKind
    public let title: String
    public let detail: String
    public let baseTarget: Int
    public let rarity: Rarity
    /// Le domaine concerné, pour les quêtes ciblées.
    public let lifeArea: LifeArea?

    public init(
        kind: QuestKind,
        title: String,
        detail: String,
        baseTarget: Int,
        rarity: Rarity = .common,
        lifeArea: LifeArea? = nil
    ) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.baseTarget = baseTarget
        self.rarity = rarity
        self.lifeArea = lifeArea
    }
}

public struct GeneratedQuest: Identifiable, Sendable, Equatable {
    public let id: String
    public let kind: QuestKind
    public let period: QuestPeriod
    public let title: String
    public let detail: String
    public let target: Int
    public let rarity: Rarity
    public let lifeArea: LifeArea?
    public let xpReward: Int
    public let coinReward: Int
    public let gemReward: Int
    public let symbolName: String

    public init(
        id: String,
        kind: QuestKind,
        period: QuestPeriod,
        title: String,
        detail: String,
        target: Int,
        rarity: Rarity,
        lifeArea: LifeArea?,
        xpReward: Int,
        coinReward: Int,
        gemReward: Int,
        symbolName: String
    ) {
        self.id = id
        self.kind = kind
        self.period = period
        self.title = title
        self.detail = detail
        self.target = target
        self.rarity = rarity
        self.lifeArea = lifeArea
        self.xpReward = xpReward
        self.coinReward = coinReward
        self.gemReward = gemReward
        self.symbolName = symbolName
    }

    public func progressFraction(_ value: Int) -> Double {
        guard target > 0 else { return 1 }
        return min(1, Double(value) / Double(target))
    }
}

// MARK: - Generator

/// Génère le tableau de quêtes. Déterministe : le même jour et le même niveau
/// produisent toujours les mêmes quêtes, ce qui évite qu'un rafraîchissement
/// de vue rebatte les cartes.
public enum QuestGenerator {

    public static let dailyTemplates: [QuestTemplate] = [
        QuestTemplate(kind: .completeTasks, title: "Trois pour commencer",
                      detail: "Accomplir %d quêtes aujourd'hui.", baseTarget: 3),
        QuestTemplate(kind: .completeTasks, title: "Journée productive",
                      detail: "Accomplir %d quêtes aujourd'hui.", baseTarget: 5, rarity: .uncommon),
        QuestTemplate(kind: .completeHighPriority, title: "Droit au but",
                      detail: "Boucler %d quête(s) de priorité P1 ou P2.", baseTarget: 1, rarity: .uncommon),
        QuestTemplate(kind: .focusMinutes, title: "Plongée profonde",
                      detail: "Cumuler %d minutes de concentration.", baseTarget: 25),
        QuestTemplate(kind: .focusMinutes, title: "Session longue",
                      detail: "Cumuler %d minutes de concentration.", baseTarget: 50, rarity: .rare),
        QuestTemplate(kind: .completeBeforeNoon, title: "Lève-tôt",
                      detail: "Accomplir %d quête(s) avant midi.", baseTarget: 2, rarity: .uncommon),
        QuestTemplate(kind: .clearOverdue, title: "Nettoyage de printemps",
                      detail: "Traiter %d quête(s) en retard.", baseTarget: 1, rarity: .uncommon),
        QuestTemplate(kind: .defeatBoss, title: "Face au colosse",
                      detail: "Vaincre %d boss.", baseTarget: 1, rarity: .rare),
        QuestTemplate(kind: .completeHabit, title: "Rituel du jour",
                      detail: "Valider %d habitude(s).", baseTarget: 2),
        QuestTemplate(kind: .scheduleBlocks, title: "Journée orchestrée",
                      detail: "Placer %d bloc(s) dans le calendrier.", baseTarget: 2),
        QuestTemplate(kind: .planTomorrow, title: "Un pas d'avance",
                      detail: "Planifier %d quête(s) pour demain.", baseTarget: 3),
        QuestTemplate(kind: .completeDifficult, title: "Sortir de sa zone",
                      detail: "Accomplir %d quête(s) ardue(s) ou plus.", baseTarget: 1, rarity: .rare),
        QuestTemplate(kind: .writeNote, title: "Tenir la chronique",
                      detail: "Écrire %d note de journal.", baseTarget: 1),
        QuestTemplate(kind: .comboChain, title: "Enchaînement",
                      detail: "Atteindre un combo de %d.", baseTarget: 3, rarity: .rare)
    ]

    public static let weeklyTemplates: [QuestTemplate] = [
        QuestTemplate(kind: .completeTasks, title: "Semaine chargée",
                      detail: "Accomplir %d quêtes cette semaine.", baseTarget: 25, rarity: .rare),
        QuestTemplate(kind: .focusMinutes, title: "Cinq heures de flux",
                      detail: "Cumuler %d minutes de concentration.", baseTarget: 300, rarity: .epic),
        QuestTemplate(kind: .defeatBoss, title: "Chasse hebdomadaire",
                      detail: "Vaincre %d boss.", baseTarget: 3, rarity: .epic),
        QuestTemplate(kind: .completeHighPriority, title: "L'essentiel d'abord",
                      detail: "Boucler %d quêtes prioritaires.", baseTarget: 7, rarity: .rare),
        QuestTemplate(kind: .completeHabit, title: "Constance",
                      detail: "Valider %d habitudes.", baseTarget: 12, rarity: .rare)
    ]

    /// Trois quêtes quotidiennes + un défi hebdomadaire.
    public static func generate(
        for date: Date,
        playerLevel: Int,
        preferredAreas: [LifeArea] = [],
        calendar: Calendar = .questly()
    ) -> [GeneratedQuest] {
        var quests = daily(for: date, playerLevel: playerLevel, preferredAreas: preferredAreas, calendar: calendar)
        quests.append(weekly(for: date, playerLevel: playerLevel, calendar: calendar))
        return quests
    }

    public static func daily(
        for date: Date,
        playerLevel: Int,
        preferredAreas: [LifeArea] = [],
        count: Int = 3,
        calendar: Calendar = .questly()
    ) -> [GeneratedQuest] {
        let daySeed = seed(for: calendar.startOfDay(for: date), salt: 0x5175_6573)
        var rng = SeededRandom(seed: daySeed)
        var pool = dailyTemplates
        var chosen: [QuestTemplate] = []

        // Une quête ciblée sur un domaine délaissé, si l'app en connaît.
        if let area = preferredAreas.first {
            chosen.append(QuestTemplate(
                kind: .completeInArea,
                title: "Cap sur \(area.label)",
                detail: "Accomplir %d quête(s) du domaine \(area.label).",
                baseTarget: 2,
                rarity: .uncommon,
                lifeArea: area
            ))
        }

        while chosen.count < count && !pool.isEmpty {
            let index = Int(rng.next(upperBound: UInt64(pool.count)))
            let template = pool.remove(at: index)
            if chosen.contains(where: { $0.kind == template.kind }) { continue }
            chosen.append(template)
        }

        let dayKey = Self.dayKey(date, calendar: calendar)
        return chosen.enumerated().map { offset, template in
            build(template: template, period: .daily, playerLevel: playerLevel, idSuffix: "\(dayKey).\(offset)")
        }
    }

    public static func weekly(
        for date: Date,
        playerLevel: Int,
        calendar: Calendar = .questly()
    ) -> GeneratedQuest {
        let weekStart = calendar.startOfWeek(date)
        var rng = SeededRandom(seed: seed(for: weekStart, salt: 0x5765_656B))
        let index = Int(rng.next(upperBound: UInt64(weeklyTemplates.count)))
        let template = weeklyTemplates[index]
        let key = Self.dayKey(weekStart, calendar: calendar)
        return build(template: template, period: .weekly, playerLevel: playerLevel, idSuffix: "w.\(key)")
    }

    // MARK: Helpers

    static func build(
        template: QuestTemplate,
        period: QuestPeriod,
        playerLevel: Int,
        idSuffix: String
    ) -> GeneratedQuest {
        // La cible croît doucement avec le niveau, plafonnée pour rester tenable.
        let scale = 1.0 + min(Double(playerLevel - 1) * 0.03, 1.0)
        let target = max(1, Int((Double(template.baseTarget) * scale).rounded()))

        let rarityBoost = Double(template.rarity.rawValue + 1)
        let periodBoost = period == .weekly ? 4.0 : 1.0
        let xp = Int((40.0 * rarityBoost * periodBoost).rounded())
        let coins = Int((15.0 * rarityBoost * periodBoost).rounded())
        let gems = period == .weekly ? max(1, template.rarity.rawValue) : (template.rarity >= .rare ? 1 : 0)

        return GeneratedQuest(
            id: "\(template.kind.rawValue).\(idSuffix)",
            kind: template.kind,
            period: period,
            title: template.title,
            detail: String(format: template.detail, target),
            target: target,
            rarity: template.rarity,
            lifeArea: template.lifeArea,
            xpReward: xp,
            coinReward: coins,
            gemReward: gems,
            symbolName: template.kind.symbolName
        )
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func seed(for date: Date, salt: UInt64) -> UInt64 {
        let days = UInt64(bitPattern: Int64(date.timeIntervalSince1970 / 86400))
        return days &* 0x9E37_79B9_7F4A_7C15 &+ salt
    }
}

// MARK: - Deterministic RNG

/// Générateur SplitMix64 : reproductible, rapide, sans dépendance système.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public mutating func next(upperBound: UInt64) -> UInt64 {
        guard upperBound > 0 else { return 0 }
        return next() % upperBound
    }

    public mutating func nextDouble() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}
