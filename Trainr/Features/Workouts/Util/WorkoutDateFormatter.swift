import Foundation

nonisolated enum WorkoutDateFormatter {

    // A week date carries no time of day and no zone, so it is read back in the
    // calendar it was built in rather than wherever the phone has since moved.
    private static var dateZone: TimeZone { WorkoutWeek.dateCalendar.timeZone }

    // FormatStyle rather than a literal pattern, which would translate the
    // words and keep English word order.
    static func fullDate(_ date: Date, locale: Locale = .current) -> String {
        var style = Date.FormatStyle(date: .complete, locale: locale)
        style.timeZone = dateZone
        return date.formatted(style)
    }

    static func weekday(_ date: Date, locale: Locale = .current) -> String {
        var style = Date.FormatStyle(locale: locale).weekday(.wide)
        style.timeZone = dateZone
        return date.formatted(style)
    }

    static func mediumDate(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, locale: locale))
    }

    // Takes the stored ISO number, Monday 1 through Sunday 7, not Calendar's
    // own Sunday-first numbering.
    static func weekdayName(iso weekday: Int, locale: Locale = .current) -> String {
        var calendar = Calendar.current
        calendar.locale = locale
        let symbols = calendar.weekdaySymbols
        let index = weekday % symbols.count
        return symbols.indices.contains(index) ? symbols[index] : ""
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
        style.timeZone = dateZone
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
