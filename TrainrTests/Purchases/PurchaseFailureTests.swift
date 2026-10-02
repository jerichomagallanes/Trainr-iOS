import Foundation
import Testing
import TrainrDependencies
@testable import Trainr

@MainActor
struct PurchaseFailureTests {
    @Test("Cancelled purchases stay silent; pending and failures explain what to do")
    func storeFailures() {
        let cancelled = NSError(domain: ErrorCode.errorDomain, code: ErrorCode.purchaseCancelledError.rawValue)
        let pending = NSError(domain: ErrorCode.errorDomain, code: ErrorCode.paymentPendingError.rawValue)
        #expect(Entitlements.message(forPurchaseError: cancelled) == nil)
        #expect(Entitlements.message(forPurchaseError: pending) == L10n.proPurchasePending)
        #expect(Entitlements.message(forPurchaseError: URLError(.notConnectedToInternet)) == L10n.proPurchaseFailed)
    }

    @Test("An unrelated error with the cancellation code is not mistaken for cancellation")
    func unrelatedDomain() {
        let error = NSError(domain: "TrainrTests", code: ErrorCode.purchaseCancelledError.rawValue)
        #expect(Entitlements.message(forPurchaseError: error) == L10n.proPurchaseFailed)
    }
}
