import Foundation

/// Un fragment reconnu dans la saisie, avec sa position : l'UI s'en sert pour
/// surligner en direct ce qui a été compris.
public struct ParsedToken: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable {
        case date
        case time
        case duration
        case priority
        case tag
        case project
        case recurrence
        case reminder
        case difficulty
        case area
        case boss
    }

    public let id: String
    public let kind: Kind
    /// Texte exact repéré dans la saisie.
    public let text: String
    /// Ce que l'app en a compris, prêt à afficher (« demain 14:00 »).
    public let display: String
    public let location: Int
    public let length: Int

    public init(kind: Kind, text: String, display: String, location: Int, length: Int) {
        self.id = "\(kind.rawValue).\(location).\(length)"
        self.kind = kind
        self.text = text
        self.display = display
        self.location = location
        self.length = length
    }

    public var symbolName: String {
        switch kind {
        case .date: return "calendar"
        case .time: return "clock"
        case .duration: return "hourglass"
        case .priority: return "flag.fill"
        case .tag: return "number"
        case .project: return "folder.fill"
        case .recurrence: return "repeat"
        case .reminder: return "bell.fill"
        case .difficulty: return "bolt.shield.fill"
        case .area: return "circle.hexagongrid.fill"
        case .boss: return "crown.fill"
        }
    }

    public var hex: String {
        switch kind {
        case .date, .time: return "5E9BFF"
        case .duration: return "64D2FF"
        case .priority: return "FF9F0A"
        case .tag: return "BF5AF2"
        case .project: return "30D158"
        case .recurrence: return "5E5CE6"
        case .reminder: return "FF375F"
        case .difficulty: return "FFD60A"
        case .area: return "FF7AC6"
        case .boss: return "F472B6"
        }
    }
}

/// Résultat complet de l'analyse d'une saisie rapide.
public struct ParsedInput: Equatable, Sendable {
    public var title: String
    public var dueDate: Date?
    /// `false` = échéance « toute la journée ».
    public var hasTime: Bool
    public var durationMinutes: Int?
    public var priority: Priority?
    public var difficulty: Difficulty?
    public var lifeArea: LifeArea?
    public var tags: [String]
    public var project: String?
    public var recurrence: RecurrenceRule?
    public var reminderMinutesBefore: Int?
    public var isBoss: Bool
    public var tokens: [ParsedToken]

    public init(
        title: String = "",
        dueDate: Date? = nil,
        hasTime: Bool = false,
        durationMinutes: Int? = nil,
        priority: Priority? = nil,
        difficulty: Difficulty? = nil,
        lifeArea: LifeArea? = nil,
        tags: [String] = [],
        project: String? = nil,
        recurrence: RecurrenceRule? = nil,
        reminderMinutesBefore: Int? = nil,
        isBoss: Bool = false,
        tokens: [ParsedToken] = []
    ) {
        self.title = title
        self.dueDate = dueDate
        self.hasTime = hasTime
        self.durationMinutes = durationMinutes
        self.priority = priority
        self.difficulty = difficulty
        self.lifeArea = lifeArea
        self.tags = tags
        self.project = project
        self.recurrence = recurrence
        self.reminderMinutesBefore = reminderMinutesBefore
        self.isBoss = isBoss
        self.tokens = tokens
    }

    public var isEmpty: Bool { title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// A-t-on compris autre chose que du texte brut ?
    public var hasMetadata: Bool { !tokens.isEmpty }
}
