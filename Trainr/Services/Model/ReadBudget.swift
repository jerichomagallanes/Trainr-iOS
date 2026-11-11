import Foundation

// A read is charged for the time it was actually given. The app is suspended
// whole while a call is taken and the model stops with it, so the budget is
// spent a slice at a time and no slice is ever charged for more than it was
// allowed to take.
nonisolated struct ReadBudget: Sendable {

    private let slice: Duration
    private var remaining: Duration

    init(budget: Duration, slice: Duration) {
        self.slice = max(slice, .zero)
        self.remaining = max(budget, .zero)
    }

    var isSpent: Bool { remaining <= .zero }

    var nextSlice: Duration { min(slice, remaining) }

    mutating func charge(_ elapsed: Duration) {
        remaining = max(remaining - min(max(elapsed, .zero), slice), .zero)
    }
}
