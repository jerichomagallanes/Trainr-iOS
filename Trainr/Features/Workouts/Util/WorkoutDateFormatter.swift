import Foundation

nonisolated enum WorkoutDateFormatter {

    // FormatStyle rather than a literal pattern, which would translate the
    // words and keep English word order.
    static func fullDate(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(date: .complete, locale: locale))
    }

    static func weekday(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(locale: locale).weekday(.wide))
    }

    // The interval style names what the two dates share once — "September 6 –
    // 12, 2026" — which is the design's rule, per locale.
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
        // A same-day range is not an interval; the style prints the date twice.
        guard start < end else { return start.formatted(style.dateStyle) }
        return (start..<end).formatted(style)
    }
}

private nonisolated extension Date.IntervalFormatStyle {
    var dateStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone)
            .month(.wide).day().year()
    }
}
