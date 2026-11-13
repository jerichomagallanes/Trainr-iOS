import Testing
@testable import Trainr

@Suite("Which phones can read a note")
struct DeviceEligibilityTests {

    private func gibibytes(_ value: Double) -> UInt64 {
        UInt64(value * Double(1 << 30))
    }

    private func eligibility(_ memory: Double, isArm64: Bool = true) -> DeviceEligibility {
        DeviceEligibility(physicalMemory: gibibytes(memory), isArm64: isArm64)
    }

    @Test("A three gigabyte phone is eligible whatever it reports")
    func aThreeGigabytePhoneIsEligibleWhateverItReports() {
        #expect(eligibility(2.7).isSupported)
        #expect(eligibility(2.8).isSupported)
        #expect(eligibility(2.9).isSupported)
        #expect(eligibility(3.0).isSupported)
    }

    @Test("A two gigabyte phone is not eligible")
    func aTwoGigabytePhoneIsNotEligible() {
        #expect(!eligibility(1.8).isSupported)
        #expect(!eligibility(2.0).isSupported)
    }

    @Test("A four gigabyte phone is eligible")
    func aFourGigabytePhoneIsEligible() {
        #expect(eligibility(3.7).isSupported)
    }

    @Test("Only sixty-four bit architectures are eligible")
    func onlySixtyFourBitArchitecturesAreEligible() {
        #expect(!eligibility(8.0, isArm64: false).isSupported)
        #expect(eligibility(8.0).isSupported)
    }
}
