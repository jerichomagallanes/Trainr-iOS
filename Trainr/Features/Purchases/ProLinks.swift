import Foundation

// Shared by the paywall and the subscription screen, which have to agree: the
// terms someone accepts when buying are the terms they are shown afterwards.
enum ProLinks {
    // Apple's standard agreement applies where no custom one is supplied, and
    // the paywall has to link to it.
    static let terms = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    )!
    static let privacy = URL(
        string: "https://jerichomagallanes.github.io/Trainr/privacy-policy"
    )!
    // Cancelling and changing plan happen in Apple's own settings, never here.
    static let subscriptions = URL(
        string: "https://apps.apple.com/account/subscriptions"
    )!
}
