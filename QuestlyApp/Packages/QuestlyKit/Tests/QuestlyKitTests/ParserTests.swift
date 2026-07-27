import XCTest
@testable import QuestlyKit

final class NaturalLanguageParserTests: XCTestCase {

    /// Mercredi 4 mars 2026, 10 h 00.
    let reference = makeDate(2026, 3, 4, 10, 0)

    func parse(_ text: String) -> ParsedInput {
        NaturalLanguageParser.parse(text, reference: reference, calendar: testCalendar)
    }

    // MARK: Texte simple

    func testPlainTextKeepsTitleIntact() {
        let result = parse("Réfléchir à la suite")
        XCTAssertEqual(result.title, "Réfléchir à la suite")
        XCTAssertNil(result.dueDate)
        XCTAssertFalse(result.hasMetadata)
    }

    func testEmptyInput() {
        let result = parse("   ")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: Dates relatives

    func testTomorrow() {
        let result = parse("Acheter du pain demain")
        XCTAssertEqual(result.title, "Acheter du pain")
        XCTAssertEqual(formattedDay(result.dueDate!), "2026-03-05")
        XCTAssertFalse(result.hasTime)
    }

    func testToday() {
        let result = parse("Ranger le bureau aujourd'hui")
        XCTAssertEqual(formattedDay(result.dueDate!), "2026-03-04")
        XCTAssertEqual(result.title, "Ranger le bureau")
    }

    func testDayAfterTomorrow() {
        XCTAssertEqual(formattedDay(parse("Relire après-demain").dueDate!), "2026-03-06")
    }

    func testInNDays() {
        XCTAssertEqual(formattedDay(parse("Relancer dans 3 jours").dueDate!), "2026-03-07")
        XCTAssertEqual(formattedDay(parse("Bilan dans 2 semaines").dueDate!), "2026-03-18")
        XCTAssertEqual(formattedDay(parse("Renouveler dans 1 mois").dueDate!), "2026-04-04")
    }

    func testEnglishRelativeDates() {
        XCTAssertEqual(formattedDay(parse("Call mom tomorrow").dueDate!), "2026-03-05")
        XCTAssertEqual(formattedDay(parse("Ship it in 5 days").dueDate!), "2026-03-09")
    }

    func testWeekdayPicksNextOccurrence() {
        // Mercredi 4 → samedi 7.
        XCTAssertEqual(formattedDay(parse("Faire les courses samedi").dueDate!), "2026-03-07")
        // Mercredi 4 → lundi 9.
        XCTAssertEqual(formattedDay(parse("Envoyer le rapport lundi").dueDate!), "2026-03-09")
    }

    func testWeekdayTodayCountsAsToday() {
        // On est mercredi : « mercredi » veut dire aujourd'hui.
        XCTAssertEqual(formattedDay(parse("Point équipe mercredi").dueDate!), "2026-03-04")
        // Sauf si on précise « prochain ».
        XCTAssertEqual(formattedDay(parse("Point équipe mercredi prochain").dueDate!), "2026-03-11")
    }

    func testNextWeekAndMonth() {
        XCTAssertEqual(formattedDay(parse("Préparer la semaine prochaine").dueDate!), "2026-03-09")
        XCTAssertEqual(formattedDay(parse("Payer le mois prochain").dueDate!), "2026-04-01")
    }

    func testEndOfMonth() {
        XCTAssertEqual(formattedDay(parse("Clôturer fin du mois").dueDate!), "2026-03-31")
    }

    // MARK: Dates absolues

    func testNumericDate() {
        let result = parse("Rendez-vous 15/03")
        XCTAssertEqual(formattedDay(result.dueDate!), "2026-03-15")
        XCTAssertEqual(result.title, "Rendez-vous")
    }

    func testNumericDateWithYear() {
        XCTAssertEqual(formattedDay(parse("Anniversaire 12/09/2027").dueDate!), "2027-09-12")
    }

    func testPastDateRollsToNextYear() {
        // Le 3 mars est déjà passé : on vise l'an prochain.
        XCTAssertEqual(formattedDay(parse("Déclarer 03/03").dueDate!), "2027-03-03")
    }

    func testWrittenMonth() {
        XCTAssertEqual(formattedDay(parse("Réserver le 20 mars").dueDate!), "2026-03-20")
        XCTAssertEqual(formattedDay(parse("Poisson le 1er avril").dueDate!), "2026-04-01")
        XCTAssertEqual(formattedDay(parse("Deadline 15 december").dueDate!), "2026-12-15")
    }

    // MARK: Heures

    func testTimeFrenchFormat() {
        let result = parse("Appeler le dentiste demain 14h30")
        XCTAssertEqual(formatted(result.dueDate!), "2026-03-05 14:30")
        XCTAssertTrue(result.hasTime)
        XCTAssertEqual(result.title, "Appeler le dentiste")
    }

    func testTimeWithoutMinutes() {
        XCTAssertEqual(formatted(parse("Sport demain 18h").dueDate!), "2026-03-05 18:00")
    }

    func testTimeColonFormat() {
        XCTAssertEqual(formatted(parse("Visio demain à 09:15").dueDate!), "2026-03-05 09:15")
    }

    func testTimeAmPm() {
        XCTAssertEqual(formatted(parse("Standup tomorrow 9am").dueDate!), "2026-03-05 09:00")
        XCTAssertEqual(formatted(parse("Dinner tomorrow 7:30pm").dueDate!), "2026-03-05 19:30")
    }

    func testPastTimeWithoutDateRollsToTomorrow() {
        // Il est 10 h : « 9h » vise demain.
        XCTAssertEqual(formatted(parse("Courir à 9h").dueDate!), "2026-03-05 09:00")
        // Alors que 15 h tient encore aujourd'hui.
        XCTAssertEqual(formatted(parse("Courir à 15h").dueDate!), "2026-03-04 15:00")
    }

    func testMomentsOfDayStayToday() {
        XCTAssertEqual(formatted(parse("Sortir la poubelle ce soir").dueDate!), "2026-03-04 19:00")
        XCTAssertEqual(formatted(parse("Réveil ce matin").dueDate!), "2026-03-04 09:00")
    }

    // MARK: Durées

    func testExplicitDuration() {
        XCTAssertEqual(parse("Réviser pendant 2h").durationMinutes, 120)
        XCTAssertEqual(parse("Marcher pour 45 min").durationMinutes, 45)
        XCTAssertEqual(parse("Écrire pendant 1h30").durationMinutes, 90)
    }

    func testBareMinuteDuration() {
        XCTAssertEqual(parse("Méditer 20min").durationMinutes, 20)
        XCTAssertEqual(parse("Pause 15 minutes").durationMinutes, 15)
    }

    func testSpelledHours() {
        XCTAssertEqual(parse("Atelier 3 heures").durationMinutes, 180)
    }

    func testHourFormatIsATimeNotADuration() {
        // « 14h » est une heure, pas 14 heures de travail.
        let result = parse("Réunion 14h")
        XCTAssertNil(result.durationMinutes)
        XCTAssertTrue(result.hasTime)
    }

    func testDurationAndTimeTogether() {
        let result = parse("Sport demain 18h pendant 45min")
        XCTAssertEqual(formatted(result.dueDate!), "2026-03-05 18:00")
        XCTAssertEqual(result.durationMinutes, 45)
        XCTAssertEqual(result.title, "Sport")
    }

    func testMonthNameIsNotEatenByDuration() {
        // « 12 mars » ne doit pas devenir « 12 minutes ».
        let result = parse("Rendez-vous le 12 mars")
        XCTAssertNil(result.durationMinutes)
        XCTAssertEqual(formattedDay(result.dueDate!), "2026-03-12")
    }

    // MARK: Priorité, difficulté, domaine, boss

    func testPriorityShorthand() {
        XCTAssertEqual(parse("Payer le loyer p1").priority, .p1)
        XCTAssertEqual(parse("Trier les photos !4").priority, .p4)
        XCTAssertEqual(parse("Réparer la fuite urgent").priority, .p1)
        XCTAssertEqual(parse("Relire le contrat important").priority, .p2)
        XCTAssertNil(parse("Arroser les plantes").priority)
    }

    func testDifficultyMarker() {
        XCTAssertEqual(parse("Refonte du site *épique").difficulty, .epic)
        XCTAssertEqual(parse("Vider la boîte mail *facile").difficulty, .easy)
        XCTAssertEqual(parse("Thèse *légendaire").difficulty, .legendary)
    }

    func testAreaMarker() {
        XCTAssertEqual(parse("Lire 30 pages %esprit").lifeArea, .mind)
        XCTAssertEqual(parse("Squats %corps").lifeArea, .body)
    }

    func testBossMarker() {
        let result = parse("!boss Terminer la refonte")
        XCTAssertTrue(result.isBoss)
        XCTAssertEqual(result.title, "Terminer la refonte")
    }

    // MARK: Étiquettes et projets

    func testTags() {
        let result = parse("Acheter du lait #courses #maison")
        XCTAssertEqual(result.tags, ["courses", "maison"])
        XCTAssertEqual(result.title, "Acheter du lait")
    }

    func testContextBecomesTag() {
        let result = parse("Imprimer le dossier @bureau")
        XCTAssertEqual(result.tags, ["bureau"])
        XCTAssertEqual(result.title, "Imprimer le dossier")
    }

    func testAccentedTags() {
        XCTAssertEqual(parse("Réviser #mathématiques").tags, ["mathématiques"])
    }

    func testProject() {
        let result = parse("Maquette d'accueil +RefonteSite")
        XCTAssertEqual(result.project, "RefonteSite")
        XCTAssertEqual(result.title, "Maquette d'accueil")
    }

    // MARK: Récurrence

    func testDailyRecurrence() {
        let result = parse("Boire de l'eau tous les jours")
        XCTAssertEqual(result.recurrence?.frequency, .daily)
        XCTAssertEqual(result.recurrence?.interval, 1)
        XCTAssertEqual(result.title, "Boire de l'eau")
    }

    func testIntervalRecurrence() {
        let result = parse("Arroser les plantes tous les 3 jours")
        XCTAssertEqual(result.recurrence?.frequency, .daily)
        XCTAssertEqual(result.recurrence?.interval, 3)
    }

    func testWeekdayRecurrenceSetsFirstOccurrence() {
        let result = parse("Yoga chaque lundi 9h")
        XCTAssertEqual(result.recurrence?.frequency, .weekly)
        XCTAssertEqual(result.recurrence?.weekdays, [2])
        // Premier lundi à venir, pas « demain ».
        XCTAssertEqual(formatted(result.dueDate!), "2026-03-09 09:00")
        XCTAssertEqual(result.title, "Yoga")
    }

    func testWeekdaysOnlyRecurrence() {
        let result = parse("Revue de code en semaine")
        XCTAssertEqual(result.recurrence, .weekdaysOnly)
        XCTAssertEqual(formattedDay(result.dueDate!), "2026-03-04")
    }

    func testMonthlyDayOfMonth() {
        let result = parse("Payer le loyer le 5 du mois")
        XCTAssertEqual(result.recurrence?.frequency, .monthly)
        XCTAssertEqual(result.recurrence?.daysOfMonth, [5])
        XCTAssertEqual(formattedDay(result.dueDate!), "2026-03-05")
    }

    func testEnglishRecurrence() {
        XCTAssertEqual(parse("Water plants every 2 weeks").recurrence?.interval, 2)
        XCTAssertEqual(parse("Water plants every 2 weeks").recurrence?.frequency, .weekly)
        XCTAssertEqual(parse("Weekly review").recurrence?.frequency, .weekly)
    }

    func testRecurrenceBeatsPlainWeekday() {
        // « tous les lundis » ne doit pas être lu comme la date « lundi ».
        let result = parse("Sortir les poubelles tous les lundis")
        XCTAssertEqual(result.recurrence?.weekdays, [2])
        XCTAssertEqual(result.title, "Sortir les poubelles")
    }

    // MARK: Rappels

    func testReminderOffset() {
        let result = parse("Visio demain 15h rappel 30min avant")
        XCTAssertEqual(result.reminderMinutesBefore, 30)
        XCTAssertEqual(formatted(result.dueDate!), "2026-03-05 15:00")
        XCTAssertEqual(result.title, "Visio")
    }

    func testReminderInHours() {
        XCTAssertEqual(parse("Train demain 8h rappel 2h avant").reminderMinutesBefore, 120)
    }

    // MARK: Déduction du domaine

    func testAreaInferredFromKeywords() {
        XCTAssertEqual(parse("Aller à la gym demain").lifeArea, .body)
        XCTAssertEqual(parse("Payer la facture EDF").lifeArea, .wealth)
        XCTAssertEqual(parse("Faire la vaisselle").lifeArea, .home)
        XCTAssertEqual(parse("Réunion client jeudi").lifeArea, .craft)
    }

    func testExplicitAreaBeatsInference() {
        XCTAssertEqual(parse("Faire la vaisselle %corps").lifeArea, .body)
    }

    // MARK: Cas composés

    func testKitchenSink() {
        let result = parse("!boss Refonte du site +Site #design p1 demain 14h pendant 2h *épique rappel 15min avant")
        XCTAssertTrue(result.isBoss)
        XCTAssertEqual(result.project, "Site")
        XCTAssertEqual(result.tags, ["design"])
        XCTAssertEqual(result.priority, .p1)
        XCTAssertEqual(result.difficulty, .epic)
        XCTAssertEqual(result.durationMinutes, 120)
        XCTAssertEqual(result.reminderMinutesBefore, 15)
        XCTAssertEqual(formatted(result.dueDate!), "2026-03-05 14:00")
        XCTAssertEqual(result.title, "Refonte du site")
    }

    func testTokensAreOrderedAndPositioned() {
        let text = "Courses demain #maison"
        let result = parse(text)
        XCTAssertEqual(result.tokens.count, 2)
        XCTAssertEqual(result.tokens[0].kind, .date)
        XCTAssertEqual(result.tokens[1].kind, .tag)
        for token in result.tokens {
            let ns = text as NSString
            XCTAssertEqual(ns.substring(with: NSRange(location: token.location, length: token.length)), token.text)
        }
    }

    func testTitleWhitespaceIsCollapsed() {
        let result = parse("Ranger    le   garage   samedi")
        XCTAssertEqual(result.title, "Ranger le garage")
    }

    func testParsingIsStable() {
        // Deux analyses identiques donnent le même résultat.
        let a = parse("Sport demain 18h #santé p2")
        let b = parse("Sport demain 18h #santé p2")
        XCTAssertEqual(a, b)
    }
}
