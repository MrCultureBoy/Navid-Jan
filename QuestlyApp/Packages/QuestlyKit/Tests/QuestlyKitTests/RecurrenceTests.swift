import XCTest
@testable import QuestlyKit

final class RecurrenceTests: XCTestCase {

    // MARK: Quotidien

    func testDailyEveryDay() {
        let anchor = makeDate(2026, 3, 2, 9, 0)
        let next = RecurrenceEngine.nextDate(rule: .daily, after: anchor, anchor: anchor, calendar: testCalendar)
        XCTAssertEqual(formatted(next!), "2026-03-03 09:00")
    }

    func testDailyKeepsAnchorTime() {
        let anchor = makeDate(2026, 3, 2, 7, 45)
        let next = RecurrenceEngine.nextDate(rule: .daily, after: makeDate(2026, 3, 5, 23, 0), anchor: anchor, calendar: testCalendar)
        XCTAssertEqual(formatted(next!), "2026-03-06 07:45")
    }

    func testDailyEveryThreeDays() {
        let anchor = makeDate(2026, 3, 2, 8, 0)
        let rule = RecurrenceRule(frequency: .daily, interval: 3)
        let dates = RecurrenceEngine.occurrences(
            rule: rule, anchor: anchor,
            from: anchor, to: testCalendar.endOfDay(makeDate(2026, 3, 20)), calendar: testCalendar
        )
        XCTAssertEqual(dates.map { formattedDay($0) },
                       ["2026-03-02", "2026-03-05", "2026-03-08", "2026-03-11", "2026-03-14", "2026-03-17", "2026-03-20"])
    }

    func testWeekdaysOnlySkipsWeekend() {
        // 2026-03-06 est un vendredi.
        let anchor = makeDate(2026, 3, 6, 9, 0)
        let next = RecurrenceEngine.nextDate(rule: .weekdaysOnly, after: anchor, anchor: anchor, calendar: testCalendar)
        XCTAssertEqual(formattedDay(next!), "2026-03-09", "Après vendredi vient lundi")
    }

    func testWeekdaysOnlyNeverLandsOnWeekend() {
        let anchor = makeDate(2026, 3, 2, 9, 0)
        let dates = RecurrenceEngine.occurrences(
            rule: .weekdaysOnly, anchor: anchor,
            from: anchor, to: testCalendar.endOfDay(makeDate(2026, 3, 31)), calendar: testCalendar
        )
        XCTAssertEqual(dates.count, 22)
        for date in dates {
            XCTAssertFalse(testCalendar.isWeekend(date), "\(formattedDay(date)) ne doit pas être un week-end")
        }
    }

    // MARK: Hebdomadaire

    func testWeeklyOnSpecificDays() {
        // Lundi (2) et jeudi (5).
        let anchor = makeDate(2026, 3, 2, 18, 30) // lundi
        let rule = RecurrenceRule(frequency: .weekly, weekdays: [2, 5])
        let dates = RecurrenceEngine.occurrences(
            rule: rule, anchor: anchor,
            from: anchor, to: testCalendar.endOfDay(makeDate(2026, 3, 16)), calendar: testCalendar
        )
        XCTAssertEqual(dates.map { formattedDay($0) },
                       ["2026-03-02", "2026-03-05", "2026-03-09", "2026-03-12", "2026-03-16"])
        XCTAssertEqual(formatted(dates[1]), "2026-03-05 18:30", "L'heure de l'ancre est conservée")
    }

    func testWeeklyEveryTwoWeeks() {
        let anchor = makeDate(2026, 3, 2, 9, 0) // lundi
        let rule = RecurrenceRule(frequency: .weekly, interval: 2)
        let dates = RecurrenceEngine.occurrences(
            rule: rule, anchor: anchor,
            from: anchor, to: testCalendar.endOfDay(makeDate(2026, 4, 30)), calendar: testCalendar
        )
        XCTAssertEqual(dates.map { formattedDay($0) },
                       ["2026-03-02", "2026-03-16", "2026-03-30", "2026-04-13", "2026-04-27"])
    }

    func testWeeklyDefaultsToAnchorWeekday() {
        let anchor = makeDate(2026, 3, 4, 9, 0) // mercredi
        let next = RecurrenceEngine.nextDate(rule: .weekly, after: anchor, anchor: anchor, calendar: testCalendar)
        XCTAssertEqual(formattedDay(next!), "2026-03-11")
    }

    // MARK: Mensuel

    func testMonthlyOnAnchorDay() {
        let anchor = makeDate(2026, 1, 15, 10, 0)
        let dates = RecurrenceEngine.occurrences(
            rule: .monthly, anchor: anchor,
            from: anchor, to: testCalendar.endOfDay(makeDate(2026, 5, 30)), calendar: testCalendar
        )
        XCTAssertEqual(dates.map { formattedDay($0) },
                       ["2026-01-15", "2026-02-15", "2026-03-15", "2026-04-15", "2026-05-15"])
    }

    func testMonthlyClampsToShortMonths() {
        // Le 31 janvier doit tomber sur le 28 février (2026 n'est pas bissextile).
        let anchor = makeDate(2026, 1, 31, 9, 0)
        let dates = RecurrenceEngine.occurrences(
            rule: .monthly, anchor: anchor,
            from: anchor, to: testCalendar.endOfDay(makeDate(2026, 4, 30)), calendar: testCalendar
        )
        XCTAssertEqual(dates.map { formattedDay($0) },
                       ["2026-01-31", "2026-02-28", "2026-03-31", "2026-04-30"])
    }

    func testMonthlyLastDayOfMonth() {
        let anchor = makeDate(2026, 1, 5, 9, 0)
        let rule = RecurrenceRule(frequency: .monthly, daysOfMonth: [-1])
        let dates = RecurrenceEngine.occurrences(
            rule: rule, anchor: anchor,
            from: anchor, to: testCalendar.endOfDay(makeDate(2026, 4, 30)), calendar: testCalendar
        )
        XCTAssertEqual(dates.map { formattedDay($0) },
                       ["2026-01-31", "2026-02-28", "2026-03-31", "2026-04-30"])
    }

    func testMonthlyEveryThreeMonths() {
        let anchor = makeDate(2026, 1, 10, 9, 0)
        let rule = RecurrenceRule(frequency: .monthly, interval: 3)
        let dates = RecurrenceEngine.occurrences(
            rule: rule, anchor: anchor,
            from: anchor, to: testCalendar.endOfDay(makeDate(2026, 12, 31)), calendar: testCalendar
        )
        XCTAssertEqual(dates.map { formattedDay($0) },
                       ["2026-01-10", "2026-04-10", "2026-07-10", "2026-10-10"])
    }

    // MARK: Annuel

    func testYearlyOnAnchorDate() {
        let anchor = makeDate(2026, 6, 21, 12, 0)
        let dates = RecurrenceEngine.occurrences(
            rule: .yearly, anchor: anchor,
            from: anchor, to: testCalendar.endOfDay(makeDate(2029, 12, 31)), calendar: testCalendar
        )
        XCTAssertEqual(dates.map { formattedDay($0) },
                       ["2026-06-21", "2027-06-21", "2028-06-21", "2029-06-21"])
    }

    func testYearlyLeapDayFallsBackToLastDay() {
        // 29 février 2028 (bissextile) → 28 février les années normales.
        let anchor = makeDate(2028, 2, 29, 9, 0)
        let dates = RecurrenceEngine.occurrences(
            rule: .yearly, anchor: anchor,
            from: anchor, to: testCalendar.endOfDay(makeDate(2030, 12, 31)), calendar: testCalendar
        )
        XCTAssertEqual(dates.map { formattedDay($0) },
                       ["2028-02-29", "2029-02-28", "2030-02-28"])
    }

    // MARK: Fins de série

    func testEndingAfterOccurrences() {
        let anchor = makeDate(2026, 3, 2, 9, 0)
        let rule = RecurrenceRule(frequency: .daily, ending: .afterOccurrences(3))
        let dates = RecurrenceEngine.occurrences(
            rule: rule, anchor: anchor,
            from: anchor, to: testCalendar.endOfDay(makeDate(2026, 3, 31)), calendar: testCalendar
        )
        XCTAssertEqual(dates.map { formattedDay($0) }, ["2026-03-02", "2026-03-03", "2026-03-04"])

        // Après la troisième occurrence, plus rien.
        let after = RecurrenceEngine.nextDate(rule: rule, after: makeDate(2026, 3, 4, 10, 0), anchor: anchor, calendar: testCalendar)
        XCTAssertNil(after)
    }

    func testEndingOnDate() {
        let anchor = makeDate(2026, 3, 2, 9, 0)
        let rule = RecurrenceRule(frequency: .daily, ending: .onDate(makeDate(2026, 3, 5)))
        let dates = RecurrenceEngine.occurrences(
            rule: rule, anchor: anchor,
            from: anchor, to: testCalendar.endOfDay(makeDate(2026, 3, 31)), calendar: testCalendar
        )
        XCTAssertEqual(dates.map { formattedDay($0) },
                       ["2026-03-02", "2026-03-03", "2026-03-04", "2026-03-05"])
        XCTAssertNil(RecurrenceEngine.nextDate(rule: rule, after: makeDate(2026, 3, 5, 10, 0), anchor: anchor, calendar: testCalendar))
    }

    // MARK: Mode « après accomplissement »

    func testAfterCompletionRestartsFromCompletionDate() {
        let anchor = makeDate(2026, 3, 2, 9, 0)
        let rule = RecurrenceRule(frequency: .daily, interval: 7, mode: .afterCompletion)
        // Tâche accomplie avec 5 jours de retard : la suivante part de là.
        let next = RecurrenceEngine.nextDate(rule: rule, after: makeDate(2026, 3, 7, 20, 0), anchor: anchor, calendar: testCalendar)
        XCTAssertEqual(formatted(next!), "2026-03-14 09:00")
    }

    func testAfterCompletionWithWeeklyInterval() {
        let anchor = makeDate(2026, 3, 2, 18, 0)
        let rule = RecurrenceRule(frequency: .weekly, interval: 2, mode: .afterCompletion)
        let next = RecurrenceEngine.nextDate(rule: rule, after: makeDate(2026, 3, 10, 12, 0), anchor: anchor, calendar: testCalendar)
        XCTAssertEqual(formatted(next!), "2026-03-24 18:00")
    }

    func testAfterCompletionSkipsWeekend() {
        let anchor = makeDate(2026, 3, 2, 9, 0)
        let rule = RecurrenceRule(frequency: .daily, interval: 1, mode: .afterCompletion, skipWeekends: true)
        // Accomplie un vendredi → la suivante saute au lundi.
        let next = RecurrenceEngine.nextDate(rule: rule, after: makeDate(2026, 3, 6, 17, 0), anchor: anchor, calendar: testCalendar)
        XCTAssertEqual(formattedDay(next!), "2026-03-09")
    }

    // MARK: Divers

    func testMatchesRejectsDatesBeforeAnchor() {
        let anchor = makeDate(2026, 3, 10)
        XCTAssertFalse(RecurrenceEngine.matches(rule: .daily, date: makeDate(2026, 3, 9), anchor: anchor, calendar: testCalendar))
        XCTAssertTrue(RecurrenceEngine.matches(rule: .daily, date: makeDate(2026, 3, 10), anchor: anchor, calendar: testCalendar))
    }

    func testCountOccurrencesIsTimeAware() {
        let anchor = makeDate(2026, 3, 2, 18, 0)
        // À midi le 2 mars, l'occurrence de 18 h n'a pas encore eu lieu.
        XCTAssertEqual(
            RecurrenceEngine.countOccurrences(rule: .daily, from: anchor, upTo: makeDate(2026, 3, 2, 12, 0), calendar: testCalendar),
            0
        )
        XCTAssertEqual(
            RecurrenceEngine.countOccurrences(rule: .daily, from: anchor, upTo: makeDate(2026, 3, 2, 19, 0), calendar: testCalendar),
            1
        )
        XCTAssertEqual(
            RecurrenceEngine.countOccurrences(rule: .daily, from: anchor, upTo: makeDate(2026, 3, 5, 19, 0), calendar: testCalendar),
            4
        )
    }

    func testWeekendsOnlyPreset() {
        let anchor = makeDate(2026, 3, 2, 9, 0) // lundi
        let dates = RecurrenceEngine.occurrences(
            rule: .weekendsOnly, anchor: anchor,
            from: anchor, to: testCalendar.endOfDay(makeDate(2026, 3, 16)), calendar: testCalendar
        )
        for date in dates {
            XCTAssertTrue(testCalendar.isWeekend(date))
        }
        XCTAssertEqual(dates.map { formattedDay($0) },
                       ["2026-03-07", "2026-03-08", "2026-03-14", "2026-03-15"])
    }

    func testHumanDescriptionsAreReadable() {
        XCTAssertEqual(RecurrenceRule.daily.humanDescription(calendar: testCalendar), "Chaque jour")
        XCTAssertEqual(RecurrenceRule(frequency: .daily, interval: 3).humanDescription(calendar: testCalendar), "Tous les 3 jours")
        XCTAssertEqual(RecurrenceRule.weekdaysOnly.humanDescription(calendar: testCalendar), "Chaque jour ouvré")
        XCTAssertEqual(
            RecurrenceRule(frequency: .weekly, weekdays: [2, 5]).humanDescription(calendar: testCalendar),
            "Chaque semaine, le lundi et jeudi"
        )
        XCTAssertEqual(
            RecurrenceRule(frequency: .monthly, daysOfMonth: [-1]).humanDescription(calendar: testCalendar),
            "Chaque mois, le dernier jour"
        )
        XCTAssertTrue(
            RecurrenceRule(frequency: .daily, ending: .afterOccurrences(5)).humanDescription(calendar: testCalendar)
                .contains("5 fois")
        )
    }

    func testOccurrencesRespectsLimit() {
        let anchor = makeDate(2026, 1, 1, 9, 0)
        let dates = RecurrenceEngine.occurrences(
            rule: .daily, anchor: anchor,
            from: anchor, to: testCalendar.endOfDay(makeDate(2026, 12, 31)), calendar: testCalendar, limit: 10
        )
        XCTAssertEqual(dates.count, 10)
    }

    func testCodableRoundTrip() throws {
        let rule = RecurrenceRule(
            frequency: .monthly,
            interval: 2,
            weekdays: [2, 4],
            daysOfMonth: [1, -1],
            monthsOfYear: [3, 9],
            ending: .onDate(makeDate(2027, 1, 1)),
            mode: .afterCompletion,
            skipWeekends: true
        )
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(RecurrenceRule.self, from: data)
        XCTAssertEqual(rule, decoded)
    }
}
