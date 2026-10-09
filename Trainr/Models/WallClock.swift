import Foundation

// The calendar date, not an interval: a screen open across midnight has to be
// able to read the day it is on now rather than the one it was opened on.
struct WallClock {
    let now: () -> Date

    static let system = WallClock { Date() }
}
