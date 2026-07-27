import XCTest
@testable import QuestlyKit

final class ScheduleEngineTests: XCTestCase {

    let day = makeDate(2026, 3, 4) // mercredi

    func busy(_ startHour: Int, _ startMinute: Int, _ endHour: Int, _ endMinute: Int, _ title: String = "") -> BusyInterval {
        BusyInterval(
            id: "\(title)-\(startHour):\(startMinute)",
            start: makeDate(2026, 3, 4, startHour, startMinute),
            end: makeDate(2026, 3, 4, endHour, endMinute),
            title: title
        )
    }

    func testFreeSlotsOnAnEmptyDay() {
        let slots = ScheduleEngine.freeSlots(on: day, busy: [], calendar: testCalendar)
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(formatted(slots[0].start), "2026-03-04 09:00")
        XCTAssertEqual(formatted(slots[0].end), "2026-03-04 18:00")
        XCTAssertEqual(slots[0].minutes, 540)
    }

    func testFreeSlotsAroundMeetings() {
        let slots = ScheduleEngine.freeSlots(
            on: day,
            busy: [busy(10, 0, 11, 0, "Point"), busy(14, 0, 15, 30, "Atelier")],
            calendar: testCalendar
        )
        XCTAssertEqual(slots.map { "\(formatted($0.start))→\(formatted($0.end))" }, [
            "2026-03-04 09:00→2026-03-04 10:00",
            "2026-03-04 11:00→2026-03-04 14:00",
            "2026-03-04 15:30→2026-03-04 18:00"
        ])
    }

    func testOverlappingBusyIntervalsAreMerged() {
        let slots = ScheduleEngine.freeSlots(
            on: day,
            busy: [busy(10, 0, 12, 0), busy(11, 0, 13, 0), busy(12, 30, 14, 0)],
            calendar: testCalendar
        )
        XCTAssertEqual(slots.count, 2)
        XCTAssertEqual(formatted(slots[1].start), "2026-03-04 14:00")
    }

    func testMinimumSlotLengthFiltersCrumbs() {
        let slots = ScheduleEngine.freeSlots(
            on: day,
            busy: [busy(9, 10, 18, 0)],
            minimumMinutes: 15,
            calendar: testCalendar
        )
        XCTAssertTrue(slots.isEmpty, "Un trou de 10 minutes ne doit pas être proposé")
    }

    func testNotBeforeTrimsThePast() {
        let slots = ScheduleEngine.freeSlots(
            on: day,
            busy: [],
            notBefore: makeDate(2026, 3, 4, 14, 30),
            calendar: testCalendar
        )
        XCTAssertEqual(formatted(slots[0].start), "2026-03-04 14:30")
    }

    func testAutoPlanPlacesEverythingWhenThereIsRoom() {
        let tasks = [
            PlannableTask(id: "a", title: "Rapport", estimatedMinutes: 60, priority: .p1, difficulty: .hard, energy: .high),
            PlannableTask(id: "b", title: "Mails", estimatedMinutes: 30, priority: .p3, difficulty: .easy, energy: .low),
            PlannableTask(id: "c", title: "Appels", estimatedMinutes: 45, priority: .p2, difficulty: .medium)
        ]
        let plan = ScheduleEngine.autoPlan(tasks: tasks, on: day, busy: [], calendar: testCalendar)
        XCTAssertEqual(plan.blocks.count, 3)
        XCTAssertTrue(plan.unplaced.isEmpty)
        XCTAssertEqual(plan.usedMinutes, 135)

        // Les blocs ne se chevauchent jamais.
        for pair in zip(plan.blocks, plan.blocks.dropFirst()) {
            XCTAssertLessThanOrEqual(pair.0.end, pair.1.start)
        }
    }

    func testAutoPlanPutsDemandingWorkInThePeakWindow() {
        let tasks = [
            PlannableTask(id: "boss", title: "Boss", estimatedMinutes: 90, difficulty: .epic, energy: .high, isBoss: true)
        ]
        let plan = ScheduleEngine.autoPlan(tasks: tasks, on: day, busy: [], calendar: testCalendar)
        let block = plan.blocks[0]
        XCTAssertGreaterThanOrEqual(block.start, makeDate(2026, 3, 4, 9, 0))
        XCTAssertLessThan(block.start, makeDate(2026, 3, 4, 12, 0))
        XCTAssertTrue(block.rationale.contains("pic d'énergie"))
    }

    func testAutoPlanReportsWhatDoesNotFit() {
        let tasks = (0..<12).map {
            PlannableTask(id: "t\($0)", title: "Tâche \($0)", estimatedMinutes: 60)
        }
        let plan = ScheduleEngine.autoPlan(tasks: tasks, on: day, busy: [], bufferMinutes: 0, calendar: testCalendar)
        XCTAssertEqual(plan.blocks.count, 9, "9 heures ouvrées = 9 blocs d'une heure")
        XCTAssertEqual(plan.unplaced.count, 3)
    }

    func testAutoPlanRespectsDeadlineOrder() {
        let tasks = [
            PlannableTask(id: "later", title: "Plus tard", estimatedMinutes: 60, priority: .p1, dueDate: makeDate(2026, 3, 20)),
            PlannableTask(id: "urgent", title: "Aujourd'hui", estimatedMinutes: 60, priority: .p4, dueDate: makeDate(2026, 3, 4))
        ]
        let plan = ScheduleEngine.autoPlan(tasks: tasks, on: day, busy: [], calendar: testCalendar)
        XCTAssertEqual(plan.blocks.first?.taskID, "urgent")
    }

    func testBufferIsInsertedBetweenBlocks() {
        let tasks = [
            PlannableTask(id: "a", title: "A", estimatedMinutes: 60),
            PlannableTask(id: "b", title: "B", estimatedMinutes: 60)
        ]
        let plan = ScheduleEngine.autoPlan(tasks: tasks, on: day, busy: [], bufferMinutes: 15, calendar: testCalendar)
        XCTAssertEqual(plan.blocks.count, 2)
        let gap = plan.blocks[1].start.timeIntervalSince(plan.blocks[0].end) / 60
        XCTAssertGreaterThanOrEqual(gap, 15)
    }

    func testSuggestSlotsSkipsNonWorkingDays() {
        // Vendredi 6 mars, plein. Le week-end n'est pas travaillé → lundi 9.
        let suggestions = ScheduleEngine.suggestSlots(
            forMinutes: 60,
            startingFrom: makeDate(2026, 3, 6, 17, 30),
            days: 5,
            busyByDay: [:],
            limit: 2,
            calendar: testCalendar
        )
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertEqual(formattedDay(suggestions[0].start), "2026-03-09")
    }

    func testWorkloadRatio() {
        XCTAssertEqual(ScheduleEngine.workloadRatio(plannedMinutes: 270), 0.5, accuracy: 0.001)
        XCTAssertGreaterThan(ScheduleEngine.workloadRatio(plannedMinutes: 700), 1.0)
    }
}

final class StatsEngineTests: XCTestCase {

    func makeRecords() -> [CompletionRecord] {
        [
            CompletionRecord(date: makeDate(2026, 3, 2, 9, 30), xp: 20, focusMinutes: 25, priority: .p1, difficulty: .medium, lifeArea: .craft),
            CompletionRecord(date: makeDate(2026, 3, 2, 14, 0), xp: 35, focusMinutes: 0, priority: .p2, difficulty: .hard, lifeArea: .craft),
            CompletionRecord(date: makeDate(2026, 3, 3, 9, 15), xp: 10, focusMinutes: 50, priority: .p4, difficulty: .easy, lifeArea: .body),
            CompletionRecord(date: makeDate(2026, 3, 4, 9, 45), xp: 60, focusMinutes: 0, priority: .p1, difficulty: .epic, lifeArea: .mind, wasOnTime: false, isBoss: true),
            CompletionRecord(date: makeDate(2026, 3, 4, 21, 0), xp: 5, focusMinutes: 0, difficulty: .trivial, lifeArea: .home, isHabit: true)
        ]
    }

    func testTotalsAndAverages() {
        let stats = StatsEngine.compute(
            records: makeRecords(),
            from: makeDate(2026, 3, 2),
            to: makeDate(2026, 3, 4),
            calendar: testCalendar
        )
        XCTAssertEqual(stats.totalCompleted, 5)
        XCTAssertEqual(stats.totalXP, 130)
        XCTAssertEqual(stats.totalFocusMinutes, 75)
        XCTAssertEqual(stats.activeDays, 3)
        XCTAssertEqual(stats.bossesDefeated, 1)
        XCTAssertEqual(stats.habitsCompleted, 1)
        XCTAssertEqual(stats.onTimeRate, 0.8, accuracy: 0.001)
        XCTAssertEqual(stats.averagePerActiveDay, 5.0 / 3.0, accuracy: 0.001)
    }

    func testDailySeriesCoversEveryDayIncludingEmptyOnes() {
        let stats = StatsEngine.compute(
            records: makeRecords(),
            from: makeDate(2026, 3, 1),
            to: makeDate(2026, 3, 5),
            calendar: testCalendar
        )
        XCTAssertEqual(stats.daily.count, 5)
        XCTAssertEqual(stats.daily[0].completed, 0)
        XCTAssertEqual(stats.daily[1].completed, 2)
        XCTAssertEqual(stats.daily[3].completed, 2)
        XCTAssertEqual(stats.daily[4].completed, 0)
    }

    func testHourAndWeekdayBuckets() {
        let stats = StatsEngine.compute(
            records: makeRecords(),
            from: makeDate(2026, 3, 2),
            to: makeDate(2026, 3, 4),
            calendar: testCalendar
        )
        XCTAssertEqual(stats.byHour.count, 24)
        XCTAssertEqual(stats.byHour[9].value, 3)
        XCTAssertEqual(stats.byHour[21].value, 1)
        XCTAssertEqual(stats.bestHour, 9)

        XCTAssertEqual(stats.byWeekday.count, 7)
        // 2 mars 2026 est un lundi → index 1.
        XCTAssertEqual(stats.byWeekday[1].value, 2)
    }

    func testBreakdownsByAreaAndDifficulty() {
        let stats = StatsEngine.compute(
            records: makeRecords(),
            from: makeDate(2026, 3, 2),
            to: makeDate(2026, 3, 4),
            calendar: testCalendar
        )
        XCTAssertEqual(stats.byArea[.craft], 2)
        XCTAssertEqual(stats.byArea[.body], 1)
        XCTAssertEqual(stats.byDifficulty[.epic], 1)
        XCTAssertEqual(stats.byPriority[.p1], 2)
    }

    func testEmptyRangeStillReturnsSkeleton() {
        let stats = StatsEngine.compute(
            records: [],
            from: makeDate(2026, 3, 1),
            to: makeDate(2026, 3, 7),
            calendar: testCalendar
        )
        XCTAssertEqual(stats.totalCompleted, 0)
        XCTAssertEqual(stats.daily.count, 7)
        XCTAssertEqual(stats.byHour.count, 24)
        XCTAssertNil(stats.bestHour)
    }

    func testRollingAverageSmoothsTheCurve() {
        let points = (0..<10).map {
            DailyPoint(date: makeDate(2026, 3, 1).adding(days: $0, calendar: testCalendar), completed: 1, xp: $0 * 10, focusMinutes: 0)
        }
        let averaged = StatsEngine.rollingAverage(points, window: 3)
        XCTAssertEqual(averaged.count, 10)
        XCTAssertEqual(averaged[0], 0, accuracy: 0.001)
        XCTAssertEqual(averaged[2], 10, accuracy: 0.001)   // (0+10+20)/3
        XCTAssertEqual(averaged[9], 80, accuracy: 0.001)   // (70+80+90)/3
    }

    func testDaysToNextLevel() {
        let xp = LevelCurve.totalXP(toReach: 5)
        let needed = LevelCurve.xpToAdvance(from: 5)
        let days = StatsEngine.daysToNextLevel(totalXP: xp, averageXPPerDay: Double(needed) / 4.0)
        XCTAssertEqual(days, 4)
        XCTAssertNil(StatsEngine.daysToNextLevel(totalXP: xp, averageXPPerDay: 0))
    }

    func testWeekOverWeekChange() {
        var records: [CompletionRecord] = []
        // Semaine précédente : 2 quêtes le lundi 23 février.
        records.append(CompletionRecord(date: makeDate(2026, 2, 23, 10, 0), xp: 10))
        records.append(CompletionRecord(date: makeDate(2026, 2, 23, 11, 0), xp: 10))
        // Semaine en cours : 3 quêtes le lundi 2 mars.
        for hour in 9...11 {
            records.append(CompletionRecord(date: makeDate(2026, 3, 2, hour, 0), xp: 10))
        }
        let change = StatsEngine.weekOverWeekChange(
            records: records,
            reference: makeDate(2026, 3, 4, 12, 0),
            calendar: testCalendar
        )
        XCTAssertEqual(change ?? 0, 0.5, accuracy: 0.001)
    }
}

final class InsightEngineTests: XCTestCase {

    func testStreakAtRiskProducesAWarning() {
        let insights = InsightEngine.insights(
            stats: .empty,
            streak: StreakState(current: 1, isAtRisk: true),
            totalXP: 100,
            overdueCount: 0,
            calendar: testCalendar
        )
        XCTAssertTrue(insights.contains { $0.id == "streakRisk" && $0.tone == .warning })
    }

    func testOverdueInsightAdaptsItsAdvice() {
        let few = InsightEngine.insights(stats: .empty, streak: .empty, totalXP: 0, overdueCount: 2, calendar: testCalendar)
        let many = InsightEngine.insights(stats: .empty, streak: .empty, totalXP: 0, overdueCount: 12, calendar: testCalendar)
        XCTAssertTrue(few.contains { $0.id == "overdue" })
        XCTAssertNotEqual(
            few.first { $0.id == "overdue" }?.detail,
            many.first { $0.id == "overdue" }?.detail
        )
    }

    func testNoInsightsWithoutData() {
        let insights = InsightEngine.insights(stats: .empty, streak: .empty, totalXP: 0, overdueCount: 0, calendar: testCalendar)
        XCTAssertTrue(insights.isEmpty)
    }

    func testNeglectedAreasRanking() {
        var stats = ProductivityStats.empty
        stats.byArea = [.body: 10, .mind: 3, .craft: 25]
        let neglected = InsightEngine.neglectedAreas(stats: stats, limit: 2)
        XCTAssertEqual(neglected.count, 2)
        XCTAssertFalse(neglected.contains(.craft))
    }
}

final class DateSupportTests: XCTestCase {

    func testMonthGridAlwaysHas42Days() {
        for month in 1...12 {
            let grid = testCalendar.monthGrid(for: makeDate(2026, month, 15))
            XCTAssertEqual(grid.count, 42)
            // La grille commence toujours un lundi (firstWeekday = 2).
            XCTAssertEqual(testCalendar.component(.weekday, from: grid[0]), 2)
        }
    }

    func testWeekDaysStartOnMonday() {
        let week = testCalendar.weekDays(for: makeDate(2026, 3, 4)) // mercredi
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(formattedDay(week[0]), "2026-03-02")
        XCTAssertEqual(formattedDay(week[6]), "2026-03-08")
    }

    func testMinutesSinceMidnight() {
        XCTAssertEqual(makeDate(2026, 3, 4, 14, 30).minutesSinceMidnight(calendar: testCalendar), 870)
        XCTAssertEqual(makeDate(2026, 3, 4, 0, 0).minutesSinceMidnight(calendar: testCalendar), 0)
    }

    func testEndOfMonthHandlesEveryLength() {
        XCTAssertEqual(formattedDay(testCalendar.endOfMonth(makeDate(2026, 2, 10))), "2026-02-28")
        XCTAssertEqual(formattedDay(testCalendar.endOfMonth(makeDate(2028, 2, 10))), "2028-02-29")
        XCTAssertEqual(formattedDay(testCalendar.endOfMonth(makeDate(2026, 4, 10))), "2026-04-30")
    }

    func testDurationFormatting() {
        XCTAssertEqual(DurationFormatter.short(minutes: 90), "1 h 30")
        XCTAssertEqual(DurationFormatter.short(minutes: 120), "2 h")
        XCTAssertEqual(DurationFormatter.short(minutes: 45), "45 min")
        XCTAssertEqual(DurationFormatter.short(minutes: 0), "—")
        XCTAssertEqual(DurationFormatter.clock(seconds: 65), "01:05")
        XCTAssertEqual(DurationFormatter.clock(seconds: 3725), "1:02:05")
    }

    func testDaylightSavingTransitionKeepsDayCount() {
        // Passage à l'heure d'été en France : 29 mars 2026.
        let before = makeDate(2026, 3, 28, 12, 0)
        let after = makeDate(2026, 3, 30, 12, 0)
        XCTAssertEqual(testCalendar.daysBetween(before, after), 2)
        XCTAssertEqual(formattedDay(before.adding(days: 1, calendar: testCalendar)), "2026-03-29")
        XCTAssertEqual(formattedDay(before.adding(days: 2, calendar: testCalendar)), "2026-03-30")
    }

    func testRecurrenceSurvivesDaylightSaving() {
        // Une tâche à 9 h doit rester à 9 h après le changement d'heure.
        let anchor = makeDate(2026, 3, 27, 9, 0)
        let dates = RecurrenceEngine.occurrences(
            rule: .daily, anchor: anchor,
            from: anchor, to: testCalendar.endOfDay(makeDate(2026, 3, 31)), calendar: testCalendar
        )
        XCTAssertEqual(dates.map { formatted($0) }, [
            "2026-03-27 09:00",
            "2026-03-28 09:00",
            "2026-03-29 09:00",
            "2026-03-30 09:00",
            "2026-03-31 09:00"
        ])
    }
}
