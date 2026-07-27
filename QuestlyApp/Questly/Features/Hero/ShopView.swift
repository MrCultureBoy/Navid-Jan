import SwiftUI
import SwiftData
import QuestlyKit

/// L'Échoppe : la seule chose à faire des pièces gagnées. Elle vend du confort
/// (gels de série, jours de repos) et du plaisir (ambiances, apparence),
/// jamais de l'avantage déloyal sur soi-même.
struct ShopView: View {

    @Environment(QuestlyStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.questlyTheme) private var theme

    @Query private var profiles: [PlayerProfile]

    @State private var category: ShopCategory = .consumable
    @State private var lastPurchase: ShopItem?
    @State private var lootDrops: [LootDrop] = []
    @State private var showsLoot = false
    @State private var errorMessage: String?

    private var player: PlayerProfile? { profiles.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacingM) {
                walletBar
                categoryPicker
                itemGrid
                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, Metrics.spacingM)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Échoppe")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if showsLoot {
                LootRevealOverlay(drops: lootDrops) {
                    withAnimation(Motion.snappy) { showsLoot = false }
                }
            }
        }
        .alert("Achat impossible", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Bourse

    private var walletBar: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ta bourse")
                        .font(.questMicro)
                        .foregroundStyle(.secondary)
                    HStack(spacing: Metrics.spacingS) {
                        CurrencyPill(kind: .coins, amount: player?.coins ?? 0)
                        CurrencyPill(kind: .gems, amount: player?.gems ?? 0)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if let expiry = player?.boostExpiresAt, expiry > Date() {
                        Label(
                            "Potion active ×\(String(format: "%.2f", player?.boostMultiplier ?? 1))",
                            systemImage: "flask.fill"
                        )
                        .font(.questMicro)
                        .foregroundStyle(Color(hex: "BF5AF2"))
                    }
                    Label("\(player?.streakFreezes ?? 0) gels", systemImage: "snowflake")
                        .font(.questMicro)
                        .foregroundStyle(Color(hex: "64D2FF"))
                }
            }
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ShopCategory.allCases) { value in
                    Button {
                        withAnimation(Motion.snappy) { category = value }
                        Haptics.selection()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: value.symbolName).font(.system(size: 10))
                            Text(value.label).font(.questMicro)
                        }
                        .foregroundStyle(category == value ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background {
                            Capsule().fill(category == value
                                           ? AnyShapeStyle(theme.gradient)
                                           : AnyShapeStyle(Color.primary.opacity(0.06)))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: Articles

    private var items: [ShopItem] {
        ShopCatalog.all
            .filter { $0.category == category }
            .sorted { lhs, rhs in
                if lhs.requiredLevel != rhs.requiredLevel { return lhs.requiredLevel < rhs.requiredLevel }
                return lhs.price.coins < rhs.price.coins
            }
    }

    private var itemGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Metrics.spacingS), count: 2),
            spacing: Metrics.spacingS
        ) {
            ForEach(items) { item in
                ShopItemCard(
                    item: item,
                    isOwned: player?.owns(itemID: item.id) ?? false,
                    isLocked: (player?.level ?? 1) < item.requiredLevel,
                    canAfford: player.map { Wallet(coins: $0.coins, gems: $0.gems).canAfford(item.price) } ?? false
                ) {
                    buy(item)
                }
            }
        }
    }

    private func buy(_ item: ShopItem) {
        guard let player else { return }

        if player.level < item.requiredLevel {
            errorMessage = "Cet objet se débloque au niveau \(item.requiredLevel)."
            Haptics.warning()
            return
        }
        if !item.isConsumable && player.owns(itemID: item.id) {
            errorMessage = "Tu possèdes déjà cet objet."
            return
        }

        let before = player.unlockedItems
        guard store.purchase(item) else {
            errorMessage = "Il te manque des pièces ou des gemmes."
            Haptics.warning()
            return
        }

        Haptics.success()
        lastPurchase = item

        // Un coffre révèle son butin.
        if case .openChest(let tier) = item.effect {
            let seed = UInt64(abs(item.id.hashValue % 1_000_000))
            lootDrops = LootEngine.openChest(tier: tier, seed: seed)
            withAnimation(Motion.celebration) { showsLoot = true }
        }

        // Une ambiance achetée s'applique tout de suite.
        if case .unlockTheme(let id) = item.effect {
            settings.themeID = id
            themeManager.select(id: id)
        }

        _ = before
    }
}

// MARK: - Carte d'article

struct ShopItemCard: View {
    let item: ShopItem
    let isOwned: Bool
    let isLocked: Bool
    let canAfford: Bool
    let onBuy: () -> Void

    @Environment(\.questlyTheme) private var theme

    private var color: Color { Color(hex: item.rarity.hex) }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingS) {
            HStack {
                Image(systemName: item.symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
                RarityChip(rarity: item.rarity)
            }

            Text(item.name)
                .font(.questCallout)
                .lineLimit(1)

            Text(item.detail)
                .font(.questMicro)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(height: 28, alignment: .top)

            Spacer(minLength: 0)

            if isLocked {
                Label("Niveau \(item.requiredLevel)", systemImage: "lock.fill")
                    .font(.questMicro)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background { Capsule().fill(Color.primary.opacity(0.06)) }
            } else if isOwned && !item.isConsumable {
                Label("Possédé", systemImage: "checkmark.seal.fill")
                    .font(.questMicro)
                    .foregroundStyle(Color(hex: "30D158"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background { Capsule().fill(Color(hex: "30D158").opacity(0.12)) }
            } else {
                Button(action: onBuy) {
                    HStack(spacing: 5) {
                        if item.price.coins > 0 {
                            Image(systemName: "dollarsign.circle.fill").font(.system(size: 10))
                            Text("\(item.price.coins)").font(.questMicro).monospacedDigit()
                        }
                        if item.price.gems > 0 {
                            Image(systemName: "diamond.fill").font(.system(size: 10))
                            Text("\(item.price.gems)").font(.questMicro).monospacedDigit()
                        }
                        if item.price.isFree {
                            Text("Offert").font(.questMicro)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background {
                        Capsule().fill(canAfford
                                       ? AnyShapeStyle(theme.gradient)
                                       : AnyShapeStyle(Color.secondary.opacity(0.4)))
                    }
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(Metrics.spacingS + 2)
        .frame(height: 176)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .strokeBorder(color.opacity(isOwned ? 0.4 : 0.15), lineWidth: 1)
        }
        .opacity(isLocked ? 0.65 : 1)
    }
}

// MARK: - Révélation du butin

struct LootRevealOverlay: View {
    let drops: [LootDrop]
    let onDismiss: () -> Void

    @State private var revealed = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: Metrics.spacingM) {
                Text("Coffre ouvert")
                    .font(.questTitle)
                    .foregroundStyle(.white)

                ForEach(Array(drops.enumerated()), id: \.element.id) { index, drop in
                    if index < revealed {
                        HStack(spacing: Metrics.spacingS) {
                            Image(systemName: drop.symbolName)
                                .font(.system(size: 22))
                                .foregroundStyle(Color(hex: drop.rarity.hex))
                                .frame(width: 44, height: 44)
                                .background {
                                    Circle().fill(Color(hex: drop.rarity.hex).opacity(0.18))
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(drop.name)
                                    .font(.questCallout)
                                    .foregroundStyle(.white)
                                RarityChip(rarity: drop.rarity)
                            }
                            Spacer()
                        }
                        .padding(Metrics.spacingS)
                        .frame(maxWidth: 300)
                        .background {
                            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                                .fill(.ultraThinMaterial)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }

                Button("Récupérer", action: onDismiss)
                    .font(.questHeadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Metrics.spacingL)
                    .padding(.vertical, 12)
                    .background { Capsule().fill(Color.white.opacity(0.2)) }
                    .padding(.top, Metrics.spacingS)
            }

            ConfettiView(pieceCount: 70, duration: 2.2)
                .ignoresSafeArea()
        }
        .onAppear(perform: revealSequentially)
    }

    private func revealSequentially() {
        for index in drops.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.45) {
                withAnimation(Motion.bouncy) { revealed = index + 1 }
                Haptics.play(.medium)
            }
        }
    }
}

// MARK: - Personnalisation de l'avatar

struct AvatarBuilderView: View {

    @Environment(QuestlyStore.self) private var store
    @Environment(\.questlyTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @Query private var profiles: [PlayerProfile]

    @State private var slot: AvatarSlot = .face
    @State private var name = ""

    private var player: PlayerProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: Metrics.spacingM) {
                preview
                slotPicker
                partGrid
            }
            .padding(.horizontal, Metrics.spacingM)
            .navigationTitle("Apparence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") {
                        if let player, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                            player.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            store.save()
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { name = player?.displayName ?? "" }
        }
    }

    private var preview: some View {
        VStack(spacing: Metrics.spacingS) {
            ZStack {
                if let aura = player?.avatarPart(for: .aura), aura.id != "aura.none" {
                    Image(systemName: aura.symbolName)
                        .font(.system(size: 120))
                        .foregroundStyle(theme.accent.opacity(0.15))
                }
                LevelRing(
                    progress: player?.levelProgress ?? .zero,
                    size: 110,
                    lineWidth: 8,
                    emoji: player?.avatarPart(for: .face)?.emoji ?? "🧭",
                    showsLevelBadge: false
                )
                if let hat = player?.avatarPart(for: .headgear), hat.id != "hat.none" {
                    Image(systemName: hat.symbolName)
                        .font(.system(size: 24))
                        .foregroundStyle(Color(hex: hat.rarity.hex))
                        .offset(y: -63)
                }
                if let pet = player?.avatarPart(for: .companion), pet.id != "pet.none", let emoji = pet.emoji {
                    Text(emoji).font(.system(size: 26)).offset(x: 54, y: 36)
                }
            }
            .frame(height: 130)

            TextField("Ton nom d'aventurier", text: $name)
                .font(.questHeadline)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
        }
    }

    private var slotPicker: some View {
        QuestlySegmentedPicker(
            items: AvatarSlot.allCases,
            label: { $0.label },
            selection: $slot
        )
    }

    private var partGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Metrics.spacingS), count: 3),
                spacing: Metrics.spacingS
            ) {
                ForEach(AvatarCatalog.parts(in: slot)) { part in
                    partCell(part)
                }
            }
            .padding(.bottom, Metrics.spacingL)
        }
    }

    private func partCell(_ part: AvatarPart) -> some View {
        let owned = isOwned(part)
        let isEquipped = player?.avatarLoadout[part.slot.rawValue] == part.id
        let color = Color(hex: part.rarity.hex)

        return Button {
            guard owned, let player else {
                Haptics.warning()
                return
            }
            store.equip(part: part, on: player)
            Haptics.selection()
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(isEquipped ? color.opacity(0.22) : Color.primary.opacity(0.05))
                        .frame(width: 52, height: 52)
                    if let emoji = part.emoji, part.id != "pet.none" {
                        Text(emoji).font(.system(size: 24))
                    } else {
                        Image(systemName: part.symbolName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(owned ? color : .secondary)
                    }
                    if !owned {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background { Circle().fill(Color.black.opacity(0.55)) }
                            .offset(x: 18, y: 18)
                    }
                }

                Text(part.name)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(owned ? .primary : .secondary)

                if !owned {
                    Text(part.price.isFree ? "Niv. \(part.requiredLevel)" : "\(part.price.coins) 🪙")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Metrics.spacingS)
            .background {
                RoundedRectangle(cornerRadius: Metrics.cornerRadiusSmall, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(isEquipped ? color : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(PressableStyle())
    }

    private func isOwned(_ part: AvatarPart) -> Bool {
        guard let player else { return false }
        if part.price.isFree { return player.level >= part.requiredLevel }
        return player.owns(itemID: part.id) || player.owns(itemID: "avatar.\(part.id)")
    }
}
