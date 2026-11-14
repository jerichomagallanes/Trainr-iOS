import Foundation

nonisolated struct DeviceEligibility: Equatable, Sendable {

    let isSupported: Bool

    init(physicalMemory: UInt64, isArm64: Bool) {
        isSupported = Self.memorySoldWith(physicalMemory) >= Self.minimumMemoryBytes && isArm64
    }

    private static let minimumMemoryBytes: UInt64 = 3 << 30
    private static let halfGibibyte: UInt64 = 1 << 29

    // The bar is the memory the device was sold with. physicalMemory already
    // reports that, while Android reads a kernel figure hundreds of megabytes
    // short of it, so both platforms round a reported figure up to the nearest
    // half gibibyte and the one constant means the same thing on each.
    private static func memorySoldWith(_ reported: UInt64) -> UInt64 {
        (reported + halfGibibyte - 1) / halfGibibyte * halfGibibyte
    }

    static let current = DeviceEligibility(
        physicalMemory: ProcessInfo.processInfo.physicalMemory,
        isArm64: {
            #if arch(arm64)
            true
            #else
            false
            #endif
        }()
    )
}
