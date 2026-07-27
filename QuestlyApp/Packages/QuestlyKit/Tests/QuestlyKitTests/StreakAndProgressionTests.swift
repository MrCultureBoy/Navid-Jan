import XCTest
@testable import QuestlyKit

final class StreakEngineTests: XCTestCase {

    func days(_ list: [String]) -> Set<Date> {
        Set(list.map { text in
            let parts = text.split(separator: "-").compactMap { Int($0) }
            return makeDate(parts[0], parts[1], parts[2])
        })
    }

    func testEmptyHistory() {
        let state = StreakEngine.evaluate(activeDays: [], today: makeDate(2026, 3, 4), calendar: testCalendar)
        XCTAssertEqual(state.current, 0)
        XCTAssertEqual(state.longest, 0)
        XCTAssertFalse(state.isAtRisk)
    }

    func testConsecutiveDaysIncludingToday() {
        let state = StreakEngine.evaluate(
            activeDays: days(["2026-03-02", "2026-03-03", "2026-03-04"]),
            today: makeDate(2026, 3, 4, 20, 0),
            calendar: testCalendar
        )
        XCTAssertEqual(state.current, 3)
        XCTAssertEqual(state.longest, 3)
        XCTAssertFalse(state.isAtRisk)
    }

    func testTodayNotYetDoneKeepsStreakButFlagsRisk() {
        let state = StreakEngine.evaluate(
            activeDays: days(["2026-03-02", "2026-03-03"]),
            today: makeDate(2026, 3, 4, 9, 0),
            calendar: testCalendar
        )
        XCTAssertEqual(state.current, 2, "La journée en cours ne casse pas la série")
        XCTAssertTrue(state.isAtRisk)
    }

    func testGapBreaksStreak() {
        let state = StreakEngine.evaluate(
            activeDays: days(["2026-02-25", "2026-02-26", "2026-03-03", "2026-03-04"]),
            today: makeDate(2026, 3, 4, 12, 0),
            calendar: testCalendar
        )
        XCTAssertEqual(state.current, 2)
        XCTAssertEqual(state.longest, 2)
    }

    func testFreezeBridgesASingleMissedDay() {
        let config = StreakEngine.Configuration(availableFreezes: 1)
        let state = StreakEngine.evaluate(
            activeDays: days(["2026-03-01", "2026-03-02", "2026-03-04"]),
            today: makeDate(2026, 3, 4, 12, 0),
            configuration: config,
            calendar: testCalendar
        )
        // 4 mars + (3 mars gelé) + 2 mars + 1er mars
        XCTAssertEqual(state.current, 3)
        XCTAssertEqual(state.freezesConsumed, 1)
    }

    func testFreezeIsNotSpentWithoutPriorActivity() {
        let config = StreakEngine.Configuration(availableFreezes: 3)
        let state = StreakEngine.evaluate(
            activeDays: days(["2026-03-04"]),
            today: makeDate(2026, 3, 4, 12, 0),
            configuration: config,
            calendar: testCalendar
        )
        XCTAssertEqual(state.current, 1)
        XCTAssertEqual(state.freezesConsumed, 0, "Inutile de geler le vide")
    }

    func testRestDaysAreNeutral() {
        // Samedi (7) et dimanche (1) déclarés jours de repos.
        let config = StreakEngine.Configuration(restWeekdays: [1, 7])
        let state = StreakEngine.evaluate(
            activeDays: days(["2026-03-05", "2026-03-06", "2026-03-09"]), // jeu, ven, lun
            today: makeDate(2026, 3, 9, 18, 0),
            configuration: config,
            calendar: testCalendar
        )
        XCTAssertEqual(state.current, 3, "Le week-end ne compte pas mais ne casse pas")
    }

    func testLongestStreakLooksAtWholeHistory() {
        let state = StreakEngine.evaluate(
            activeDays: days([
                "2026-01-01", "2026-01-02", "2026-01-03", "2026-01-04", "2026-01-05",
                "2026-03-03", "2026-03-04"
            ]),
            today: makeDate(2026, 3, 4, 12, 0),
            calendar: testCalendar
        )
        XCTAssertEqual(state.current, 2)
        XCTAssertEqual(state.longest, 5)
        XCTAssertEqual(state.totalActiveDays, 7)
    }

    func testMilestoneDetection() {
        let state = StreakState(current: 7)
        XCTAssertEqual(state.milestoneReached, 7)
        XCTAssertNil(StreakState(current: 8).milestoneReached)
    }

    func testHeatmapLevels() {
        let cells = StreakEngine.heatmap(
            completionsByDay: [
                makeDate(2026, 3, 1): 1,
                makeDate(2026, 3, 2): 4,
                makeDate(2026, 3, 3): 8
            ],
            from: makeDate(2026, 3, 1),
            to: makeDate(2026, 3, 5),
            calendar: testCalendar
        )
        XCTAssertEqual(cells.count, 5)
        XCTAssertEqual(cells[0].level, 1)
        XCTAssertEqual(cells[2].level, 4)
        XCTAssertEqual(cells[4].level, 0)
        XCTAssertEqual(cells[4].count, 0)
    }
}

final class AchievementTests: XCTestCase {

    func testCatalogHasUniqueIdentifiers() {
        let ids = AchievementCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Deux hauts faits partagent le même identifiant")
        XCTAssertGreaterThan(ids.count, 40)
    }

    func testCatalogGoalsArePositive() {
        for definition in AchievementCatalog.all {
            XCTAssertGreaterThan(definition.goal, 0, "\(definition.id) a un objectif nul")
            XCTAssertGreaterThan(definition.xpReward, 0, "\(definition.id) ne rapporte rien")
        }
    }

    func testEveryCategoryIsPopulated() {
        for category in AchievementCategory.allCases {
            let items = AchievementCatalog.all.filter { $0.category == category }
            XCTAssertFalse(items.isEmpty, "La catégorie \(category.label) est vide")
        }
    }

    func testProgressEvaluation() {
        let snapshot = PlayerSnapshot(level: 12, tasksCompleted: 60, currentStreak: 4)
        let progress = AchievementEngine.evaluate(snapshot: snapshot)

        let centurion = progress.first { $0.id == "vol.100" }
        XCTAssertNotNil(centurion)
        XCTAssertEqual(centurion?.value, 60)
        XCTAssertFalse(centurion?.isUnlocked ?? true)
        XCTAssertEqual(centurion?.fraction ?? 0, 0.6, accuracy: 0.001)
        XCTAssertEqual(centurion?.remaining, 40)

        let firstBlood = progress.first { $0.id == "first.blood" }
        XCTAssertTrue(firstBlood?.isUnlocked ?? false)
    }

    func testNewlyUnlockedExcludesAlreadyKnown() {
        let snapshot = PlayerSnapshot(tasksCompleted: 30)
        let all = AchievementEngine.newlyUnlocked(snapshot: snapshot, alreadyUnlocked: [])
        XCTAssertTrue(all.contains { $0.id == "vol.25" })

        let filtered = AchievementEngine.newlyUnlocked(snapshot: snapshot, alreadyUnlocked: ["vol.25", "first.blood"])
        XCTAssertFalse(filtered.contains { $0.id == "vol.25" })
    }

    func testBalancedAreasMetric() {
        var counts: [LifeArea: Int] = [:]
        for area in LifeArea.allCases { counts[area] = 12 }
        let snapshot = PlayerSnapshot(completionsByArea: counts)
        XCTAssertEqual(snapshot.value(for: .balancedAreas), LifeArea.allCases.count)
        XCTAssertTrue(
            AchievementEngine.newlyUnlocked(snapshot: snapshot, alreadyUnlocked: [])
                .contains { $0.id == "balance.all" }
        )
    }

    func testAlmostThereIsSortedByProgress() {
        let snapshot = PlayerSnapshot(level: 4, tasksCompleted: 24, currentStreak: 2, focusMinutes: 10)
        let almost = AchievementEngine.almostThere(snapshot: snapshot, limit: 3)
        XCTAssertLessThanOrEqual(almost.count, 3)
        for pair in zip(almost, almost.dropFirst()) {
            XCTAssertGreaterThanOrEqual(pair.0.fraction, pair.1.fraction)
        }
        XCTAssertFalse(almost.contains { $0.isUnlocked })
    }
}

final class QuestGeneratorTests: XCTestCase {

    func testDailyQuestsAreDeterministic() {
        let date = makeDate(2026, 3, 4)
        let first = QuestGenerator.daily(for: date, playerLevel: 7, calendar: testCalendar)
        let second = QuestGenerator.daily(for: date, playerLevel: 7, calendar: testCalendar)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertEqual(first.map(\.target), second.map(\.target))
    }

    func testDifferentDaysGiveDifferentQuests() {
        let a = QuestGenerator.daily(for: makeDate(2026, 3, 4), playerLevel: 7, calendar: testCalendar)
        let b = QuestGenerator.daily(for: makeDate(2026, 3, 5), playerLevel: 7, calendar: testCalendar)
        XCTAssertNotEqual(a.map(\.id), b.map(\.id))
    }

    func testQuestKindsAreUniqueWithinADay() {
        for offset in 0..<40 {
            let date = makeDate(2026, 3, 4).adding(days: offset, calendar: testCalendar)
            let quests = QuestGenerator.daily(for: date, playerLevel: 10, calendar: testCalendar)
            let kinds = quests.map(\.kind)
            XCTAssertEqual(Set(kinds).count, kinds.count, "Doublon de type de quête le \(formattedDay(date))")
        }
    }

    func testPreferredAreaProducesTargetedQuest() {
        let quests = QuestGenerator.daily(
            for: makeDate(2026, 3, 4),
            playerLevel: 5,
            preferredAreas: [.body],
            calendar: testCalendar
        )
        XCTAssertEqual(quests.first?.kind, .completeInArea)
        XCTAssertEqual(quests.first?.lifeArea, .body)
    }

    func testTargetsScaleWithLevelButStayReasonable() {
        let low = QuestGenerator.weekly(for: makeDate(2026, 3, 4), playerLevel: 1, calendar: testCalendar)
        let high = QuestGenerator.weekly(for: makeDate(2026, 3, 4), playerLevel: 60, calendar: testCalendar)
        XCTAssertGreaterThanOrEqual(high.target, low.target)
        XCTAssertLessThanOrEqual(Double(high.target), Double(low.target) * 2.0)
    }

    func testWeeklyQuestIsStableAcrossTheWeek() {
        let monday = QuestGenerator.weekly(for: makeDate(2026, 3, 2), playerLevel: 5, calendar: testCalendar)
        let friday = QuestGenerator.weekly(for: makeDate(2026, 3, 6), playerLevel: 5, calendar: testCalendar)
        XCTAssertEqual(monday.id, friday.id)
    }

    func testGenerateReturnsDailiesPlusWeekly() {
        let quests = QuestGenerator.generate(for: makeDate(2026, 3, 4), playerLevel: 3, calendar: testCalendar)
        XCTAssertEqual(quests.filter { $0.period == .daily }.count, 3)
        XCTAssertEqual(quests.filter { $0.period == .weekly }.count, 1)
    }

    func testProgressFraction() {
        let quest = QuestGenerator.daily(for: makeDate(2026, 3, 4), playerLevel: 1, calendar: testCalendar)[0]
        XCTAssertEqual(quest.progressFraction(0), 0)
        XCTAssertEqual(quest.progressFraction(quest.target), 1)
        XCTAssertEqual(quest.progressFraction(quest.target * 5), 1)
    }
}

final class EconomyTests: XCTestCase {

    func testWalletSpending() {
        var wallet = Wallet(coins: 100, gems: 2)
        XCTAssertFalse(wallet.spend(Price(coins: 200)))
        XCTAssertEqual(wallet.coins, 100)
        XCTAssertTrue(wallet.spend(Price(coins: 80, gems: 1)))
        XCTAssertEqual(wallet.coins, 20)
        XCTAssertEqual(wallet.gems, 1)
    }

    func testShopCatalogIntegrity() {
        let ids = ShopCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Identifiants d'objets dupliqués")
        for item in ShopCatalog.all where item.category != .theme {
            XCTAssertGreaterThanOrEqual(item.requiredLevel, 1)
        }
        XCTAssertFalse(ShopCatalog.available(forLevel: 1).isEmpty)
        XCTAssertGreaterThan(
            ShopCatalog.available(forLevel: 50).count,
            ShopCatalog.available(forLevel: 1).count
        )
    }

    func testAvatarCatalogIntegrity() {
        let ids = AvatarCatalog.parts.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        for slot in AvatarSlot.allCases {
            XCTAssertFalse(AvatarCatalog.parts(in: slot).isEmpty, "Aucune pièce pour \(slot.label)")
        }
        // Le vestiaire de départ doit être gratuit et disponible au niveau 1.
        for (_, id) in AvatarCatalog.defaultLoadout {
            let part = AvatarCatalog.part(id: id)
            XCTAssertNotNil(part, "Pièce par défaut introuvable : \(id)")
            XCTAssertTrue(part?.isFree ?? false)
        }
    }

    func testChestOpeningIsDeterministic() {
        let a = LootEngine.openChest(tier: 2, seed: 42)
        let b = LootEngine.openChest(tier: 2, seed: 42)
        XCTAssertEqual(a.map(\.id), b.map(\.id))
        XCTAssertEqual(a.count, 2)
    }

    func testHigherTierChestsSkewRarer() {
        func averageRarity(tier: Int) -> Double {
            var total = 0
            let samples = 400
            for seed in 0..<samples {
                var rng = SeededRandom(seed: UInt64(seed) &+ 1)
                total += LootEngine.rollRarity(tier: tier, rng: &rng).rawValue
            }
            return Double(total) / Double(samples)
        }
        let wood = averageRarity(tier: 1)
        let gold = averageRarity(tier: 3)
        XCTAssertGreaterThan(gold, wood, "Un coffre doré doit donner mieux qu'un coffre de bois")
    }

    func testSeededRandomIsReproducible() {
        var a = SeededRandom(seed: 7)
        var b = SeededRandom(seed: 7)
        for _ in 0..<50 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testSeededRandomBounds() {
        var rng = SeededRandom(seed: 1234)
        for _ in 0..<500 {
            let value = rng.next(upperBound: 10)
            XCTAssertLessThan(value, 10)
        }
        for _ in 0..<200 {
            let value = rng.nextDouble()
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThan(value, 1)
        }
    }
}
