import Testing
@testable import Trainr

@MainActor
@Suite("Which Pro screen")
struct ProScreenChoiceTests {

    @Test("A store that has not answered yet gets neither screen")
    func anUnreadEntitlementShowsNeitherScreen() {
        #expect(ProView.showing(hasRead: false, isPro: false) == .unknown)
        #expect(ProView.showing(hasRead: false, isPro: true) == .unknown)
    }

    @Test("A subscriber gets the status screen, never the sales page")
    func aSubscriberIsNeverShownTheSalesPage() {
        #expect(ProView.showing(hasRead: true, isPro: true) == .status)
    }

    @Test("Someone without Pro still gets the sales page")
    func someoneWithoutProStillGetsTheSalesPage() {
        #expect(ProView.showing(hasRead: true, isPro: false) == .paywall)
    }
}
