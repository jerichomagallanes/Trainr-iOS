import Foundation

// One generated week is free, ever. Recorded apart from the plans themselves so
// deleting every week does not hand back the allowance: that would be a way to
// generate without limit and without even reinstalling.
//
// A reinstall does clear this, and that is accepted rather than defended. The
// only iOS mechanism that survives a reinstall is DeviceCheck, which needs a
// server we do not have, and the leak costs one generation while taking away
// every set the person had logged.
protocol FreeGenerationAllowance {
    func hasBeenUsed() -> Bool
    func markUsed()
}

final class StoredGenerationAllowance: FreeGenerationAllowance {

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func hasBeenUsed() -> Bool {
        #if DEBUG
        if Self.arguments.contains("-freeGenerationUsed") { return true }
        if Self.isEphemeral { return Self.volatile }
        #endif
        return defaults.bool(forKey: Self.key)
    }

    func markUsed() {
        #if DEBUG
        if Self.isEphemeral {
            Self.volatile = true
            return
        }
        #endif
        defaults.set(true, forKey: Self.key)
    }

    private static let key = "free_generation_used"

    #if DEBUG
    private static let arguments = ProcessInfo.processInfo.arguments

    // A UI test's store dies with the process but UserDefaults does not, so the
    // allowance would leak from one test into the next.
    private static let isEphemeral = arguments.contains("-inMemoryStore")
    private nonisolated(unsafe) static var volatile = false
    #endif
}
