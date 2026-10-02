import Foundation

nonisolated struct DeviceEligibility: Equatable, Sendable {

    let isSupported: Bool

    init(physicalMemory: UInt64, isArm64: Bool) {
        isSupported = physicalMemory >= Self.minimumMemoryBytes && isArm64
    }

    private static let minimumMemoryBytes: UInt64 = 3 << 30

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
