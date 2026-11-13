import Foundation
import SwiftData

// Every shipped build wrote a week's anchor as midnight in whatever zone the
// phone was in, so the week re-dated itself the moment the phone moved west.
// Each one is rewritten to midnight UTC on the day it was meant to be, in the
// zone the phone is in when it runs.
//
// A schema migration would be the place for this, as it is on Android, but
// SwiftData refuses a custom stage between two schemas of the same shape and
// nothing about the shape changes here. So it runs at every open and is safe to:
// an anchor that is already midnight UTC is left alone, and local midnight is
// midnight UTC only in a zone at no offset, where it is already right.
nonisolated enum StoredWeekAnchor {

    // Hung off the container's making, so nothing can open the store and read
    // an anchor the shipped app left as an instant.
    @MainActor
    static func normalised(
        _ container: ModelContainer, breadcrumbs: any Breadcrumbs
    ) -> ModelContainer {
        do {
            try normalise(in: ModelContext(container))
        } catch {
            breadcrumbs.report(error, doing: "normaliseWeekAnchors")
        }
        return container
    }

    static func normalise(in context: ModelContext, zone: TimeZone = .current) throws {
        let stale = try context.fetch(FetchDescriptor<WeeklyPlanRecord>())
            .filter { $0.startDate.map(isAnInstant) ?? false }
        guard !stale.isEmpty else { return }

        for plan in stale {
            guard let stored = plan.startDate else { continue }
            plan.startDate = utcMidnight(of: stored, in: zone)
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    static func isAnInstant(_ stored: Date) -> Bool {
        stored.timeIntervalSince1970.truncatingRemainder(dividingBy: secondsPerDay) != 0
    }

    // The offset in force at that instant, not today's, so a plan anchored the
    // other side of a daylight-saving change keeps its own date.
    static func utcMidnight(of stored: Date, in zone: TimeZone) -> Date {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = zone
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        let parts = local.dateComponents([.year, .month, .day], from: stored)
        return utc.date(
            from: DateComponents(year: parts.year, month: parts.month, day: parts.day)
        ) ?? stored
    }

    private static let secondsPerDay: TimeInterval = 24 * 60 * 60
}
