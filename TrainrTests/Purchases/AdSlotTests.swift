import Testing
@testable import Trainr

@Suite("The plan screen's ad slot")
struct AdSlotTests {

    // The defect, in the state it actually occurs in: between process start and
    // the launch read landing, a subscriber and a free client are the same
    // unread false, and the banner Pro exists to remove was requested in that
    // gap and shown to people who had paid not to see it.
    @Test("Nobody is shown an ad while the store is still answering")
    func nobodyIsShownAnAdWhileTheStoreIsStillAnswering() {
        #expect(WeeklyPlanView.showsAd(canShowAds: true, hasRead: false, isPro: false) == false)
    }

    // A read that failed never sets hasRead, so this is the same input as the
    // test above and deliberately the same answer: no ad, for good, on this
    // launch. An impression nobody serves costs less than charging a subscriber
    // the one thing Pro promises to remove.
    @Test("A read that failed leaves the slot empty rather than guessing")
    func aReadThatFailedLeavesTheSlotEmpty() {
        #expect(WeeklyPlanView.showsAd(canShowAds: true, hasRead: false, isPro: false) == false)
    }

    @Test("A subscriber is shown no ad once the read confirms Pro")
    func aSubscriberIsShownNoAd() {
        #expect(WeeklyPlanView.showsAd(canShowAds: true, hasRead: true, isPro: true) == false)
    }

    @Test("A free client is shown an ad once the read lands")
    func aFreeClientIsShownAnAd() {
        #expect(WeeklyPlanView.showsAd(canShowAds: true, hasRead: true, isPro: false))
    }

    @Test("Consent still decides before any of it")
    func consentStillDecidesBeforeAnyOfIt() {
        #expect(WeeklyPlanView.showsAd(canShowAds: false, hasRead: true, isPro: false) == false)
    }
}
