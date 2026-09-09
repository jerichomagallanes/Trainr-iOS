import Foundation

// Shared by the paywall and the subscription screen, which have to agree: the
// terms someone accepts when buying are the terms they are shown afterwards.
enum ProLinks {
    // Ours rather than Apple's standard agreement, which applies only while no
    // custom one is supplied and says nothing about injury risk or about plans
    // being written by a model. It must also be pasted into App Store Connect's
    // License Agreement field, or the document shown here is not the one that
    // governs.
    static let terms = URL(
        string: "https://jerichomagallanes.github.io/Trainr/terms-of-use"
    )!
    static let privacy = URL(
        string: "https://jerichomagallanes.github.io/Trainr/privacy-policy"
    )!
    // Cancelling and changing plan happen in Apple's own settings, never here.
    static let subscriptions = URL(
        string: "https://apps.apple.com/account/subscriptions"
    )!
}
