import Foundation

// MARK: - Currencies

public struct Wallet: Sendable, Equatable, Codable {
    public var coins: Int
    public var gems: Int

    public init(coins: Int = 0, gems: Int = 0) {
        self.coins = coins
        self.gems = gems
    }

    public func canAfford(_ price: Price) -> Bool {
        coins >= price.coins && gems >= price.gems
    }

    public mutating func spend(_ price: Price) -> Bool {
        guard canAfford(price) else { return false }
        coins -= price.coins
        gems -= price.gems
        return true
    }

    public mutating func earn(coins: Int = 0, gems: Int = 0) {
        self.coins += max(0, coins)
        self.gems += max(0, gems)
    }
}

public struct Price: Sendable, Equatable, Hashable, Codable {
    public var coins: Int
    public var gems: Int

    public init(coins: Int = 0, gems: Int = 0) {
        self.coins = coins
        self.gems = gems
    }

    public static let free = Price()
    public var isFree: Bool { coins == 0 && gems == 0 }
}

// MARK: - Shop

public enum ShopCategory: String, CaseIterable, Sendable, Identifiable {
    case consumable
    case theme
    case avatar
    case chest
    case utility

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .consumable: return "Potions"
        case .theme: return "Ambiances"
        case .avatar: return "Apparence"
        case .chest: return "Coffres"
        case .utility: return "Confort"
        }
    }

    public var symbolName: String {
        switch self {
        case .consumable: return "flask.fill"
        case .theme: return "paintpalette.fill"
        case .avatar: return "person.crop.circle.fill"
        case .chest: return "shippingbox.fill"
        case .utility: return "gearshape.fill"
        }
    }
}

public enum ShopEffect: Sendable, Equatable, Codable, Hashable {
    case xpBoost(multiplier: Double, hours: Int)
    case streakFreeze(count: Int)
    case restDayToken(count: Int)
    case unlockTheme(id: String)
    case unlockAvatarPart(id: String)
    case openChest(tier: Int)
    case coinPouch(amount: Int)
}

public struct ShopItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let detail: String
    public let symbolName: String
    public let rarity: Rarity
    public let category: ShopCategory
    public let price: Price
    public let effect: ShopEffect
    /// Niveau minimum requis pour voir l'objet en boutique.
    public let requiredLevel: Int
    /// Un objet consommable peut être racheté indéfiniment.
    public let isConsumable: Bool

    public init(
        id: String,
        name: String,
        detail: String,
        symbolName: String,
        rarity: Rarity,
        category: ShopCategory,
        price: Price,
        effect: ShopEffect,
        requiredLevel: Int = 1,
        isConsumable: Bool = false
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.symbolName = symbolName
        self.rarity = rarity
        self.category = category
        self.price = price
        self.effect = effect
        self.requiredLevel = requiredLevel
        self.isConsumable = isConsumable
    }
}

public enum ShopCatalog {

    public static let all: [ShopItem] = consumables + themes + avatarItems + chests + utilities

    public static func item(id: String) -> ShopItem? {
        all.first { $0.id == id }
    }

    public static func available(forLevel level: Int) -> [ShopItem] {
        all.filter { $0.requiredLevel <= level }
    }

    static let consumables: [ShopItem] = [
        ShopItem(id: "potion.xp.small", name: "Fiole d'expérience",
                 detail: "×1,5 XP pendant 2 heures.",
                 symbolName: "flask.fill", rarity: .common, category: .consumable,
                 price: Price(coins: 150), effect: .xpBoost(multiplier: 1.5, hours: 2),
                 isConsumable: true),
        ShopItem(id: "potion.xp.large", name: "Élixir d'expérience",
                 detail: "×2 XP pendant 4 heures.",
                 symbolName: "testtube.2", rarity: .rare, category: .consumable,
                 price: Price(coins: 600, gems: 2), effect: .xpBoost(multiplier: 2.0, hours: 4),
                 requiredLevel: 8, isConsumable: true),
        ShopItem(id: "freeze.single", name: "Gel de série",
                 detail: "Protège la série pour une journée manquée.",
                 symbolName: "snowflake", rarity: .uncommon, category: .consumable,
                 price: Price(coins: 250), effect: .streakFreeze(count: 1),
                 isConsumable: true),
        ShopItem(id: "freeze.triple", name: "Trio de gels",
                 detail: "Trois journées de protection d'un coup.",
                 symbolName: "snowflake.circle.fill", rarity: .rare, category: .consumable,
                 price: Price(coins: 650), effect: .streakFreeze(count: 3),
                 requiredLevel: 5, isConsumable: true),
        ShopItem(id: "restday", name: "Jour de repos",
                 detail: "Un jour neutre, sans culpabilité, qui ne casse rien.",
                 symbolName: "moon.zzz.fill", rarity: .uncommon, category: .consumable,
                 price: Price(coins: 300), effect: .restDayToken(count: 1),
                 isConsumable: true)
    ]

    static let themes: [ShopItem] = [
        ShopItem(id: "theme.nebula", name: "Nébuleuse",
                 detail: "Violets profonds et poussière d'étoiles.",
                 symbolName: "sparkles", rarity: .common, category: .theme,
                 price: .free, effect: .unlockTheme(id: "nebula")),
        ShopItem(id: "theme.aurora", name: "Aurore",
                 detail: "Roses et oranges de lever de soleil.",
                 symbolName: "sunrise.fill", rarity: .uncommon, category: .theme,
                 price: Price(coins: 800), effect: .unlockTheme(id: "aurora"), requiredLevel: 3),
        ShopItem(id: "theme.forest", name: "Sylve",
                 detail: "Émeraude et mousse, pour rester calme.",
                 symbolName: "leaf.fill", rarity: .uncommon, category: .theme,
                 price: Price(coins: 800), effect: .unlockTheme(id: "forest"), requiredLevel: 5),
        ShopItem(id: "theme.ocean", name: "Abysse",
                 detail: "Bleus profonds et reflets turquoise.",
                 symbolName: "water.waves", rarity: .rare, category: .theme,
                 price: Price(coins: 1500), effect: .unlockTheme(id: "ocean"), requiredLevel: 10),
        ShopItem(id: "theme.ember", name: "Braise",
                 detail: "Ambre et charbon ardent.",
                 symbolName: "flame.fill", rarity: .rare, category: .theme,
                 price: Price(coins: 1500), effect: .unlockTheme(id: "ember"), requiredLevel: 14),
        ShopItem(id: "theme.ink", name: "Encre",
                 detail: "Monochrome absolu, pour les puristes.",
                 symbolName: "circle.lefthalf.filled", rarity: .epic, category: .theme,
                 price: Price(coins: 2500, gems: 5), effect: .unlockTheme(id: "ink"), requiredLevel: 20),
        ShopItem(id: "theme.candy", name: "Guimauve",
                 detail: "Pastels sucrés et coins arrondis.",
                 symbolName: "birthday.cake.fill", rarity: .epic, category: .theme,
                 price: Price(coins: 2500, gems: 5), effect: .unlockTheme(id: "candy"), requiredLevel: 25),
        ShopItem(id: "theme.gold", name: "Âge d'or",
                 detail: "Or liquide sur noir. Réservé aux légendes.",
                 symbolName: "crown.fill", rarity: .legendary, category: .theme,
                 price: Price(coins: 6000, gems: 25), effect: .unlockTheme(id: "gold"), requiredLevel: 40)
    ]

    static let avatarItems: [ShopItem] = AvatarCatalog.purchasableParts.map { part in
        ShopItem(
            id: "avatar.\(part.id)",
            name: part.name,
            detail: part.slot.label,
            symbolName: part.symbolName,
            rarity: part.rarity,
            category: .avatar,
            price: part.price,
            effect: .unlockAvatarPart(id: part.id),
            requiredLevel: part.requiredLevel
        )
    }

    static let chests: [ShopItem] = [
        ShopItem(id: "chest.wood", name: "Coffre de bois",
                 detail: "Un butin modeste, mais garanti.",
                 symbolName: "shippingbox.fill", rarity: .common, category: .chest,
                 price: Price(coins: 200), effect: .openChest(tier: 1), isConsumable: true),
        ShopItem(id: "chest.silver", name: "Coffre d'argent",
                 detail: "De meilleures chances de rareté.",
                 symbolName: "shippingbox.circle.fill", rarity: .rare, category: .chest,
                 price: Price(coins: 750), effect: .openChest(tier: 2), requiredLevel: 8, isConsumable: true),
        ShopItem(id: "chest.gold", name: "Coffre doré",
                 detail: "Du légendaire à portée de main.",
                 symbolName: "cube.transparent.fill", rarity: .legendary, category: .chest,
                 price: Price(coins: 2000, gems: 3), effect: .openChest(tier: 3), requiredLevel: 18, isConsumable: true)
    ]

    static let utilities: [ShopItem] = [
        ShopItem(id: "pouch.small", name: "Bourse d'appoint",
                 detail: "Convertit 1 gemme en 400 pièces.",
                 symbolName: "bag.fill", rarity: .common, category: .utility,
                 price: Price(gems: 1), effect: .coinPouch(amount: 400), isConsumable: true)
    ]
}

// MARK: - Loot

public struct LootDrop: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let symbolName: String
    public let rarity: Rarity
    public let effect: ShopEffect

    public init(id: String, name: String, symbolName: String, rarity: Rarity, effect: ShopEffect) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.rarity = rarity
        self.effect = effect
    }
}

public enum LootEngine {

    /// Tire une rareté selon les poids, avec un bonus de palier pour les
    /// coffres de meilleure qualité.
    public static func rollRarity(tier: Int, rng: inout SeededRandom) -> Rarity {
        let bonus = Double(max(0, tier - 1))
        let weights = Rarity.allCases.map { rarity -> Double in
            // Les coffres supérieurs poussent la distribution vers le haut.
            let shift = pow(1.0 + 0.55 * bonus, Double(rarity.rawValue))
            return rarity.lootWeight * shift
        }
        let total = weights.reduce(0, +)
        var roll = rng.nextDouble() * total
        for (index, weight) in weights.enumerated() {
            roll -= weight
            if roll <= 0 { return Rarity.allCases[index] }
        }
        return .common
    }

    /// Ouvre un coffre : 1 à 3 objets selon le palier.
    public static func openChest(tier: Int, seed: UInt64) -> [LootDrop] {
        var rng = SeededRandom(seed: seed)
        let count = min(3, max(1, tier))
        return (0..<count).map { index in
            let rarity = rollRarity(tier: tier, rng: &rng)
            return drop(for: rarity, index: index, rng: &rng)
        }
    }

    static func drop(for rarity: Rarity, index: Int, rng: inout SeededRandom) -> LootDrop {
        let coinAmount = coinValue(for: rarity)
        let choice = rng.next(upperBound: 100)

        if choice < 45 {
            return LootDrop(
                id: "loot.coins.\(rarity.rawValue).\(index)",
                name: "\(coinAmount) pièces",
                symbolName: "dollarsign.circle.fill",
                rarity: rarity,
                effect: .coinPouch(amount: coinAmount)
            )
        }
        if choice < 65 {
            let count = max(1, rarity.rawValue)
            return LootDrop(
                id: "loot.freeze.\(rarity.rawValue).\(index)",
                name: count > 1 ? "\(count) gels de série" : "Gel de série",
                symbolName: "snowflake",
                rarity: rarity,
                effect: .streakFreeze(count: count)
            )
        }
        if choice < 85 {
            let multiplier = 1.25 + Double(rarity.rawValue) * 0.25
            let hours = 1 + rarity.rawValue
            return LootDrop(
                id: "loot.boost.\(rarity.rawValue).\(index)",
                name: "Potion ×\(String(format: "%.2f", multiplier))",
                symbolName: "flask.fill",
                rarity: rarity,
                effect: .xpBoost(multiplier: multiplier, hours: hours)
            )
        }
        // Objet cosmétique : on pioche dans les pièces d'avatar de cette rareté.
        let parts = AvatarCatalog.parts.filter { $0.rarity == rarity }
        if let part = parts.isEmpty ? nil : parts[Int(rng.next(upperBound: UInt64(parts.count)))] {
            return LootDrop(
                id: "loot.part.\(part.id)",
                name: part.name,
                symbolName: part.symbolName,
                rarity: rarity,
                effect: .unlockAvatarPart(id: part.id)
            )
        }
        return LootDrop(
            id: "loot.coins.fallback.\(index)",
            name: "\(coinAmount) pièces",
            symbolName: "dollarsign.circle.fill",
            rarity: rarity,
            effect: .coinPouch(amount: coinAmount)
        )
    }

    static func coinValue(for rarity: Rarity) -> Int {
        switch rarity {
        case .common: return 60
        case .uncommon: return 150
        case .rare: return 400
        case .epic: return 900
        case .legendary: return 2000
        case .mythic: return 5000
        }
    }
}
