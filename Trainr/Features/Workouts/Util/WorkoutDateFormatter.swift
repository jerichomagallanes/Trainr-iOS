import Foundation

nonisolated enum WorkoutDateFormatter {

    // Date.FormatStyle rather than a literal pattern: the same call reads as
    // "Wednesday, 23 July 2025" or 2025年7月23日水曜日 depending on the locale,
    // where a hand-written pattern would translate the words and keep English
    // word order.
    static func fullDate(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(date: .complete, locale: locale))
    }

    static func weekday(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(locale: locale).weekday(.wide))
    }

    // The pair of dates a week spans. Foundation's interval style says whatever
    // the two dates have in common once — "September 6 – 12, 2026", and the
    // month again when the week crosses one — which is the rule the design
    // wants and a per-locale one rather than a rule about English.
    static func weekRange(
        from start: Date,
        to end: Date,
        locale: Locale = .current,
        calendar: Calendar = .current,
        abbreviated: Bool = false
    ) -> String {
        var style = Date.IntervalFormatStyle(locale: locale, calendar: calendar)
            .month(abbreviated ? .abbreviated : .wide)
            .day()
            .year()
        style.timeZone = calendar.timeZone
        // A week that begins and ends on the same day is not an interval; the
        // style would print one date twice.
        guard start < end else { return start.formatted(style.dateStyle) }
        return (start..<end).formatted(style)
    }
}

private nonisolated extension Date.IntervalFormatStyle {
    // The same fields, for the one date an empty range leaves.
    var dateStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone)
            .month(.wide).day().year()
    }
}
