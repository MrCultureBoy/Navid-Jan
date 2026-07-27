import XCTest
@testable import QuestlyKit

final class LevelCurveTests: XCTestCase {

    func testLevelOneStartsAtZero() {
        XCTAssertEqual(LevelCurve.totalXP(toReach: 1), 0)
        XCTAssertEqual(LevelCurve.level(forTotalXP: 0), 1)
        XCTAssertEqual(LevelCurve.level(forTotalXP: -50), 1)
    }

    func testCurveIsStrictlyIncreasing() {
        var previous = -1
        for level in 1...200 {
            let total = LevelCurve.totalXP(toReach: level)
            XCTAssertGreaterThan(total, previous, "Le seuil du niveau \(level) doit dépasser le précédent")
            previous = total
        }
    }

    func testRoundTripBetweenTotalXPAndLevel() {
        for level in 1...300 {
            let threshold = LevelCurve.totalXP(toReach: level)
            XCTAssertEqual(LevelCurve.level(forTotalXP: threshold), level,
                           "Le seuil exact du niveau \(level) doit rendre ce niveau")
            if level < 300 {
                XCTAssertEqual(LevelCurve.level(forTotalXP: threshold + 1), level)
                XCTAssertEqual(LevelCurve.level(forTotalXP: LevelCurve.totalXP(toReach: level + 1) - 1), level)
            }
        }
    }

    func testProgressFractionStaysInBounds() {
        for xp in stride(from: 0, through: 50_000, by: 137) {
            let progress = LevelCurve.progress(forTotalXP: xp)
            XCTAssertGreaterThanOrEqual(progress.fraction, 0)
            XCTAssertLessThanOrEqual(progress.fraction, 1)
            XCTAssertGreaterThanOrEqual(progress.xpIntoLevel, 0)
            XCTAssertLessThanOrEqual(progress.xpIntoLevel, progress.xpRequiredForLevel)
        }
    }

    func testProgressAtExactThresholdIsZeroFraction() {
        let threshold = LevelCurve.totalXP(toReach: 12)
        let progress = LevelCurve.progress(forTotalXP: threshold)
        XCTAssertEqual(progress.level, 12)
        XCTAssertEqual(progress.xpIntoLevel, 0)
        XCTAssertEqual(progress.fraction, 0, accuracy: 0.0001)
    }

    func testFirstLevelIsReachableQuickly() {
        // Une première montée de niveau doit rester à portée d'une bonne journée.
        XCTAssertEqual(LevelCurve.xpToAdvance(from: 1), 100)
        XCTAssertLessThan(LevelCurve.totalXP(toReach: 3), 400)
    }

    func testRankMapping() {
        XCTAssertEqual(Rank.forLevel(1), .novice)
        XCTAssertEqual(Rank.forLevel(5), .novice)
        XCTAssertEqual(Rank.forLevel(6), .apprentice)
        XCTAssertEqual(Rank.forLevel(11), .squire)
        XCTAssertEqual(Rank.forLevel(9999), .eternal)
        XCTAssertEqual(Rank.novice.minimumLevel, 1)
        XCTAssertEqual(Rank.apprentice.minimumLevel, 6)
    }

    func testAttributeCurveRoundTrip() {
        for level in 1...80 {
            let total = AttributeCurve.totalXP(toReach: level)
            XCTAssertEqual(AttributeCurve.level(forTotalXP: total), level)
        }
        let progress = AttributeCurve.progress(forTotalXP: 0)
        XCTAssertEqual(progress.level, 1)
        XCTAssertEqual(progress.fraction, 0, accuracy: 0.0001)
    }
}

final class XPEngineTests: XCTestCase {

    func testBaseAwardMatchesDifficulty() {
        let task = XPTaskDescriptor(difficulty: .medium, priority: .p4)
        let award = XPEngine.award(for: task, context: XPContext(), calendar: testCalendar)
        XCTAssertEqual(award.totalXP, 20)
        XCTAssertEqual(award.coins, 5)
        XCTAssertEqual(award.gems, 0)
    }

    func testPriorityIncreasesReward() {
        let low = XPEngine.award(for: XPTaskDescriptor(difficulty: .medium, priority: .p4), context: XPContext(), calendar: testCalendar)
        let high = XPEngine.award(for: XPTaskDescriptor(difficulty: .medium, priority: .p1), context: XPContext(), calendar: testCalendar)
        XCTAssertGreaterThan(high.totalXP, low.totalXP)
        XCTAssertEqual(high.totalXP, 30) // 20 × 1,5
    }

    func testBossDoublesReward() {
        let normal = XPEngine.award(for: XPTaskDescriptor(difficulty: .hard), context: XPContext(), calendar: testCalendar)
        let boss = XPEngine.award(for: XPTaskDescriptor(difficulty: .hard, isBoss: true), context: XPContext(), calendar: testCalendar)
        XCTAssertEqual(boss.totalXP, normal.totalXP * 2)
        XCTAssertGreaterThan(boss.gems, 0)
    }

    func testOnTimeBonusAndLatePenalty() {
        let due = makeDate(2026, 3, 10, 12, 0)
        let task = XPTaskDescriptor(difficulty: .medium, dueDate: due, hasTimeComponent: true)

        let early = XPEngine.award(for: task, context: XPContext(completionDate: makeDate(2026, 3, 10, 10, 0)), calendar: testCalendar)
        let late = XPEngine.award(for: task, context: XPContext(completionDate: makeDate(2026, 3, 12, 10, 0)), calendar: testCalendar)

        XCTAssertGreaterThan(early.totalXP, late.totalXP)
        XCTAssertEqual(early.totalXP, 23)  // 20 × 1,15
        XCTAssertEqual(late.totalXP, 17)   // 20 × 0,85
    }

    func testAllDayTaskUsesDayGranularity() {
        let due = makeDate(2026, 3, 10)
        let task = XPTaskDescriptor(difficulty: .easy, dueDate: due, hasTimeComponent: false)
        // Terminée le jour dit, même tard dans la soirée : pas de pénalité.
        let award = XPEngine.award(for: task, context: XPContext(completionDate: makeDate(2026, 3, 10, 23, 30)), calendar: testCalendar)
        XCTAssertEqual(award.totalXP, 12) // 10 × 1,15 = 11,5 arrondi
    }

    func testStreakMultiplierIsCappedAt30Percent() {
        XCTAssertEqual(XPEngine.streakMultiplier(days: 0), 1.0)
        XCTAssertEqual(XPEngine.streakMultiplier(days: 1), 1.0)
        XCTAssertEqual(XPEngine.streakMultiplier(days: 10), 1.10, accuracy: 0.0001)
        XCTAssertEqual(XPEngine.streakMultiplier(days: 30), 1.30, accuracy: 0.0001)
        XCTAssertEqual(XPEngine.streakMultiplier(days: 400), 1.30, accuracy: 0.0001)
    }

    func testComboMultiplierIsCapped() {
        XCTAssertEqual(XPEngine.comboMultiplier(count: 1), 1.0)
        XCTAssertEqual(XPEngine.comboMultiplier(count: 3), 1.10, accuracy: 0.0001)
        XCTAssertEqual(XPEngine.comboMultiplier(count: 6), 1.25, accuracy: 0.0001)
        XCTAssertEqual(XPEngine.comboMultiplier(count: 100), 1.25, accuracy: 0.0001)
    }

    func testBreakdownExplainsEveryBonus() {
        let task = XPTaskDescriptor(
            difficulty: .hard,
            priority: .p1,
            estimatedMinutes: 60,
            completedSubtaskCount: 3,
            totalSubtaskCount: 3,
            isBoss: true,
            focusedMinutes: 45
        )
        let context = XPContext(streakDays: 12, comboCount: 3, boostMultiplier: 1.5, isFirstCompletionOfDay: true)
        let award = XPEngine.award(for: task, context: context, calendar: testCalendar)

        let ids = Set(award.breakdown.map(\.id))
        XCTAssertTrue(ids.contains("base"))
        XCTAssertTrue(ids.contains("subtasks"))
        XCTAssertTrue(ids.contains("duration"))
        XCTAssertTrue(ids.contains("focus"))
        XCTAssertTrue(ids.contains("priority"))
        XCTAssertTrue(ids.contains("streak"))
        XCTAssertTrue(ids.contains("combo"))
        XCTAssertTrue(ids.contains("boss"))
        XCTAssertTrue(ids.contains("boost"))
        XCTAssertTrue(ids.contains("firstOfDay"))
        XCTAssertGreaterThan(award.totalXP, 100)
    }

    func testAttributeXPOnlyWhenAreaKnown() {
        let withArea = XPEngine.award(for: XPTaskDescriptor(lifeArea: .body), context: XPContext(), calendar: testCalendar)
        let without = XPEngine.award(for: XPTaskDescriptor(), context: XPContext(), calendar: testCalendar)
        XCTAssertGreaterThan(withArea.attributeXP, 0)
        XCTAssertEqual(withArea.lifeArea, .body)
        XCTAssertEqual(without.attributeXP, 0)
    }

    func testAwardNeverDropsBelowOne() {
        let task = XPTaskDescriptor(difficulty: .trivial, priority: .p4, dueDate: makeDate(2020, 1, 1), hasTimeComponent: true)
        let award = XPEngine.award(for: task, context: XPContext(completionDate: makeDate(2026, 1, 1)), calendar: testCalendar)
        XCTAssertGreaterThanOrEqual(award.totalXP, 1)
        XCTAssertGreaterThanOrEqual(award.coins, 1)
    }
}

final class ComboTrackerTests: XCTestCase {

    func testComboGrowsInsideWindow() {
        var tracker = ComboTracker()
        let start = makeDate(2026, 5, 4, 9, 0)
        XCTAssertEqual(tracker.register(at: start), 1)
        XCTAssertEqual(tracker.register(at: start.addingTimeInterval(60)), 2)
        XCTAssertEqual(tracker.register(at: start.addingTimeInterval(200)), 3)
        XCTAssertTrue(tracker.isActive(at: start.addingTimeInterval(210)))
    }

    func testComboResetsAfterWindow() {
        var tracker = ComboTracker()
        let start = makeDate(2026, 5, 4, 9, 0)
        _ = tracker.register(at: start)
        _ = tracker.register(at: start.addingTimeInterval(60))
        XCTAssertEqual(tracker.register(at: start.addingTimeInterval(60 + 400)), 1)
        XCTAssertFalse(tracker.isActive(at: start.addingTimeInterval(60 + 400)))
    }

    func testRemainingSecondsCountsDown() {
        var tracker = ComboTracker()
        let start = makeDate(2026, 5, 4, 9, 0)
        _ = tracker.register(at: start)
        XCTAssertEqual(tracker.remainingSeconds(at: start.addingTimeInterval(60)), 240)
        XCTAssertEqual(tracker.remainingSeconds(at: start.addingTimeInterval(999)), 0)
    }
}
