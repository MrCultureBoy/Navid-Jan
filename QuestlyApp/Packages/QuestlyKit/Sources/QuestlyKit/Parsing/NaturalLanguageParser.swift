import Foundation

/// Analyseur de saisie rapide, bilingue français / anglais.
///
/// Conventions retenues (documentées dans l'écran d'aide de l'app) :
/// - `#étiquette`, `@contexte`, `+projet`
/// - `p1`…`p4` ou `!1`…`!4` pour la priorité, `urgent` → P1
/// - `*facile`, `*ardu`, `*épique`, `*légendaire` pour la difficulté
/// - `%corps`, `%esprit`… pour le domaine de vie
/// - `!boss` pour marquer un boss
/// - `9h`, `14h30`, `14:30`, `2pm` sont des **heures**
/// - `30min`, `2 heures`, `pendant 1h30` sont des **durées**
public enum NaturalLanguageParser {

    // MARK: - Entrée principale

    public static func parse(
        _ input: String,
        reference: Date = Date(),
        calendar: Calendar = .questly()
    ) -> ParsedInput {
        var result = ParsedInput()
        let ns = input as NSString
        var consumed: [NSRange] = []

        // L'ordre compte : la récurrence avale « tous les lundis » avant que le
        // parseur de dates ne voie « lundi ».
        parseRecurrence(ns, &consumed, &result, calendar: calendar)
        parseReminder(ns, &consumed, &result)
        parseDuration(ns, &consumed, &result)
        let time = parseTime(ns, &consumed, &result)
        let day = parseDate(ns, &consumed, &result, reference: reference, calendar: calendar)
        parsePriority(ns, &consumed, &result)
        parseDifficulty(ns, &consumed, &result)
        parseArea(ns, &consumed, &result)
        parseBoss(ns, &consumed, &result)
        parseTags(ns, &consumed, &result)
        parseProject(ns, &consumed, &result)

        applyDueDate(day: day, time: time, reference: reference, calendar: calendar, into: &result)

        // « chaque lundi 9 h » sans date explicite : l'échéance est la première
        // occurrence réelle de la règle, pas demain matin.
        if let rule = result.recurrence, day == nil {
            applyFirstOccurrence(of: rule, time: time, reference: reference, calendar: calendar, into: &result)
        }

        // Domaine déduit des étiquettes si rien d'explicite.
        if result.lifeArea == nil {
            result.lifeArea = inferArea(from: result.tags, title: input)
        }

        result.title = cleanTitle(ns, consumed: consumed)
        result.tokens.sort { $0.location < $1.location }
        return result
    }

    // MARK: - Récurrence

    static func parseRecurrence(
        _ ns: NSString,
        _ consumed: inout [NSRange],
        _ result: inout ParsedInput,
        calendar: Calendar
    ) {
        // « tous les 2 jours », « toutes les 3 semaines », « every 2 weeks »
        if let m = firstMatch(
            #"\b(?:tou(?:s|tes)\s+les|every|chaque)\s+(\d+)\s*(jours?|semaines?|mois|ans?|années?|days?|weeks?|months?|years?)\b"#,
            in: ns, avoiding: consumed
        ) {
            let count = Int(group(m, 1, ns)) ?? 1
            let unit = group(m, 2, ns).lowercased()
            let frequency = frequencyFor(unit: unit)
            result.recurrence = RecurrenceRule(frequency: frequency, interval: count)
            record(.recurrence, m.range, ns, display: result.recurrence?.humanDescription(calendar: calendar) ?? "", into: &result, consumed: &consumed)
            return
        }

        // « chaque lundi », « tous les lundis », « every monday »
        if let m = firstMatch(
            #"\b(?:chaque|tous\s+les|toutes\s+les|every)\s+(lundis?|mardis?|mercredis?|jeudis?|vendredis?|samedis?|dimanches?|mondays?|tuesdays?|wednesdays?|thursdays?|fridays?|saturdays?|sundays?)\b"#,
            in: ns, avoiding: consumed
        ) {
            let name = group(m, 1, ns).lowercased()
            if let weekday = weekdayNumber(for: name) {
                result.recurrence = RecurrenceRule(frequency: .weekly, weekdays: [weekday])
                record(.recurrence, m.range, ns, display: result.recurrence?.humanDescription(calendar: calendar) ?? "", into: &result, consumed: &consumed)
                return
            }
        }

        // « tous les 15 du mois »
        if let m = firstMatch(
            #"\b(?:tous\s+les|le)\s+(\d{1,2})\s+du\s+mois\b"#,
            in: ns, avoiding: consumed
        ) {
            let day = Int(group(m, 1, ns)) ?? 1
            result.recurrence = RecurrenceRule(frequency: .monthly, daysOfMonth: [day])
            record(.recurrence, m.range, ns, display: result.recurrence?.humanDescription(calendar: calendar) ?? "", into: &result, consumed: &consumed)
            return
        }

        struct SimplePattern {
            let regex: String
            let rule: RecurrenceRule
        }

        let simple: [SimplePattern] = [
            SimplePattern(regex: #"\b(?:en\s+semaine|jours?\s+ouvr[ée]s?|weekdays?)\b"#, rule: .weekdaysOnly),
            SimplePattern(regex: #"\b(?:le\s+week-?ends?|les\s+week-?ends|weekends?)\b"#, rule: .weekendsOnly),
            SimplePattern(regex: #"\b(?:tous\s+les\s+jours|chaque\s+jour|quotidien(?:ne)?|every\s*day|daily)\b"#, rule: .daily),
            SimplePattern(regex: #"\b(?:toutes\s+les\s+semaines|chaque\s+semaine|hebdo(?:madaire)?|every\s*week|weekly)\b"#, rule: .weekly),
            SimplePattern(regex: #"\b(?:tous\s+les\s+mois|chaque\s+mois|mensuel(?:le)?|every\s*month|monthly)\b"#, rule: .monthly),
            SimplePattern(regex: #"\b(?:tous\s+les\s+ans|chaque\s+ann[ée]e|annuel(?:le)?|every\s*year|yearly|annually)\b"#, rule: .yearly)
        ]

        for pattern in simple {
            if let m = firstMatch(pattern.regex, in: ns, avoiding: consumed) {
                result.recurrence = pattern.rule
                record(.recurrence, m.range, ns, display: pattern.rule.humanDescription(calendar: calendar), into: &result, consumed: &consumed)
                return
            }
        }
    }

    static func frequencyFor(unit: String) -> RecurrenceRule.Frequency {
        if unit.hasPrefix("sem") || unit.hasPrefix("week") { return .weekly }
        if unit.hasPrefix("mois") || unit.hasPrefix("month") { return .monthly }
        if unit.hasPrefix("an") || unit.hasPrefix("ann") || unit.hasPrefix("year") { return .yearly }
        return .daily
    }

    // MARK: - Rappel

    static func parseReminder(_ ns: NSString, _ consumed: inout [NSRange], _ result: inout ParsedInput) {
        guard let m = firstMatch(
            #"\b(?:rappel|rappelle[- ]moi|remind(?:er)?)\s*(\d+)\s*(m|min|mins|minutes?|h|heures?|hours?)\s*(?:avant|before)?\b"#,
            in: ns, avoiding: consumed
        ) else { return }
        let value = Int(group(m, 1, ns)) ?? 0
        let unit = group(m, 2, ns).lowercased()
        let minutes = unit.hasPrefix("h") ? value * 60 : value
        guard minutes > 0 else { return }
        result.reminderMinutesBefore = minutes
        record(.reminder, m.range, ns, display: "Rappel \(DurationFormatter.short(minutes: minutes)) avant", into: &result, consumed: &consumed)
    }

    // MARK: - Durée

    static func parseDuration(_ ns: NSString, _ consumed: inout [NSRange], _ result: inout ParsedInput) {
        // Durée explicite : « pendant 1h30 », « pour 45 min », « for 2 hours »
        if let m = firstMatch(
            #"\b(?:pendant|pour|dur[ée]e\s*(?:de)?|dure|for|~|≈)\s*(\d{1,3})\s*(h|heures?|hrs?|hours?|m|min|mins|minutes?)\s*(\d{1,2})?\b"#,
            in: ns, avoiding: consumed
        ) {
            let value = Int(group(m, 1, ns)) ?? 0
            let unit = group(m, 2, ns).lowercased()
            let extra = Int(group(m, 3, ns)) ?? 0
            let minutes = unit.hasPrefix("h") ? value * 60 + extra : value
            if minutes > 0 {
                result.durationMinutes = minutes
                record(.duration, m.range, ns, display: DurationFormatter.short(minutes: minutes), into: &result, consumed: &consumed)
                return
            }
        }

        // Durée en minutes : « 30min », « 45 m »
        if let m = firstMatch(
            #"\b(\d{1,3})\s*(?:min|mins|minutes?|m)\b"#,
            in: ns, avoiding: consumed
        ) {
            let minutes = Int(group(m, 1, ns)) ?? 0
            if minutes > 0 {
                result.durationMinutes = minutes
                record(.duration, m.range, ns, display: DurationFormatter.short(minutes: minutes), into: &result, consumed: &consumed)
                return
            }
        }

        // Durée en heures écrites en toutes lettres : « 2 heures », « 3 hours »
        if let m = firstMatch(
            #"\b(\d{1,2})\s*(?:heures?|hours?|hrs?)\b"#,
            in: ns, avoiding: consumed
        ) {
            let hours = Int(group(m, 1, ns)) ?? 0
            if hours > 0 {
                result.durationMinutes = hours * 60
                record(.duration, m.range, ns, display: DurationFormatter.short(minutes: hours * 60), into: &result, consumed: &consumed)
            }
        }
    }

    // MARK: - Heure

    struct TimeOfDay: Equatable {
        var hour: Int
        var minute: Int
        /// « ce soir », « ce matin » désignent explicitement aujourd'hui, même
        /// si l'heure est déjà passée.
        var forcesToday: Bool = false
    }

    static func parseTime(_ ns: NSString, _ consumed: inout [NSRange], _ result: inout ParsedInput) -> TimeOfDay? {
        // am / pm
        if let m = firstMatch(#"\b(\d{1,2})(?:[:h\.](\d{2}))?\s*(am|pm)\b"#, in: ns, avoiding: consumed) {
            var hour = Int(group(m, 1, ns)) ?? 0
            let minute = Int(group(m, 2, ns)) ?? 0
            let suffix = group(m, 3, ns).lowercased()
            if suffix == "pm" && hour < 12 { hour += 12 }
            if suffix == "am" && hour == 12 { hour = 0 }
            if let time = validate(hour: hour, minute: minute) {
                record(.time, m.range, ns, display: displayTime(time), into: &result, consumed: &consumed)
                return time
            }
        }

        // Format français : 9h, 14h30 — éventuellement précédé de « à »/« vers »
        if let m = firstMatch(#"\b(?:[àa]|vers|at)?\s*(\d{1,2})\s*h\s*(\d{2})?\b"#, in: ns, avoiding: consumed) {
            let hour = Int(group(m, 1, ns)) ?? 0
            let minute = Int(group(m, 2, ns)) ?? 0
            if let time = validate(hour: hour, minute: minute) {
                record(.time, m.range, ns, display: displayTime(time), into: &result, consumed: &consumed)
                return time
            }
        }

        // Format 24 h avec deux-points : 14:30
        if let m = firstMatch(#"\b(?:[àa]|vers|at)?\s*(\d{1,2}):(\d{2})\b"#, in: ns, avoiding: consumed) {
            let hour = Int(group(m, 1, ns)) ?? 0
            let minute = Int(group(m, 2, ns)) ?? 0
            if let time = validate(hour: hour, minute: minute) {
                record(.time, m.range, ns, display: displayTime(time), into: &result, consumed: &consumed)
                return time
            }
        }

        // Moments de la journée
        let moments: [(String, TimeOfDay)] = [
            (#"\b(?:ce\s+)?matin\b|\bmorning\b"#, TimeOfDay(hour: 9, minute: 0, forcesToday: true)),
            (#"\b(?:ce\s+)?midi\b|\bnoon\b"#, TimeOfDay(hour: 12, minute: 0, forcesToday: true)),
            (#"\b(?:cet\s+)?apr[èe]s-midi\b|\bafternoon\b"#, TimeOfDay(hour: 15, minute: 0, forcesToday: true)),
            (#"\b(?:ce\s+)?soir\b|\bevening\b|\btonight\b"#, TimeOfDay(hour: 19, minute: 0, forcesToday: true)),
            (#"\b(?:cette\s+)?nuit\b|\bnight\b"#, TimeOfDay(hour: 22, minute: 0, forcesToday: true))
        ]
        for (pattern, time) in moments {
            if let m = firstMatch(pattern, in: ns, avoiding: consumed) {
                record(.time, m.range, ns, display: displayTime(time), into: &result, consumed: &consumed)
                return time
            }
        }

        return nil
    }

    static func validate(hour: Int, minute: Int) -> TimeOfDay? {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return TimeOfDay(hour: hour, minute: minute)
    }

    static func displayTime(_ time: TimeOfDay) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }

    // MARK: - Date

    struct DayResult: Equatable {
        var date: Date
        var label: String
    }

    static func parseDate(
        _ ns: NSString,
        _ consumed: inout [NSRange],
        _ result: inout ParsedInput,
        reference: Date,
        calendar: Calendar
    ) -> DayResult? {
        let today = calendar.startOfDay(for: reference)

        // « dans 3 jours », « in 2 weeks »
        if let m = firstMatch(
            #"\b(?:dans|in)\s+(\d{1,3})\s*(jours?|semaines?|mois|ans?|années?|days?|weeks?|months?|years?)\b"#,
            in: ns, avoiding: consumed
        ) {
            let value = Int(group(m, 1, ns)) ?? 0
            let unit = group(m, 2, ns).lowercased()
            var date = today
            if unit.hasPrefix("sem") || unit.hasPrefix("week") {
                date = calendar.date(byAdding: .weekOfYear, value: value, to: today) ?? today
            } else if unit.hasPrefix("mois") || unit.hasPrefix("month") {
                date = calendar.date(byAdding: .month, value: value, to: today) ?? today
            } else if unit.hasPrefix("an") || unit.hasPrefix("ann") || unit.hasPrefix("year") {
                date = calendar.date(byAdding: .year, value: value, to: today) ?? today
            } else {
                date = today.adding(days: value, calendar: calendar)
            }
            let day = DayResult(date: date, label: shortDate(date, calendar: calendar))
            record(.date, m.range, ns, display: day.label, into: &result, consumed: &consumed)
            return day
        }

        // Mots-clés relatifs
        let relatives: [(String, Int)] = [
            (#"\bapr[èe]s[- ]demain\b|\bday\s+after\s+tomorrow\b"#, 2),
            (#"\bdemain\b|\btomorrow\b|\btmr\b"#, 1),
            (#"\baujourd'?hui\b|\bauj\b|\btoday\b|\bce\s+soir\b|\btonight\b"#, 0)
        ]
        for (pattern, offset) in relatives {
            if let m = firstMatch(pattern, in: ns, avoiding: consumed) {
                let date = today.adding(days: offset, calendar: calendar)
                let day = DayResult(date: date, label: relativeLabel(offset: offset, date: date, calendar: calendar))
                record(.date, m.range, ns, display: day.label, into: &result, consumed: &consumed)
                return day
            }
        }

        // « la semaine prochaine », « le mois prochain »
        if let m = firstMatch(#"\b(?:la\s+)?semaine\s+pro(?:chaine)?\b|\bnext\s+week\b"#, in: ns, avoiding: consumed) {
            let date = calendar.startOfWeek(calendar.date(byAdding: .weekOfYear, value: 1, to: today) ?? today)
            let day = DayResult(date: date, label: shortDate(date, calendar: calendar))
            record(.date, m.range, ns, display: day.label, into: &result, consumed: &consumed)
            return day
        }
        if let m = firstMatch(#"\b(?:le\s+)?mois\s+prochain\b|\bnext\s+month\b"#, in: ns, avoiding: consumed) {
            let date = calendar.startOfMonth(calendar.date(byAdding: .month, value: 1, to: today) ?? today)
            let day = DayResult(date: date, label: shortDate(date, calendar: calendar))
            record(.date, m.range, ns, display: day.label, into: &result, consumed: &consumed)
            return day
        }
        if let m = firstMatch(#"\b(?:ce\s+)?week-?end\b|\bthis\s+weekend\b"#, in: ns, avoiding: consumed) {
            let date = nextWeekday(6 + 1, from: today, calendar: calendar, forceNext: false) // samedi
            let day = DayResult(date: date, label: shortDate(date, calendar: calendar))
            record(.date, m.range, ns, display: day.label, into: &result, consumed: &consumed)
            return day
        }
        if let m = firstMatch(#"\bfin\s+du\s+mois\b|\bend\s+of\s+(?:the\s+)?month\b"#, in: ns, avoiding: consumed) {
            let date = calendar.startOfDay(for: calendar.endOfMonth(today))
            let day = DayResult(date: date, label: shortDate(date, calendar: calendar))
            record(.date, m.range, ns, display: day.label, into: &result, consumed: &consumed)
            return day
        }

        // Jours de la semaine, avec ou sans « prochain »
        if let m = firstMatch(
            #"\b(?:(next)\s+)?(lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche|monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:\s+(prochain))?\b"#,
            in: ns, avoiding: consumed
        ) {
            let name = group(m, 2, ns).lowercased()
            let forceNext = !group(m, 1, ns).isEmpty || !group(m, 3, ns).isEmpty
            if let weekday = weekdayNumber(for: name) {
                let date = nextWeekday(weekday, from: today, calendar: calendar, forceNext: forceNext)
                let day = DayResult(date: date, label: shortDate(date, calendar: calendar))
                record(.date, m.range, ns, display: day.label, into: &result, consumed: &consumed)
                return day
            }
        }

        // « 3 mars », « le 1er avril », « march 3 »
        if let m = firstMatch(
            #"\b(?:le\s+)?(\d{1,2})\s*(?:er)?\s+(janvier|février|fevrier|mars|avril|mai|juin|juillet|août|aout|septembre|octobre|novembre|décembre|decembre|january|february|march|april|may|june|july|august|september|october|november|december)\b(?:\s+(\d{4}))?"#,
            in: ns, avoiding: consumed
        ) {
            let dayNumber = Int(group(m, 1, ns)) ?? 1
            let monthName = group(m, 2, ns).lowercased()
            let year = Int(group(m, 3, ns))
            if let month = monthNumber(for: monthName),
               let date = buildDate(day: dayNumber, month: month, year: year, reference: today, calendar: calendar) {
                let day = DayResult(date: date, label: shortDate(date, calendar: calendar))
                record(.date, m.range, ns, display: day.label, into: &result, consumed: &consumed)
                return day
            }
        }

        // Format numérique jour/mois — convention française.
        if let m = firstMatch(#"\b(\d{1,2})[/\.](\d{1,2})(?:[/\.](\d{2,4}))?\b"#, in: ns, avoiding: consumed) {
            let dayNumber = Int(group(m, 1, ns)) ?? 1
            let month = Int(group(m, 2, ns)) ?? 1
            var year = Int(group(m, 3, ns))
            if let y = year, y < 100 { year = 2000 + y }
            if let date = buildDate(day: dayNumber, month: month, year: year, reference: today, calendar: calendar) {
                let day = DayResult(date: date, label: shortDate(date, calendar: calendar))
                record(.date, m.range, ns, display: day.label, into: &result, consumed: &consumed)
                return day
            }
        }

        return nil
    }

    static func buildDate(day: Int, month: Int, year: Int?, reference: Date, calendar: Calendar) -> Date? {
        guard (1...31).contains(day), (1...12).contains(month) else { return nil }
        var comps = DateComponents()
        comps.day = day
        comps.month = month
        comps.year = year ?? calendar.component(.year, from: reference)
        guard var date = calendar.date(from: comps) else { return nil }
        // Sans année explicite, une date déjà passée bascule sur l'an prochain.
        if year == nil, date < calendar.startOfDay(for: reference) {
            comps.year = (comps.year ?? 0) + 1
            date = calendar.date(from: comps) ?? date
        }
        return calendar.startOfDay(for: date)
    }

    /// Prochaine occurrence d'un jour de semaine. Aujourd'hui compte, sauf si
    /// l'utilisateur a précisé « prochain » / « next ».
    static func nextWeekday(_ weekday: Int, from date: Date, calendar: Calendar, forceNext: Bool) -> Date {
        let current = calendar.component(.weekday, from: date)
        var delta = (weekday - current + 7) % 7
        if delta == 0 && forceNext { delta = 7 }
        return date.adding(days: delta, calendar: calendar)
    }

    // MARK: - Priorité, difficulté, domaine, boss

    static func parsePriority(_ ns: NSString, _ consumed: inout [NSRange], _ result: inout ParsedInput) {
        if let m = firstMatch(#"(?:^|\s)(?:!|p)([1-4])\b"#, in: ns, avoiding: consumed) {
            if let value = Int(group(m, 1, ns)), let priority = Priority(rawValue: value) {
                result.priority = priority
                record(.priority, m.range, ns, display: priority.label, into: &result, consumed: &consumed)
                return
            }
        }
        if let m = firstMatch(#"\b(urgent|urgente|critique|asap)\b"#, in: ns, avoiding: consumed) {
            result.priority = .p1
            record(.priority, m.range, ns, display: Priority.p1.label, into: &result, consumed: &consumed)
            return
        }
        if let m = firstMatch(#"\b(important|importante)\b"#, in: ns, avoiding: consumed) {
            result.priority = .p2
            record(.priority, m.range, ns, display: Priority.p2.label, into: &result, consumed: &consumed)
        }
    }

    static func parseDifficulty(_ ns: NSString, _ consumed: inout [NSRange], _ result: inout ParsedInput) {
        guard let m = firstMatch(
            #"\*(broutille|trivial|facile|easy|normal|moyen|ardu|ardue|difficile|hard|[ée]pique|epic|l[ée]gendaire|legendary)\b"#,
            in: ns, avoiding: consumed
        ) else { return }
        let word = group(m, 1, ns).lowercased()
        let difficulty: Difficulty
        switch word {
        case "broutille", "trivial": difficulty = .trivial
        case "facile", "easy": difficulty = .easy
        case "normal", "moyen": difficulty = .medium
        case "ardu", "ardue", "difficile", "hard": difficulty = .hard
        case "épique", "epique", "epic": difficulty = .epic
        default: difficulty = .legendary
        }
        result.difficulty = difficulty
        record(.difficulty, m.range, ns, display: difficulty.label, into: &result, consumed: &consumed)
    }

    static func parseArea(_ ns: NSString, _ consumed: inout [NSRange], _ result: inout ParsedInput) {
        guard let m = firstMatch(
            #"%(corps|body|esprit|mind|cœur|coeur|heart|œuvre|oeuvre|craft|fortune|wealth|foyer|home)\b"#,
            in: ns, avoiding: consumed
        ) else { return }
        let word = group(m, 1, ns).lowercased()
        let area: LifeArea?
        switch word {
        case "corps", "body": area = .body
        case "esprit", "mind": area = .mind
        case "cœur", "coeur", "heart": area = .heart
        case "œuvre", "oeuvre", "craft": area = .craft
        case "fortune", "wealth": area = .wealth
        case "foyer", "home": area = .home
        default: area = nil
        }
        guard let area else { return }
        result.lifeArea = area
        record(.area, m.range, ns, display: area.label, into: &result, consumed: &consumed)
    }

    static func parseBoss(_ ns: NSString, _ consumed: inout [NSRange], _ result: inout ParsedInput) {
        guard let m = firstMatch(#"(?:!boss|👑)"#, in: ns, avoiding: consumed) else { return }
        result.isBoss = true
        record(.boss, m.range, ns, display: "Boss", into: &result, consumed: &consumed)
    }

    static func parseTags(_ ns: NSString, _ consumed: inout [NSRange], _ result: inout ParsedInput) {
        for pattern in [#"#([\p{L}\p{N}_\-]+)"#, #"@([\p{L}\p{N}_\-]+)"#] {
            var searchRange = NSRange(location: 0, length: ns.length)
            while let m = regex(pattern).firstMatch(in: ns as String, options: [], range: searchRange) {
                let next = NSRange(
                    location: m.range.location + m.range.length,
                    length: max(0, ns.length - (m.range.location + m.range.length))
                )
                if !overlaps(m.range, consumed) {
                    let tag = group(m, 1, ns)
                    if !tag.isEmpty && !result.tags.contains(tag.lowercased()) {
                        result.tags.append(tag.lowercased())
                        record(.tag, m.range, ns, display: "#\(tag)", into: &result, consumed: &consumed)
                    }
                }
                if next.length <= 0 { break }
                searchRange = next
            }
        }
    }

    static func parseProject(_ ns: NSString, _ consumed: inout [NSRange], _ result: inout ParsedInput) {
        guard let m = firstMatch(#"\+([\p{L}\p{N}_\-]+)"#, in: ns, avoiding: consumed) else { return }
        let name = group(m, 1, ns)
        guard !name.isEmpty else { return }
        result.project = name
        record(.project, m.range, ns, display: name, into: &result, consumed: &consumed)
    }

    // MARK: - Assemblage de l'échéance

    static func applyDueDate(
        day: DayResult?,
        time: TimeOfDay?,
        reference: Date,
        calendar: Calendar,
        into result: inout ParsedInput
    ) {
        switch (day, time) {
        case (nil, nil):
            return
        case (let day?, nil):
            result.dueDate = calendar.startOfDay(for: day.date)
            result.hasTime = false
        case (nil, let time?):
            var candidate = calendar.setting(hour: time.hour, minute: time.minute, of: reference)
            // Une heure déjà passée vise le lendemain, comme dans Todoist —
            // sauf si l'utilisateur a explicitement dit « ce soir ».
            if candidate <= reference && !time.forcesToday {
                candidate = candidate.adding(days: 1, calendar: calendar)
            }
            result.dueDate = candidate
            result.hasTime = true
        case (let day?, let time?):
            result.dueDate = calendar.setting(hour: time.hour, minute: time.minute, of: day.date)
            result.hasTime = true
        }
    }

    static func applyFirstOccurrence(
        of rule: RecurrenceRule,
        time: TimeOfDay?,
        reference: Date,
        calendar: Calendar,
        into result: inout ParsedInput
    ) {
        let anchor = calendar.startOfDay(for: reference)
        var cursor = anchor
        for _ in 0..<400 {
            if RecurrenceEngine.matches(rule: rule, date: cursor, anchor: anchor, calendar: calendar) {
                if let time {
                    let candidate = calendar.setting(hour: time.hour, minute: time.minute, of: cursor)
                    if candidate >= reference || time.forcesToday {
                        result.dueDate = candidate
                        result.hasTime = true
                        return
                    }
                } else {
                    result.dueDate = cursor
                    result.hasTime = false
                    return
                }
            }
            cursor = cursor.adding(days: 1, calendar: calendar)
        }
    }

    // MARK: - Déduction du domaine

    static let areaKeywords: [LifeArea: [String]] = [
        .body: ["sport", "gym", "muscu", "course", "courir", "running", "yoga", "santé", "sante", "médecin", "medecin",
                "dentiste", "sommeil", "marche", "vélo", "velo", "natation", "workout", "health", "run"],
        .mind: ["lecture", "lire", "cours", "étude", "etude", "révision", "revision", "apprendre", "formation",
                "podcast", "méditation", "meditation", "study", "read", "learn", "duolingo"],
        .heart: ["famille", "ami", "amis", "appeler", "appel", "anniversaire", "cadeau", "couple", "dîner", "diner",
                 "call", "family", "friend", "date", "thérapie", "therapie"],
        .craft: ["projet", "code", "dev", "design", "écrire", "ecrire", "réunion", "reunion", "client", "boulot",
                 "travail", "work", "meeting", "deck", "rapport", "présentation", "presentation"],
        .wealth: ["facture", "impôt", "impot", "banque", "budget", "épargne", "epargne", "assurance", "devis",
                  "paiement", "invoice", "tax", "money", "salaire", "compta"],
        .home: ["courses", "ménage", "menage", "vaisselle", "lessive", "ranger", "rangement", "cuisine", "jardin",
                "bricolage", "poubelle", "aspirateur", "groceries", "clean", "laundry"]
    ]

    static func inferArea(from tags: [String], title: String) -> LifeArea? {
        let haystack = (tags + [title.lowercased()]).joined(separator: " ")
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
        for area in LifeArea.allCases {
            guard let keywords = areaKeywords[area] else { continue }
            for keyword in keywords {
                let normalized = keyword.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
                if haystack.contains(normalized) { return area }
            }
        }
        return nil
    }

    // MARK: - Outils regex

    private static let cache = RegexCache()

    static func regex(_ pattern: String) -> NSRegularExpression {
        cache.regex(for: pattern)
    }

    static func firstMatch(_ pattern: String, in ns: NSString, avoiding consumed: [NSRange]) -> NSTextCheckingResult? {
        let full = NSRange(location: 0, length: ns.length)
        let matches = regex(pattern).matches(in: ns as String, options: [], range: full)
        return matches.first { !overlaps($0.range, consumed) }
    }

    static func overlaps(_ range: NSRange, _ ranges: [NSRange]) -> Bool {
        ranges.contains { NSIntersectionRange($0, range).length > 0 }
    }

    static func group(_ match: NSTextCheckingResult, _ index: Int, _ ns: NSString) -> String {
        guard index < match.numberOfRanges else { return "" }
        let range = match.range(at: index)
        guard range.location != NSNotFound, range.length > 0 else { return "" }
        return ns.substring(with: range)
    }

    static func record(
        _ kind: ParsedToken.Kind,
        _ range: NSRange,
        _ ns: NSString,
        display: String,
        into result: inout ParsedInput,
        consumed: inout [NSRange]
    ) {
        let text = ns.substring(with: range)
        result.tokens.append(ParsedToken(
            kind: kind,
            text: text,
            display: display,
            location: range.location,
            length: range.length
        ))
        consumed.append(range)
    }

    static func cleanTitle(_ ns: NSString, consumed: [NSRange]) -> String {
        let mutable = NSMutableString(string: ns as String)
        for range in consumed.sorted(by: { $0.location > $1.location }) {
            guard range.location + range.length <= mutable.length else { continue }
            mutable.replaceCharacters(in: range, with: " ")
        }
        let collapsed = regex(#"\s{2,}"#).stringByReplacingMatches(
            in: mutable as String,
            options: [],
            range: NSRange(location: 0, length: mutable.length),
            withTemplate: " "
        )
        return collapsed
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,;:-—–"))
    }

    // MARK: - Libellés

    static func weekdayNumber(for name: String) -> Int? {
        let normalized = name
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .lowercased()
        let table: [(String, Int)] = [
            ("dimanche", 1), ("sunday", 1),
            ("lundi", 2), ("monday", 2),
            ("mardi", 3), ("tuesday", 3),
            ("mercredi", 4), ("wednesday", 4),
            ("jeudi", 5), ("thursday", 5),
            ("vendredi", 6), ("friday", 6),
            ("samedi", 7), ("saturday", 7)
        ]
        for (key, value) in table where normalized.hasPrefix(key) {
            return value
        }
        return nil
    }

    static func monthNumber(for name: String) -> Int? {
        let normalized = name
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .lowercased()
        let table: [(String, Int)] = [
            ("janvier", 1), ("january", 1),
            ("fevrier", 2), ("february", 2),
            ("mars", 3), ("march", 3),
            ("avril", 4), ("april", 4),
            ("mai", 5), ("may", 5),
            ("juin", 6), ("june", 6),
            ("juillet", 7), ("july", 7),
            ("aout", 8), ("august", 8),
            ("septembre", 9), ("september", 9),
            ("octobre", 10), ("october", 10),
            ("novembre", 11), ("november", 11),
            ("decembre", 12), ("december", 12)
        ]
        for (key, value) in table where normalized == key {
            return value
        }
        return nil
    }

    static func relativeLabel(offset: Int, date: Date, calendar: Calendar) -> String {
        switch offset {
        case 0: return "Aujourd'hui"
        case 1: return "Demain"
        case 2: return "Après-demain"
        default: return shortDate(date, calendar: calendar)
        }
    }

    static func shortDate(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: date).capitalizedFirstLetter
    }
}

// MARK: - Cache de regex

/// Compiler une `NSRegularExpression` coûte cher : on les garde en mémoire.
final class RegexCache: @unchecked Sendable {
    private var storage: [String: NSRegularExpression] = [:]
    private let lock = NSLock()

    /// Motif de repli, syntaxiquement valide et qui ne matche jamais rien.
    private static let neverMatching: NSRegularExpression = {
        // Un littéral simple : sa compilation ne peut pas échouer.
        (try? NSRegularExpression(pattern: "\\bZZZ_NO_MATCH_ZZZ\\b", options: []))!
    }()

    func regex(for pattern: String) -> NSRegularExpression {
        lock.lock()
        defer { lock.unlock() }
        if let existing = storage[pattern] { return existing }
        // Les motifs sont des littéraux du code : un échec ici est un bug de
        // développement. On retombe sur un motif inerte plutôt que de faire
        // tomber l'app entre les mains de l'utilisateur.
        let created = (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))
            ?? RegexCache.neverMatching
        storage[pattern] = created
        return created
    }
}

public extension String {
    var capitalizedFirstLetter: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}
