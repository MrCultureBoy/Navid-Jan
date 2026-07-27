import Foundation

/// Emplacements personnalisables du héros. L'avatar est composé de symboles
/// système et d'emojis : zéro asset externe, rendu net à toutes les tailles.
public enum AvatarSlot: String, CaseIterable, Codable, Sendable, Identifiable {
    case face
    case headgear
    case companion
    case aura
    case frame

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .face: return "Visage"
        case .headgear: return "Couvre-chef"
        case .companion: return "Familier"
        case .aura: return "Aura"
        case .frame: return "Cadre"
        }
    }

    public var symbolName: String {
        switch self {
        case .face: return "face.smiling"
        case .headgear: return "crown"
        case .companion: return "pawprint.fill"
        case .aura: return "sparkles"
        case .frame: return "circle.dashed"
        }
    }
}

public struct AvatarPart: Identifiable, Sendable, Equatable, Hashable {
    public let id: String
    public let name: String
    public let slot: AvatarSlot
    /// Emoji affiché pour les visages et familiers.
    public let emoji: String?
    /// Symbole SF utilisé pour les auras, cadres et couvre-chefs.
    public let symbolName: String
    public let rarity: Rarity
    public let requiredLevel: Int
    public let price: Price

    public init(
        id: String,
        name: String,
        slot: AvatarSlot,
        emoji: String? = nil,
        symbolName: String,
        rarity: Rarity = .common,
        requiredLevel: Int = 1,
        price: Price = .free
    ) {
        self.id = id
        self.name = name
        self.slot = slot
        self.emoji = emoji
        self.symbolName = symbolName
        self.rarity = rarity
        self.requiredLevel = requiredLevel
        self.price = price
    }

    public var isFree: Bool { price.isFree && requiredLevel <= 1 }
}

public enum AvatarCatalog {

    public static let parts: [AvatarPart] = faces + headgear + companions + auras + frames

    public static var purchasableParts: [AvatarPart] {
        parts.filter { !$0.price.isFree }
    }

    public static func part(id: String) -> AvatarPart? {
        parts.first { $0.id == id }
    }

    public static func parts(in slot: AvatarSlot) -> [AvatarPart] {
        parts.filter { $0.slot == slot }
    }

    /// Pièces débloquées gratuitement à un niveau donné.
    public static func unlocked(atLevel level: Int) -> [AvatarPart] {
        parts.filter { $0.price.isFree && $0.requiredLevel <= level }
    }

    public static let defaultLoadout: [AvatarSlot: String] = [
        .face: "face.explorer",
        .frame: "frame.simple"
    ]

    // MARK: Visages

    static let faces: [AvatarPart] = [
        AvatarPart(id: "face.explorer", name: "Exploratrice", slot: .face, emoji: "🧭", symbolName: "face.smiling"),
        AvatarPart(id: "face.scholar", name: "Érudit", slot: .face, emoji: "🦉", symbolName: "book.closed.fill"),
        AvatarPart(id: "face.fox", name: "Renard", slot: .face, emoji: "🦊", symbolName: "pawprint.fill", rarity: .uncommon, requiredLevel: 3),
        AvatarPart(id: "face.dragon", name: "Dragonnet", slot: .face, emoji: "🐉", symbolName: "flame.fill", rarity: .rare, requiredLevel: 12, price: Price(coins: 1200)),
        AvatarPart(id: "face.robot", name: "Automate", slot: .face, emoji: "🤖", symbolName: "cpu.fill", rarity: .uncommon, requiredLevel: 6, price: Price(coins: 500)),
        AvatarPart(id: "face.ghost", name: "Spectre", slot: .face, emoji: "👻", symbolName: "moon.fill", rarity: .rare, requiredLevel: 15, price: Price(coins: 1400)),
        AvatarPart(id: "face.alien", name: "Voyageur", slot: .face, emoji: "👾", symbolName: "sparkle", rarity: .epic, requiredLevel: 22, price: Price(coins: 2600, gems: 4)),
        AvatarPart(id: "face.phoenix", name: "Phénix", slot: .face, emoji: "🔥", symbolName: "flame.circle.fill", rarity: .legendary, requiredLevel: 35, price: Price(coins: 5000, gems: 15))
    ]

    // MARK: Couvre-chefs

    static let headgear: [AvatarPart] = [
        AvatarPart(id: "hat.none", name: "Tête nue", slot: .headgear, symbolName: "nosign"),
        AvatarPart(id: "hat.band", name: "Bandeau", slot: .headgear, symbolName: "bandage.fill", requiredLevel: 2),
        AvatarPart(id: "hat.helmet", name: "Heaume", slot: .headgear, symbolName: "shield.fill", rarity: .uncommon, requiredLevel: 7, price: Price(coins: 600)),
        AvatarPart(id: "hat.wizard", name: "Chapeau de mage", slot: .headgear, symbolName: "wand.and.stars", rarity: .rare, requiredLevel: 13, price: Price(coins: 1300)),
        AvatarPart(id: "hat.crown", name: "Couronne", slot: .headgear, symbolName: "crown.fill", rarity: .epic, requiredLevel: 25, price: Price(coins: 3000, gems: 6)),
        AvatarPart(id: "hat.halo", name: "Auréole", slot: .headgear, symbolName: "circle.circle.fill", rarity: .legendary, requiredLevel: 45, price: Price(coins: 7000, gems: 20))
    ]

    // MARK: Familiers

    static let companions: [AvatarPart] = [
        AvatarPart(id: "pet.none", name: "Solitaire", slot: .companion, symbolName: "nosign"),
        AvatarPart(id: "pet.cat", name: "Chat", slot: .companion, emoji: "🐈", symbolName: "pawprint.fill", rarity: .uncommon, requiredLevel: 4, price: Price(coins: 450)),
        AvatarPart(id: "pet.owl", name: "Chouette", slot: .companion, emoji: "🦉", symbolName: "bird.fill", rarity: .uncommon, requiredLevel: 9, price: Price(coins: 700)),
        AvatarPart(id: "pet.slime", name: "Gluant", slot: .companion, emoji: "🟢", symbolName: "drop.fill", rarity: .rare, requiredLevel: 16, price: Price(coins: 1500)),
        AvatarPart(id: "pet.wolf", name: "Loup", slot: .companion, emoji: "🐺", symbolName: "pawprint.circle.fill", rarity: .epic, requiredLevel: 28, price: Price(coins: 3200, gems: 8)),
        AvatarPart(id: "pet.dragon", name: "Petit dragon", slot: .companion, emoji: "🐲", symbolName: "flame.fill", rarity: .mythic, requiredLevel: 60, price: Price(coins: 12000, gems: 60))
    ]

    // MARK: Auras

    static let auras: [AvatarPart] = [
        AvatarPart(id: "aura.none", name: "Aucune", slot: .aura, symbolName: "nosign"),
        AvatarPart(id: "aura.spark", name: "Étincelles", slot: .aura, symbolName: "sparkles", rarity: .uncommon, requiredLevel: 5),
        AvatarPart(id: "aura.flame", name: "Braises", slot: .aura, symbolName: "flame.fill", rarity: .rare, requiredLevel: 18, price: Price(coins: 1600)),
        AvatarPart(id: "aura.frost", name: "Givre", slot: .aura, symbolName: "snowflake", rarity: .rare, requiredLevel: 20, price: Price(coins: 1600)),
        AvatarPart(id: "aura.storm", name: "Orage", slot: .aura, symbolName: "bolt.fill", rarity: .epic, requiredLevel: 30, price: Price(coins: 3400, gems: 8)),
        AvatarPart(id: "aura.cosmos", name: "Cosmos", slot: .aura, symbolName: "moon.stars.fill", rarity: .legendary, requiredLevel: 50, price: Price(coins: 8000, gems: 25))
    ]

    // MARK: Cadres

    static let frames: [AvatarPart] = [
        AvatarPart(id: "frame.simple", name: "Cercle simple", slot: .frame, symbolName: "circle"),
        AvatarPart(id: "frame.dashed", name: "Pointillés", slot: .frame, symbolName: "circle.dashed", requiredLevel: 3),
        AvatarPart(id: "frame.hex", name: "Hexagone", slot: .frame, symbolName: "hexagon", rarity: .uncommon, requiredLevel: 11, price: Price(coins: 800)),
        AvatarPart(id: "frame.laurel", name: "Laurier", slot: .frame, symbolName: "laurel.leading", rarity: .rare, requiredLevel: 21, price: Price(coins: 1800)),
        AvatarPart(id: "frame.seal", name: "Sceau", slot: .frame, symbolName: "seal", rarity: .epic, requiredLevel: 33, price: Price(coins: 3600, gems: 9)),
        AvatarPart(id: "frame.infinity", name: "Infini", slot: .frame, symbolName: "infinity", rarity: .mythic, requiredLevel: 70, price: Price(coins: 15000, gems: 80))
    ]
}
